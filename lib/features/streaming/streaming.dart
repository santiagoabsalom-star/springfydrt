import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:springfydrt/core/directories.dart';
import 'package:springfydrt/features/home/dtos/LocalSong.dart';
import 'package:springfydrt/features/notifier/notifier.dart';
import 'package:web_socket_channel/io.dart';
import '../../core/log.dart';
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
  double _currentSliderValue = 0.0;
  Timer? _progressTimer;
  final StreamController<DuoState> _stateController =
  StreamController<DuoState>.broadcast();
  DuoState _duoState = DuoState.connecting;

  IOWebSocketChannel? _channel;
  String? _usuarioActual;
  String? _nombreDuo;
  int? _currentSongIndex;
  Directory? _prevDirectory;
  AudioDTO? _currentSong;
  String? _hostUser;
  bool _isFollowerConnected = false;
   bool _isPlaying= false;
  Directory? _selectedDirectory;
  late Future<List<Directory>> _directoriesFuture;
  bool _isDuoConnected= false;
  int _currentSongDuration=0;
  bool disconnectedFromSession= false;
  @override
  void initState() {
    _startProgressTimer();
    super.initState();

    _initialize();

    WidgetsBinding.instance.addObserver(this);

    StreamFromSessionNotifier.instance.addListener(disconnectFromSession);
    StreamFromPlayerNotifier.instance.addListener(disconnectFromPlayer);
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
        Log.d("App cerrada completamente");

        if(_duoState == DuoState.hosting){
          _channel?.sink.close();
          _sendPlayerCommand('disconnect');
          _pcmPlayer.stop();
        }
        else{
          _sendPlayerCommand('follower-disconnect');
          _pcmPlayer.stop();
        }

    }

    if (state == AppLifecycleState.paused) {
      Log.d("App en segundo plano");
    }
  }
  @override
  void dispose() {
    _progressTimer?.cancel();
    if(_duoState == DuoState.hosting){
      _sendPlayerCommand('disconnect');

      _pcmPlayer.stop();
    }
    else{
      _sendPlayerCommand('follower-disconnect');
      _pcmPlayer.stop();
    }
    WidgetsBinding.instance.removeObserver(this);
    StreamFolderNotifier.instance.removeListener(() {
      _refreshCloudSongs();
      setState(() {
        _directoriesFuture = getDirectoriesOnFolder();
      });
    });
    StreamFromSessionNotifier.instance.removeListener(disconnectFromSession);
    StreamFromPlayerNotifier.instance.removeListener(disconnectFromPlayer);
    _stateController.close();

    _pcmPlayer.close();

    super.dispose();
  }
  void _resetSlider() {
    setState(() {
      _currentSliderValue = 0.0;
    });
  }
  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPlaying && _currentSongDuration > 0) {
        setState(() {
          _currentSliderValue = (_currentSliderValue + 1).clamp(0.0, _currentSongDuration.toDouble());
        });
      }
    });
  }
  void isDuoConnected() {
    Log.d("Enviando verificacion de conexion");

    _sendPlayerCommand("is-duo-connected");

  }
