import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:springfydrt/core/directories.dart';
import 'package:springfydrt/features/home/dtos/LocalSong.dart';
import 'package:springfydrt/features/notifier/notifier.dart';
import 'package:web_socket_channel/io.dart';
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

class _StreamingPageState extends State<StreamingPage> with WidgetsBindingObserver {
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
  Directory? _prevDirectory;
  AudioDTO? _currentSong;
  String? _hostUser;
  bool _isFollowerConnected = false;

  Directory? _selectedDirectory;
  late Future<List<Directory>> _directoriesFuture;

  @override
  void initState() {
    super.initState();
    _initialize();
    WidgetsBinding.instance.addObserver(this);

    StreamNotifier.instance.addListener(disconnect);
    StreamFolderNotifier.instance.addListener(() {
      if (!mounted) return;

      _refreshCloudSongs();
      setState(() {
        _directoriesFuture = getDirectoriesOnFolder();
      });
    }
    );
    _refreshCloudSongs();
    _directoriesFuture = getDirectoriesOnFolder();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      log("App cerrada completamente");
      _channel?.sink.close();

    }

    if (state == AppLifecycleState.paused) {
      log("App en segundo plano");
    }
  }
  @override
  void dispose() {

    _channel?.sink.close();
    WidgetsBinding.instance.removeObserver(this);
    StreamFolderNotifier.instance.removeListener(() {
      _refreshCloudSongs();
      setState(() {
        _directoriesFuture = getDirectoriesOnFolder();
      });
    });
    StreamNotifier.instance.removeListener(disconnect);
    _stateController.close();
    _pcmPlayer.close();
    super.dispose();
  }

  Future<void> disconnect() async {
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

    final otherUsers = availableUsers
        .where((user) => user != currentUser && user.isNotEmpty)
        .toList();

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
      final duoRequest =
      DuoRequest(username1: currentUser, username2: selectedUser);
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
          if (_duoState != DuoState.hosting &&
              !(_duoState == DuoState.following && _isFollowerConnected)) {
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
        log("Following niggaaaa");
        if (_usuarioActual == comando.seguidor) {
          final songs = await _cloudSongs;

          final songIndex =
          songs.indexWhere((s) => s.audioId == comando.musicId);
          if (songIndex != -1) {
            final song = songs[songIndex];
            log("following");
            setState(() {
              _currentSongIndex = songIndex;
              _currentSong = song;
              _hostUser = comando.anfitrion;
              _isFollowerConnected = false;
            });
            _emitState(DuoState.following);
            await _pcmPlayer.ensureReady();
          } else {
            log("Song with ID ${comando.musicId} not found.");
          }
        }
        break;

      case 'disconnect':
        await _pcmPlayer.stop();
        setState(() {
          _currentSong = null;
          _hostUser = null;
          _isFollowerConnected = false;
          _currentSongIndex = null;
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
        final newIndex =
        songs.indexWhere((song) => song.audioId == comando.musicId);

        if (newIndex != -1) {
          setState(() {
            _currentSongIndex = newIndex;
            _currentSong = songs[newIndex];
          });
          await _pcmPlayer.ensureReady();
        }
        break;

      default:
        log("Comando desconocido recibido: ${comando.comando}");
    }
  }

  Future<void> _skipToNextSong() async {
    _selectedDirectory= _prevDirectory;
    //sin hacer setState para que no se cambie en ui:DDD

    if (_selectedDirectory == null) return;

    final localSongs = await loadSongsFromFolderOrdered(_selectedDirectory!);
    if (localSongs.isEmpty) return;

    final cloudSongs = await _cloudSongs;
    int currentLocalIndex = localSongs.indexWhere((s) => s.videoId == _currentSong?.audioId);

    AudioDTO? nextCloudSong;
    int nextLocalIndex = currentLocalIndex;

    for (int i = 0; i < localSongs.length; i++) {
      nextLocalIndex = (nextLocalIndex + 1) % localSongs.length;
      final ls = localSongs[nextLocalIndex];
      try {
        nextCloudSong = cloudSongs.firstWhere((s) => s.audioId == ls.videoId);
        break;
      } catch (_) {
        continue;
      }
    }

    if (nextCloudSong != null) {
      setState(() {
        _currentSong = nextCloudSong;
        _currentSongIndex = cloudSongs.indexOf(nextCloudSong!);
      });
      _sendPlayerCommand('change', params: {'musicId': nextCloudSong.audioId});
      await _pcmPlayer.ensureReady();
    }
   _selectedDirectory=null;
  }

  Future<void> _skipToPreviousSong() async {
    _selectedDirectory= _prevDirectory;

    if (_selectedDirectory == null) return;

    final localSongs = await loadSongsFromFolderOrdered(_selectedDirectory!);
    if (localSongs.isEmpty) return;

    final cloudSongs = await _cloudSongs;
    int currentLocalIndex = localSongs.indexWhere((s) => s.videoId == _currentSong?.audioId);

    AudioDTO? prevCloudSong;
    int prevLocalIndex = currentLocalIndex;

    for (int i = 0; i < localSongs.length; i++) {
      prevLocalIndex = (prevLocalIndex - 1 + localSongs.length) % localSongs.length;
      final ls = localSongs[prevLocalIndex];
      try {
        prevCloudSong = cloudSongs.firstWhere((s) => s.audioId == ls.videoId);
        break;
      } catch (_) {
        continue;
      }
    }

    if (prevCloudSong != null) {
      setState(() {
        _currentSong = prevCloudSong;
        _currentSongIndex = cloudSongs.indexOf(prevCloudSong!);
      });
      _sendPlayerCommand('change', params: {'musicId': prevCloudSong.audioId});
      await _pcmPlayer.ensureReady();
    }
    _selectedDirectory=null;
  }

  Future<void> _refreshCloudSongs() async {
    setState(() {
      _cloudSongs = _apiCloud.allOnCloudWav();
    });
  }

  void _sendPlayerCommand(String command,
      {Map<String, dynamic> params = const {}}) {
    if ((_duoState != DuoState.hosting && _duoState != DuoState.following) ||
        _channel == null) return;

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

  Future<void> _startHosting(LocalSong localSong) async {
    if (_channel == null ||
        _usuarioActual == null ||
        _nombreUsuarioConexion == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No se puede iniciar, falta información de usuario o conexión.')));
      return;
    }

    final cloudSongs = await _cloudSongs;
    AudioDTO? songToHost;
    for (final cloudSong in cloudSongs) {
      if (cloudSong.audioId == localSong.videoId) {
        songToHost = cloudSong;
        break;
      }
    }

    if (songToHost == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La canción no está disponible en la nube.')));
      return;
    }

    setState(() {
      _currentSong = songToHost;
      _hostUser = _usuarioActual;
      _currentSongIndex =
          cloudSongs.indexWhere((s) => s.audioId == _currentSong?.audioId);
    });
    _emitState(DuoState.hosting);

    await _pcmPlayer.ensureReady();

    _sendPlayerCommand('start');
  }

  Future<void> _disconnect() async {
    _sendPlayerCommand('disconnect');

    await _pcmPlayer.close();

    setState(() {
      _currentSong = null;
      _hostUser = null;
      _isFollowerConnected = false;
      _currentSongIndex = null;
    });
    _emitState(DuoState.none);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dúo'),
        leading: _selectedDirectory != null
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _selectedDirectory = null;
            });
          },
        )
            : null,
        actions: [
          StreamBuilder<DuoState>(
            stream: _stateController.stream,
            initialData: _duoState,
            builder: (context, snap) {
              final state = snap.data ?? DuoState.none;
              if (state == DuoState.none) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _refreshCloudSongs();
                    setState(() {
                      _directoriesFuture = getDirectoriesOnFolder();
                    });
                  },
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
    if (_selectedDirectory == null) {
      return FutureBuilder<List<Directory>>(
        future: _directoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          if (snapshot.hasError) {
            return Text('Error al cargar directorios: ${snapshot.error}');
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Text('No hay directorios locales.');
          }

          final directories = snapshot.data!;
          return ListView.builder(
            itemCount: directories.length,
            itemBuilder: (context, index) {
              final directory = directories[index];
              final directoryName = directory.path.split('/').last;
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(directoryName),
                onTap: () {
                  setState(() {
                    _selectedDirectory = directory;
                  });
                },
              );
            },
          );
        },
      );
    } else {
      return FutureBuilder<List<LocalSong>>(
        future: loadSongsFromFolderOrdered(_selectedDirectory!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          if (snapshot.hasError) {
            return Text('Error al cargar canciones: ${snapshot.error}');
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('No hay canciones en este directorio.'));
          }

          final songs = snapshot.data!;
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(song.title),
                onTap: () {
                  setState(() {
                    _prevDirectory= _selectedDirectory;
                    _selectedDirectory = null;
                  });

                  PlayerNotifier.instance.notify();
                  _startHosting(song);
                },
              );
            },
          );
        },
      );
    }
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
                  onPressed: () => _skipToPreviousSong(),
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
                    await _skipToNextSong();
                  },
                  iconSize: 48,
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed:()async {
                setState(() {
                  _selectedDirectory=_prevDirectory;
                  _prevDirectory=null;
                });// logica cuando se desconecta y conecta no pierda el antiguo directorio

                await _disconnect();},
              child: const Text('Desconectar'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isFollowerConnected = !_isFollowerConnected;
                });
                _sendPlayerCommand(
                    _isFollowerConnected ? 'connect' : 'follower-disconnect');
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
