import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:springfydrt/features/notifier/notifier.dart';
import 'package:web_socket_channel/io.dart';
import 'package:collection/collection.dart';
import '../cloud/api/api_cloud.dart';
import '../cloud/dto/audioDto.dart';
import '../login/api/token.dart';
import 'api/p_c_m_player.dart';
import 'api/wsconnect.dart';
import 'dto/comando.dart';

enum DuoState { none, connecting, hosting, following }

class StreamingPage extends StatefulWidget {
  const StreamingPage({super.key});

  @override
  State<StreamingPage> createState() => _StreamingPageState();
}

class _StreamingPageState extends State<StreamingPage> {
  final ApiCloud _apiCloud = ApiCloud();
  late Future<List<AudioDTO>> _cloudSongs;
  final PcmPlayer _pcmPlayer = PcmPlayer();

  final StreamController<DuoState> _stateController =
  StreamController<DuoState>.broadcast();
  DuoState _duoState = DuoState.connecting;

  IOWebSocketChannel? _channel;
  String? _usuarioActual;
  String? _nombreUsuarioConexion;
  int? _currentSongIndex;
  AudioDTO? _currentSong;
  String? _hostUser;
  bool _isFollowerConnected = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    StreamNotifier.instance.addListener(disconnect);
    _refreshCloudSongs();
  }

  @override
  void dispose() {

    _channel?.sink.close();
    _pcmPlayer.close();
    _stateController.close();
    super.dispose();
  }

  Future<void> disconnect() async{

    _channel?.sink.close();
  }
  void _emitState(DuoState s) {
    _duoState = s;
    if (!_stateController.isClosed) {
      _stateController.add(s);
    }
  }

  Future<void> _initialize() async {
    await _pcmPlayer.ensureReady();
    _emitState(DuoState.connecting);
    await _obtainUser();

    final user = await obtainUserConection();
    if (user != null && user.isNotEmpty) {
      _nombreUsuarioConexion = user;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showUserSelectionDialog();
      });
    }

    await _connect();
    if (_duoState == DuoState.connecting) {
      _emitState(DuoState.none);
    }
  }

  Future<void> _obtainUser() async {
    final token = await TokenStorage.getToken();
    log("Token: $token");
    if (token != null) {
      _usuarioActual = await TokenStorage.getUsername();
      log("Usuario actual: $_usuarioActual");
    } else {
      log("No se pudo obtener el usuario actual.");
    }
  }

  Future<void> _showUserSelectionDialog() async {
    final availableUsers = await allUserNames();
    final currentUser = _usuarioActual;

    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo identificar al usuario actual.')));
      }
      return;
    }

    final otherUsers =
    availableUsers.where((user) => user != currentUser && user.isNotEmpty).toList();

    if (!mounted) return;

    final selectedUser = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('No estás haciendo dúo con nadie'),
          content: SizedBox(
            width: double.maxFinite,
            child: otherUsers.isEmpty
                ? const Text("No hay otros usuarios disponibles.")
                : ListView.builder(
              shrinkWrap: true,
              itemCount: otherUsers.length,
              itemBuilder: (BuildContext context, int index) {
                final user = otherUsers[index];
                return ListTile(
                  title: Text(user),
                  onTap: () {
                    Navigator.pop(context, user);
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    if (selectedUser != null) {
      final duoRequest = DuoRequest(username1: currentUser, username2: selectedUser);
      try {
        await createDuo(duoRequest);
        _nombreUsuarioConexion = selectedUser;
        log("currentUser: $currentUser");
        log("_nombreUsuarioConexion: $_nombreUsuarioConexion");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ahora estás en un dúo con $selectedUser.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al crear el dúo: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selección de dúo cancelada.')),
        );
      }
    }
  }

  Future<void> _connect() async {
    if (_usuarioActual == null) return;

    Map<String, String> userHeader = {'Usuario': _usuarioActual!};

    bool _wavHeaderSkipped = false;
    int _wavHeaderBytesPending = 44;

    try {
      _channel = await connect(userHeader);
      log("WebSocket connected.");

      _channel!.stream.listen((message) async {
        if (message is String) {
          final comando = ComandoDTO.fromJson(jsonDecode(message));
          await _handleCommand(comando);
          return;
        }

        if (message is List<int>) {
          if (_duoState != DuoState.hosting && !(_duoState == DuoState.following && _isFollowerConnected)) {
            return;
          }

          Uint8List bytes = Uint8List.fromList(message);

          if (!_wavHeaderSkipped) {
            if (bytes.length <= _wavHeaderBytesPending) {
              _wavHeaderBytesPending -= bytes.length;
              return;
            } else {
              bytes = bytes.sublist(_wavHeaderBytesPending);
              _wavHeaderBytesPending = 0;
              _wavHeaderSkipped = true;
            }
          }

          if (bytes.isEmpty) return;

          if (bytes.lengthInBytes % 2 != 0) {
            bytes = bytes.sublist(0, bytes.lengthInBytes - 1);
          }
          log("chunk bytes = ${bytes.length}");

          if (bytes.isEmpty) return;

          final bd = ByteData.view(
            bytes.buffer,
            bytes.offsetInBytes,
            bytes.lengthInBytes,
          );

          final pcm = PcmArrayInt16(bytes: bd);

          await _pcmPlayer.play(pcm);
        }
      }, onDone: () async {
        log("WebSocket connection closed.");
        if (!mounted) return;

        // reset visuals and emit state none
        await _pcmPlayer.stop();
        setState(() {
          _currentSong = null;
          _hostUser = null;
          _isFollowerConnected = false;
        });
        _emitState(DuoState.none);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión dúo terminada.')),
        );

        _connect();
      }, onError: (error) async {
        log("WebSocket error: $error");
        if (!mounted) return;

        await _pcmPlayer.stop();
        setState(() {
          _currentSong = null;
          _hostUser = null;
          _isFollowerConnected = false;
        });
        _emitState(DuoState.none);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $error')),
        );
      });
    } catch (e) {
      log("Failed to connect: $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo conectar al servidor: $e')),
      );

      _emitState(DuoState.none);
    }
  }

  Future<void> _handleCommand(ComandoDTO comando) async {
    switch (comando.comando) {
      case 'start':
        if (_usuarioActual == comando.seguidor) {
          final songs = await _cloudSongs;
          var song;
          int i;
          for (i = 0; i < songs.length; i++) {
            if(songs[i].audioId==comando.musicId){
              song=songs[i];
              _currentSongIndex=i;
              break;
            }

          }


          log("following");
          if (song != null) {
            setState(() {
              _currentSongIndex=i;// song mierdaaaa
              _currentSong = song;
              _hostUser = comando.anfitrion;
              _isFollowerConnected = false;
            });
            _emitState(DuoState.following);
            await _pcmPlayer.ensureReady();
          }
        }
        break;

      case 'disconnect':
        await _pcmPlayer.close();
        setState(() {
          _currentSong = null;
          _hostUser = null;
          _isFollowerConnected = false;
        });
        _emitState(DuoState.none);
        break;

      case 'stop':
        if (_duoState == DuoState.following) await _pcmPlayer.stop();
        break;

      case 'resume':
        if (_duoState == DuoState.following) await _pcmPlayer.resume();
        break;

      case 'change':
        final songs = await _cloudSongs;
        setState(() {
          _currentSongIndex = songs.indexWhere((song) => song.audioId == comando.musicId);
          _currentSong= songs[_currentSongIndex!];

        });
        await _pcmPlayer.ensureReady();
        break;


      default:
        log("Comando desconocido recibid: ${comando.comando}");
    }
  }

  Future<void> _refreshCloudSongs() async {
    setState(() {
      _cloudSongs = _apiCloud.allOnCloudWav();
    });
  }

  void _sendPlayerCommand(String command, {Map<String, dynamic> params = const {}}) {
    if ((_duoState != DuoState.hosting && _duoState != DuoState.following) || _channel == null) return;

    final Map<String, dynamic> commandData;

    if (_duoState == DuoState.hosting) {
      commandData = {
        'comando': command,
        'anfitrion': _usuarioActual,
        'seguidor': _nombreUsuarioConexion,
        'musicId': _currentSong?.audioId,
        ...params,
      };
    } else {
      commandData = {
        'comando': command,
        'anfitrion': _hostUser,
        'seguidor': _usuarioActual,
        'musicId': _currentSong?.audioId,
        ...params,
      };
    }
    _channel!.sink.add(jsonEncode(commandData));
  }

  Future<void> _startHosting(AudioDTO song) async {
    if (_channel == null || _usuarioActual == null || _nombreUsuarioConexion == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se puede iniciar, falta información de usuario o conexión.')));
      return;
    }


    setState(() {
      _currentSong = song;
      _hostUser = _usuarioActual;
    });
    _emitState(DuoState.hosting);


    await _pcmPlayer.ensureReady();

    _sendPlayerCommand('start');
  }

  Future<void> _disconnect() async {
    _sendPlayerCommand('disconnect');

    await _pcmPlayer.close();

    await _channel?.sink.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dúo'),
        actions: [

          StreamBuilder<DuoState>(
            stream: _stateController.stream,
            initialData: _duoState,
            builder: (context, snap) {
              final state = snap.data ?? DuoState.none;
              if (state == DuoState.none) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshCloudSongs,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Center(
        child: StreamBuilder<DuoState>(
          stream: _stateController.stream,
          initialData: _duoState,
          builder: (context, snapshot) {
            final state = snapshot.data ?? DuoState.none;
            switch (state) {
              case DuoState.connecting:
                return const CircularProgressIndicator();
              case DuoState.none:
                return _buildSongListUI();
              case DuoState.hosting:
                return _buildPlayerUI(isHost: true);
              case DuoState.following:
                return _buildPlayerUI(isHost: false);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSongListUI() {
    return FutureBuilder<List<AudioDTO>>(
      future: _cloudSongs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Error al cargar canciones: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No hay canciones en la nube.');
        }

        final songs = snapshot.data!;
        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return ListTile(
              leading: const Icon(Icons.music_note),
              title: Text(song.nombreAudio),
              subtitle: Text("Santi"),
              onTap: (){
                PlayerNotifier.instance.notify();
                _startHosting(song);},
            );
          },
        );
      },
    );
  }

  Widget _buildPlayerUI({required bool isHost}) {
    if (_currentSong == null) {
      return const Text("Esperando información de la canción...");
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isHost)
            Text(

              '${_hostUser ?? "Anfitrión"} está escuchando:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: 16),
          Text(
            _currentSong!.nombreAudio,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          Text(
            "Santi",
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (isHost) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () async {
                    final songs = await _cloudSongs;

                    final nextIndex = (_currentSongIndex ?? 0) - 1;
                    if (nextIndex >= songs.length) return;

                    final nextSong = songs[nextIndex];

                    setState(() {
                      _currentSongIndex = nextIndex;
                      _currentSong = nextSong;
                    });

                    _sendPlayerCommand('change', params: {
                      "musicId": nextSong.audioId,
                    });
                  }
                  ,
                  iconSize: 48,
                ),
                IconButton(
                  icon: const Icon(Icons.pause),
                  onPressed: () => _sendPlayerCommand('stop'),
                  iconSize: 48,
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _sendPlayerCommand('resume'),
                  iconSize: 48,
                ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: () async {
                  final songs = await _cloudSongs;

                  final nextIndex = (_currentSongIndex ?? 0) + 1;
                  if (nextIndex >= songs.length) return;

                  final nextSong = songs[nextIndex];

                  setState(() {
                    _currentSongIndex = nextIndex;
                    _currentSong = nextSong;
                  });

                  _sendPlayerCommand('change', params: {
                    "musicId": nextSong.audioId,
                  });
                }
                ,
                iconSize: 48,
              ),

],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _disconnect,
              child: const Text('Desconectar'),
            ),
          ] else ...[
          ElevatedButton(
          onPressed: () {
    setState(() {
    _isFollowerConnected = !_isFollowerConnected;
    });
    _sendPlayerCommand(_isFollowerConnected ? 'connect' : 'follower-disconnect');
    },
      child: Text(_isFollowerConnected ? 'Desconectar' : 'Conectar'),
    ),
    const SizedBox(height: 16),
    const Text("Controles manejados por el anfitrión."),
     ]
        ],
      ),
    );
  }
}