Future<void> obtenerDuo() async {
    if(_duoState == DuoState.hosting || _duoState == DuoState.following){
      final String? user = await obtainUserConection();
      setState(() {
        _nombreDuo=user;

      });
    }
      
  }
  Future<void> disconnectFromSession() async{
    setState(() {
      _isPlaying=false;
    });
    disconnectedFromSession=true;
    if(_duoState == DuoState.hosting){
      _channel!.sink.close();
      _channel=null;

      _resetSlider();
      _sendPlayerCommand('disconnect');
      await _pcmPlayer.stop();
      setState(() {
        _currentSong = null;
        _usuarioActual=null;
        _nombreDuo=null;
        _channel=null;
        _hostUser = null;
        _isFollowerConnected = false;
        _currentSongIndex = null;
      });
      _emitState(DuoState.none);
    }
    else{

      _channel!.sink.close();
      _channel=null;
      await _pcmPlayer.stop();
      _sendPlayerCommand('follower-disconnect');

      setState(() {
        _isFollowerConnected = false;
      });


    }
  }
  Future<void> disconnectFromPlayer() async {
    setState(() {
      _isPlaying=false;
    });
    if(_duoState == DuoState.hosting){

      _resetSlider();
      _sendPlayerCommand('disconnect');
    await _pcmPlayer.stop();
    setState(() {
      _currentSong = null;
      _hostUser = null;
      _isFollowerConnected = false;
      _currentSongIndex = null;
    });
    _emitState(DuoState.none);
    }
    else{
      await _pcmPlayer.stop();
      _sendPlayerCommand('follower-disconnect');

      setState(() {
        _isFollowerConnected = false;
      });


    }
  }

  
  void _emitState(DuoState s) {
    _duoState = s;
    if (!_stateController.isClosed) {
      _stateController.add(s);
    }
  }

  Future<void> _initialize() async {
    await _obtainUser();
    await _pcmPlayer.initialize();

    _emitState(DuoState.connecting);


    final user = await obtainUserConection();
    if (user != null && user.isNotEmpty) {
      _nombreDuo = user;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showUserSelectionDialog();
      });
    }
    if (mounted) {
      if (await hasConnection()) {
        _connect();

        Log.d("WebSocket connected.");
      } else {
        Log.d("No hay conexión a internet");
      }

    }
    if (_duoState == DuoState.connecting) {
      _emitState(DuoState.none);
    }
  }

  Future<void> _obtainUser() async {
    final token = await TokenStorage.getToken();
    Log.d("Token: $token");
    if (token != null) {
      _usuarioActual = await TokenStorage.getUsername();
      Log.d("Usuario actual: $_usuarioActual");
    } else {
      Log.d("No se pudo obtener el usuario actual.");
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
        _nombreDuo = selectedUser;
        Log.d("currentUser: $currentUser");
        Log.d("_nombreUsuarioConexion: $_nombreDuo");
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



  Future<bool> hasConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();

    return connectivityResult != ConnectivityResult.none;
  }
  Future<void> _connect() async {
    if (_usuarioActual == null) return;

    Map<String, String> userHeader = {'Usuario': _usuarioActual!};

    bool _wavHeaderSkipped = false;
    int _wavHeaderBytesPending = 44;

    try {
      if (mounted) {
        if (await hasConnection()) {
          _channel = await connect(userHeader);

        } else {
          Log.d("No hay conexión a internet");
        }
      }

      isDuoConnected();
      _channel!.stream.listen((message) async {
        if (message is String) {
          final comando = ComandoDTO.fromJson(jsonDecode(message));
          Log.d(message.toString());
          Log.d(comando.comando);
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
        Log.d("WebSocket connection closed.");
        if (!mounted) return;
        if(disconnectedFromSession){
          disconnectedFromSession=false;
          return;

        }
        await _pcmPlayer.stop();
        setState(() {
          _isPlaying= false;
          _currentSongIndex = null;
          _currentSliderValue=0.0;
          _currentSongDuration=0;
          _currentSong = null;
          _hostUser = null;
          _isFollowerConnected = false;
        });
        _emitState(DuoState.none);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión dúo terminada.')),
        );
        if (mounted) {
          if (await hasConnection()) {
            _channel = await connect(userHeader);
            Log.d("WebSocket connected.");
          } else {
            Log.d("No hay conexión a internet");
          }
        }
        }, onError: (error) async {
        Log.d("WebSocket error: $error");
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
      Log.d("Failed to connect: $e");
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
        _resetSlider();
        Log.d("following niggaaaa");

        if (_usuarioActual == comando.seguidor) {
          final songs = await _cloudSongs;

          final songIndex =
          songs.indexWhere((s) => s.audioId == comando.musicId);
          if (songIndex != -1) {
            final song = songs[songIndex];
            Log.d("current song duration ${comando.duration}");
            setState(() {
              Log.d(comando.isPlaying ? 'true' : 'false');
              _isPlaying=comando.isPlaying;
              _currentSongIndex = songIndex;
              _currentSong = song;
              _currentSliderValue=comando.currentPosition.toDouble();


              _hostUser = comando.anfitrion;
              _isFollowerConnected = false;
            });
            _emitState(DuoState.following);
            await _pcmPlayer.ensureReady();
          } else {
            Log.d("Song with ID ${comando.musicId} not found.");
          }
        }
        break;
      case 'finished':
        _skipToNextSong();
      case 'duo-connected':
        Log.d("duo conectado");
        setState(() {
          _isDuoConnected= true;
        });
        break;
      case 'duo-disconnected':
        Log.d("duo desconectado");
        setState(() {
          Log.d("cambiando estado");
          _isDuoConnected= false;
        });
        break;
      case 'disconnect':
        Log.d("recibiendo disconnect");
        _resetSlider();
        await _pcmPlayer.stop();
        setState(() {
          _currentSongDuration=0;
          _isPlaying= false;
          _currentSong = null;
          _hostUser = null;
          _isFollowerConnected = false;
          _currentSongIndex = null;
        });
        _emitState(DuoState.none);
        break;
      case 'duration':
        Log.d("Recibiendo duracion ${comando.duration}");
        setState(() {
          _currentSongDuration = comando.duration;
        });
        break;
      case 'follower-connect':
        setState(() {
          _isFollowerConnected = true;
        });
        break;
      case 'follower-disconnect':
        setState(() {
          _isFollowerConnected = false;
        });
        break;

      case 'stop':
        Log.d("recibiendo stop");
        setState(() {
          Log.d("cambiando a false");
          _isPlaying=false;
        });
        if (_duoState == DuoState.following) await _pcmPlayer.stop();
        break;

      case 'resume':
        setState(() {
          _isPlaying=true;
        });
        if (_duoState == DuoState.following) await _pcmPlayer.resume();
        break;
      case 'move':
        setState(() {
          _currentSliderValue=comando.segundosToMove.toDouble();
        });
      case 'change':

        _resetSlider();

        final songs = await _cloudSongs;
        final newIndex =
        songs.indexWhere((song) => song.audioId == comando.musicId);

        if (newIndex != -1) {
          setState(() {
            if(!_isPlaying) _isPlaying=true;
            _currentSongIndex = newIndex;
            _currentSong = songs[newIndex];
          });
          await _pcmPlayer.ensureReady();
        }
        break;

      default:
        Log.d("Comando desconocido recibido: ${comando.comando}");
    }
  }

  Future<void> _skipToNextSong() async {
    _resetSlider();
    setState(() {
      if(!_isPlaying) _isPlaying=true;
    });
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
    _resetSlider();
    setState(() {
      if(!_isPlaying) _isPlaying=true;
    });
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

    final Map<String, dynamic> commandData;
    if(command=='is-duo-connected'){
      Log.d("Enviando verificacion de conexion");
      commandData={
        'comando':command,
        'anfitrion':_usuarioActual,
        ...params,
      };
      _channel!.sink.add(jsonEncode(commandData));
    }
    else {
      if ((_duoState != DuoState.hosting && _duoState != DuoState.following) ||
          _channel == null) return;


      if (_duoState == DuoState.hosting) {
        commandData = {
          'comando': command,
          'anfitrion': _usuarioActual,
          'seguidor': _nombreDuo,
          'musicId': _currentSong?.audioId,
          'isPlaying': _isPlaying,
          'currentPosition': _currentSliderValue.toInt(),

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

  }

  Future<void> _startHosting(LocalSong localSong) async {

    _isPlaying=true;
    if (_channel == null ||
        _usuarioActual == null ||
        _nombreDuo == null) {

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
  PlayerNotifier.instance.notify();

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

  Future<void> disconnectFromDuoPlayer() async {
    setState(() {
      _isPlaying=false;
    });
    if(_duoState == DuoState.hosting){
      _sendPlayerCommand('disconnect');

      _resetSlider();
      await _pcmPlayer.stop();
      setState(() {
        _currentSong = null;
        _hostUser = null;
        _isFollowerConnected = false;
        _currentSongIndex = null;
        _prevDirectory=null;
      });
      _emitState(DuoState.none);
    }
    else{
      await _pcmPlayer.stop();

      _sendPlayerCommand('follower-disconnect');
      setState(() {
        _isFollowerConnected = false;
      });


    }
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

                return Row(
                  children: [
                     Text(_isDuoConnected ? '$_nombreDuo esta conectado' : '$_nombreDuo esta desconectado'), // Tu widget al lado del botón
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        _refreshCloudSongs();
                        setState(() {
                          _directoriesFuture = getDirectoriesOnFolder();
                        });
                      },
                    ),
                  ],
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
          Slider(
            min: 0,max: _currentSongDuration.toDouble(),
            value: _currentSliderValue.clamp(0.0, _currentSongDuration.toDouble()),
            onChanged: (value) {
              if(_duoState!=DuoState.hosting){
                showTopNotification(context, "Controles manejados por el anfitrión.");
              return;
              }
              setState(() {
                _currentSliderValue = value;
              });
            },
            onChangeEnd: (value) {
              _sendPlayerCommand('move', params: {'segundosToMove': value.toInt()});
            },
          ),Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(Duration(seconds: _currentSliderValue.toInt()))),
                Text(_formatDuration(Duration(seconds: _currentSongDuration))),
              ],
            ),
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
                  icon: _isPlaying ? const Icon(Icons.pause) : const Icon(Icons.play_arrow),
                  onPressed: () {
                    _isPlaying ? _sendPlayerCommand('stop')  : _sendPlayerCommand('resume');
                    setState(() {
                      _isPlaying = !_isPlaying;
                    });


                    },
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
            Text(_isFollowerConnected ? '$_nombreDuo esta conectado' : '$_nombreDuo esta desconectado'),
            ElevatedButton(
              onPressed:()async {
                setState(() {
                  _selectedDirectory=_prevDirectory;
                  _prevDirectory=null;
                });// logica cuando se desconecta y conecta no pierda el antiguo directorio
                _isPlaying= false;
                await disconnectFromDuoPlayer();},
              child: const Text('Desconectar'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () {
                PlayerNotifier.instance.notify();
                setState(() {
                  _isFollowerConnected = !_isFollowerConnected;
                });

                if (_isFollowerConnected) {

                  PlayerNotifier.instance.notify();
                   _pcmPlayer.ensureReady();
                }
                _sendPlayerCommand(
                    _isFollowerConnected ? 'follower-connect' : 'follower-disconnect');
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
  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }
  void showTopNotification(BuildContext context, String message) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 60,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                  )
                ],
              ),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }
}
