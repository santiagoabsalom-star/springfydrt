import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:springfydrt/core/directories.dart';
import 'package:springfydrt/features/home/dtos/LocalSong.dart';
import 'package:springfydrt/features/notifier/notifier.dart';
import 'package:springfydrt/main.dart';
import 'package:web_socket_channel/io.dart';
import '../../core/log.dart';
import '../../custom/audio_service.dart';
import '../cloud/api/api_cloud.dart';
import '../cloud/dto/audioDto.dart';
import '../login/api/token.dart';
import 'api/wsconnect.dart';
import 'dto/comando.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

enum DuoState { none, connecting, hosting, following }
void pcmProcessorIsolate(SendPort toMainPort) {
  final fromMainPort = ReceivePort();
  toMainPort.send(fromMainPort.sendPort);

  fromMainPort.listen((message) {
    if (message is List<int>) {
      try{
        final Uint8List uint8list = message is Uint8List
            ? message
            : Uint8List.fromList(message);

        if (uint8list.isEmpty) return;

        final int validLength = uint8list.length % 2 == 0
            ? uint8list.length
            : uint8list.length - 1;

        if (validLength <= 0) return;

        final bd = ByteData.view(
            uint8list.buffer,
            uint8list.offsetInBytes,
            validLength
        );

        // 4. Enviamos al hilo principal
        toMainPort.send(PcmArrayInt16(bytes: bd));
      } catch (e) {
    Log.d("Error al procesar datos PCM: $e");
          }
    }
  });
}
class StreamingPage extends StatefulWidget {

  const StreamingPage({super.key});

  @override
  State<StreamingPage> createState() => _StreamingPageState();
}

class _StreamingPageState extends State<StreamingPage> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();
//ya reviso te quiero mostrar esto pls :((((
  Isolate? _pcmIsolate;
  SendPort? _toIsolatePort;
  ReceivePort? _fromIsolatePort;
  @override
  bool get wantKeepAlive => true;
  final ApiCloud _apiCloud = ApiCloud();
  late Future<List<AudioDTO>> _cloudSongs;
  double _currentSliderValue = 0.0;
  Timer? _progressTimer;
  final StreamController<DuoState> _stateController =
  StreamController<DuoState>.broadcast();
  DuoState _duoState = DuoState.connecting;
  bool _isStateRepeating= false;
  final StreamController<bool> _isStateRepeatingController= StreamController<bool>.broadcast();
  bool _showPlaylist = true;
  IOWebSocketChannel? _channel;
  String? _usuarioActual;
  int _duracionPlaylist=0;
  String? _nombreDuo;
  int? _currentSongIndex;
  Directory? _prevDirectory;
  AudioDTO? _currentSong;
  String? _hostUser;
  bool _isFollowerConnected = false;
   bool _isPlaying= false;
  Directory? _selectedDirectory;
  late Future<List<AudioDTO>> _currentPlaylist;
  late Future<List<Directory>> _directoriesFuture;
  bool _isDuoConnected= false;
  int _currentSongDuration=0;
  late List<String> currentPlaylist;
  final ValueNotifier<double> _progressNotifier = ValueNotifier(0);
  bool disconnectedFromSession= false;
  StreamSubscription? _audioHandlerSubscription;
  Future<void> initIsolate() async {
    _fromIsolatePort = ReceivePort();
    _pcmIsolate = await Isolate.spawn(pcmProcessorIsolate, _fromIsolatePort!.sendPort);

    _fromIsolatePort!.listen((message) {
      if (message is SendPort) {
        _toIsolatePort = message;
      } else if (message is PcmArrayInt16) {
        audioHandler.playpcm(message);
      }
    });
  }

  void _onDataReceived(List<int> bytes) {
    if (_toIsolatePort != null) {
      _toIsolatePort!.send(bytes);
    }
  }
  Future<void> init()async{
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Montevideo'));
    const androidSettings= AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings= DarwinInitializationSettings();
    const InitializationSettings initializationSettings= InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,

    );
    await notificationsPlugin.initialize(settings:  initializationSettings,
        onDidReceiveNotificationResponse: (payload){
          String? payloadString = payload.payload;
          switch (payloadString) {
            case "show_Duo":
              Log.d("show_Duo");
              break;
            case "show_duo":
              Log.d("show_duo");
              break;
          }

        }
    );
//ESTO ES LO QUE NECESITO PARA HACER LAS NOTIFICACIONES QUE ME PIDES:)))) DESPUES SIGO :)
  }
  // INSTANT NOTIFICATIONS:D
  //TODO: LOGICA DE NOTIFICACIONES PARA RECIBIR 3 NOTIFICACIONES:D
  //1--Santiago quiere escuchar musica contigo
  //2--Conectarme
  //3--Santiago se ha conectado
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    required String payload

  }) async {
    await   notificationsPlugin.show(
        id:1,
        title: title,
        body: body,

        notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'instant_notification_channel_id',
              'Instant notifications',
              channelDescription: 'Instant notification channel',
              importance: Importance.max,
              priority: Priority.max,
              icon: '@mipmap/ic_launcher',
              color: Colors.green,
           //   actions: <AndroidNotificationAction>[
             //   AndroidNotificationAction(
               // 'connectFollowing'
             //   ,"following",
               // icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
               // ),
                //AndroidNotificationAction(
              //   'Hola',
                // 'Puto',
                // cancelNotification: true,

                //)
              //]
            )
        ));
  }
  @override
  void initState() {
    _startProgressTimer();
    super.initState();
    _initialize();
    initIsolate();
    WidgetsBinding.instance.addObserver(this);
    init();
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



    _audioHandlerSubscription = audioHandler.customEvent.listen((event) {
      if (!mounted) return;
      if (_duoState == DuoState.hosting) {
        if (event == 'play') {
          _sendPlayerCommand('resume');
          setState(() => _isPlaying = true);
        } else if (event == 'pause') {
          _sendPlayerCommand('stop');
          setState(() => _isPlaying = false);
        } else if (event == 'skipToNext') {
          _skipToNextSong();
        } else if (event == 'skipToPrevious') {
          _skipToPreviousSong();
        } else if (event is Map && event['action'] == 'seek') {
          _sendPlayerCommand('move', params: {'segundosToMove': event['position']});
          _progressNotifier.value = (event['position'] as int).toDouble();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
        Log.d("App cerrada completamente");

        if(_duoState == DuoState.hosting){
          _channel?.sink.close();
          _sendPlayerCommand('disconnect');
          audioHandler.stoppcm();
        }
        else{
          _sendPlayerCommand('follower-disconnect');
          audioHandler.stoppcm();
        }

    }

    if (state == AppLifecycleState.paused) {

      Log.d("App en segundo plano");
    }
  }
  @override
  void dispose() {
    _pcmIsolate?.kill();
    WakelockPlus.disable();
    _progressTimer?.cancel();
    _audioHandlerSubscription?.cancel();
    if(_duoState == DuoState.hosting){
      _sendPlayerCommand('disconnect');

      audioHandler.stoppcm();
    }
    else{
      _sendPlayerCommand('follower-disconnect');
      audioHandler.stoppcm();
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

    audioHandler.close();

    super.dispose();
  }
  void _resetSlider() {
   _progressNotifier.value= 0.0;
  }
  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPlaying && _currentSongDuration > 0) {

        _progressNotifier.value = (_progressNotifier.value + 1.0)
            .clamp(0.0, _currentSongDuration.toDouble());
        if ((_duoState == DuoState.hosting) || (_duoState == DuoState.following && _isFollowerConnected)) {
          audioHandler.playbackState.add(
            audioHandler.playbackState.value.copyWith(
              updatePosition: Duration(
                milliseconds: (_progressNotifier.value * 1000).toInt(),
              ),
            ),
          );
        }
      }
    });
  }
  Future<void> _setPlaylist() async {

    final ls = await loadSongsFromFolderOrdered(_selectedDirectory!);
    final cloudSongs = await _cloudSongs;

    final ids = ls.map((s) => s.videoId).toSet();

    final playlist =
    cloudSongs.where((song) => ids.contains(song.audioId)).toList();

    setState(() {
      currentPlaylist=playlist.map((e) => e.audioId).toList();
      _currentPlaylist = Future.value(playlist);

    });Log.d("Playlist cargada exitosamente");
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
  Future<void> initializeAudioService()async{

    audioHandler.playFromDuo();
    audioHandler.updateNotificationInfo(_currentSong!);
    audioHandler.playbackState.add(audioHandler.playbackState.value.copyWith(
      queueIndex: _currentSongIndex,
      playing: true,
    ));

  }
  Future<void> disconnectFromSession() async{
    setState(() {
      _isPlaying=false;
    });
    _isStateRepeating=false;
    WakelockPlus.disable();
    _emitRepeatingState(_isStateRepeating);
    disconnectedFromSession=true;
    if(_duoState == DuoState.hosting){
      _channel!.sink.close();
      _channel=null;

      _resetSlider();
      _sendPlayerCommand('disconnect');
      await audioHandler.stoppcm();
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
      await audioHandler.stoppcm();
      _sendPlayerCommand('follower-disconnect');

      setState(() {
        _isFollowerConnected = false;
      });


    }
  }
  void _emitRepeatingState(bool isRepeating){
    _isStateRepeating=isRepeating;
    _isStateRepeatingController.add(isRepeating);
  }
  Future<void> disconnectFromPlayer() async {

    if(_duoState == DuoState.hosting){
      setState(() {
        _isPlaying=false;
      });
      WakelockPlus.disable();
      _isStateRepeating=false;
      _emitRepeatingState(_isStateRepeating);
      _resetSlider();
      _sendPlayerCommand('disconnect');
    await audioHandler.stoppcm();
    setState(() {
      _currentSong = null;
      _hostUser = null;
      _isFollowerConnected = false;
      _currentSongIndex = null;
    });
    _emitState(DuoState.none);
    }
    else{
      await audioHandler.stoppcm();
      _sendPlayerCommand('follower-disconnect');

      setState(() {
        _isFollowerConnected = false;
      });


    }
  }

  Future<List<AudioDTO>> buildCurrentPlaylist(List<String> currentPlaylist) async {

    final cloudSongs = await _cloudSongs;

    final songsById = {
      for (var song in cloudSongs) song.audioId: song
    };

    List<AudioDTO> audios = currentPlaylist.map((id) => songsById[id]).whereType<AudioDTO>().toList();
    _duracionPlaylist=(await _getPlaylistDuration(audios));

    return audios;
  }
  Future<int> _getPlaylistDuration(List<AudioDTO> playlist)async {
    int duration = 0;

    for (final song in playlist) {
      duration += song.duration;
    }
    return duration;
  }
  void _emitState(DuoState s) {
    _duoState = s;
    if (!_stateController.isClosed) {
      _stateController.add(s);
    }
  }

  Future<void> _initialize() async {
    await _obtainUser();
    await audioHandler.initialize();

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
         WakelockPlus.enable();
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

           Uint8List bytes= Uint8List.fromList(message);


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

          _onDataReceived(bytes);
        }
      }, onDone: () async {
        Log.d("WebSocket connection closed.");
        if (!mounted) return;
        if(disconnectedFromSession){
          disconnectedFromSession=false;
          return;

        }
        await audioHandler.stoppcm();
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
        showTopNotification(context, "Sesión terminada");

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

        await audioHandler.stoppcm();
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
        Log.d("following mode active");

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
              _progressNotifier.value=comando.currentPosition.toDouble();
              _isStateRepeating= comando.isRepeating;
              _currentPlaylist= buildCurrentPlaylist(comando.currentPlaylist);

              _hostUser = comando.anfitrion;
              _isFollowerConnected = false;
            });
            _emitState(DuoState.following);
           //showInstantNotification(id:1, title: "Duo", body: "$_nombreDuo esta escuchando, quieres escuchar?", payload: "show_Duo");
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
      case 'repeating':
        Log.d("repetir");
        _resetSlider();
      break;
      case 'repeat':
        Log.d("repetir");

        setState(() {
          _isStateRepeating=!_isStateRepeating;
          _emitRepeatingState(_isStateRepeating);
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
        _isStateRepeating=false;
        _setPlaylist();
        _emitRepeatingState(_isStateRepeating);
        _resetSlider();
        await audioHandler.stoppcm();
        setState(() {
          _emitState(DuoState.none);
          _currentSongDuration=0;
          _isPlaying= false;
          _currentSong = null;
          _hostUser = null;
          _isFollowerConnected = false;
          _currentSongIndex = null;
        });
        showNoti();
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
        if (_duoState == DuoState.following) {
          audioHandler.pausepcm();
          Log.d("Pausando");
        }

        break;

      case 'resume':

        setState(() {

          _isPlaying=true;
        });
        if (_duoState == DuoState.following && _isFollowerConnected){
         await audioHandler.resumepcm();}
        break;
      case 'move':
        _progressNotifier.value = comando.segundosToMove.toDouble() ;
        break;
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
          if(_duoState == DuoState.following && _isFollowerConnected){
          audioHandler.updateNotificationInfo(_currentSong!);
          audioHandler.playbackState.add(audioHandler.playbackState.value.copyWith(
              queueIndex: newIndex,
              playing: true,
          ));

          await audioHandler.ensureReady();
        }
        }
        break;

      default:
        Log.d("Comando desconocido recibido: ${comando.comando}");
    }
  }
Future<void> _changeSong(String songId) async {
  _resetSlider();
  setState(() {
    if(!_isPlaying) _isPlaying=true;
  });
  _selectedDirectory= _prevDirectory;
  final localSongs = await loadSongsFromFolderOrdered(_selectedDirectory!);
  if (localSongs.isEmpty) return;
final cloudSongs = await _cloudSongs;

setState(() {
  _currentSongIndex=localSongs.indexWhere((s) => s.videoId == songId);
  _currentSong= cloudSongs.firstWhere((s)=> s.audioId==songId);
});

  if(_currentSongIndex == -1){return;}

  audioHandler.updateNotificationInfo(_currentSong!);
  audioHandler.playbackState.add(audioHandler.playbackState.value.copyWith(
      queueIndex: _currentSongIndex,
      playing: true,
  ));

  _sendPlayerCommand('change', params: {'musicId': songId});
  await audioHandler.ensureReady();
  _selectedDirectory=null;
  }
  Future<void> _skipToNextSong() async {
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

      audioHandler.updateNotificationInfo(_currentSong!);
      audioHandler.playbackState.add(audioHandler.playbackState.value.copyWith(
          queueIndex: _currentSongIndex,
          playing: true,
      ));

      _sendPlayerCommand('change', params: {'musicId': nextCloudSong.audioId});
      await audioHandler.ensureReady();
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

      audioHandler.updateNotificationInfo(_currentSong!);
      audioHandler.playbackState.add(audioHandler.playbackState.value.copyWith(
          queueIndex: _currentSongIndex,
          playing: true,
      ));

      _sendPlayerCommand('change', params: {'musicId': prevCloudSong.audioId});
      await audioHandler.ensureReady();
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
          'currentPlaylist':  currentPlaylist,
          'currentPosition': _progressNotifier.value.toInt(),

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
      Log.d(jsonEncode(commandData));
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
    _duracionPlaylist=await _getPlaylistDuration(await _currentPlaylist);
  PlayerNotifier.instance.notify();

    setState(()  {
      _currentSong = songToHost;
      _hostUser = _usuarioActual;
      _currentSongIndex =
          cloudSongs.indexWhere((s) => s.audioId == _currentSong?.audioId);

    });
    showNoti();

    _emitState(DuoState.hosting);


    await audioHandler.ensureReady();

    _sendPlayerCommand('start');

  }

  Future<void> disconnectFromDuoPlayer() async {
    setState(() {
      _isPlaying=false;
    });
    WakelockPlus.disable();
    _isStateRepeating=false;
    _emitRepeatingState(_isStateRepeating);
    if(_duoState == DuoState.hosting){
      _sendPlayerCommand('disconnect');

      _resetSlider();
      await audioHandler.stoppcm();
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
      await audioHandler.stoppcm();

      _sendPlayerCommand('follower-disconnect');
      setState(() {
        _isFollowerConnected = false;
      });


    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                     Text(_isDuoConnected ? '$_nombreDuo esta conectado' : '$_nombreDuo esta desconectado'),
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () {
                   _showInfoDialog();
                      },
                    ),
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
                    _setPlaylist();

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
            "Nigga",
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          ValueListenableBuilder<double>(
            valueListenable: _progressNotifier,
            builder: (context, value, _) {
              return Slider(
                min: 0,
                max: _currentSongDuration.toDouble(),
                value: value.clamp(0.0, _currentSongDuration.toDouble()),
                onChanged: (v) {
                  if(isHost) {
                    _progressNotifier.value = v;
                  }
                  else{
                    showTopNotification(context, "Controles manejados por el anfitrión.");
                  }},
                onChangeEnd: (v) {
                  if(isHost){
                  _sendPlayerCommand('move', params: {'segundosToMove': v.toInt()});}else{
                    showTopNotification(context, "Controles manejados por el anfitrión.");
                  }
                },
              );
            },
          ),ValueListenableBuilder<double>(
            valueListenable: _progressNotifier,
            builder: (context, value, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(Duration(seconds: value.toInt()))),
                  Text(_formatDuration(Duration(seconds: _currentSongDuration))),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
    Text("Duracion de la playlist: ${_formatDuration(Duration(seconds: _duracionPlaylist))}" ) ,
    IconButton(
    icon: Icon(_showPlaylist ? Icons.expand_less : Icons.expand_more),
    onPressed: () {
    setState(() {
    _showPlaylist = !_showPlaylist;
    });
    },
    ),


          if (_showPlaylist)
            Expanded(
              child: _buildPlaylist(isHost),
            ),


          const SizedBox(height: 32),
          if (isHost) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StreamBuilder(stream: _isStateRepeatingController.stream,
                    initialData: _isStateRepeating, builder: (context,snapshot){
                  final isRepeating = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(isRepeating ? Icons.repeat_one : Icons.repeat),
                    onPressed: () {


                      _isStateRepeating=!isRepeating;
                      _sendPlayerCommand('repeat');
                      _emitRepeatingState(_isStateRepeating);

    });
    }),

                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => _skipToPreviousSong(),
                  iconSize: 48,
                ),
                IconButton(
                  icon: _isPlaying ? const Icon(Icons.pause) : const Icon(Icons.play_arrow),
                  onPressed: () {
                    if (_isPlaying) {
                      _sendPlayerCommand('stop');
                      audioHandler.pausepcm();
                    } else {
                      _sendPlayerCommand('resume');
                      audioHandler.resumepcm();
                    }
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
                });
                _isPlaying= false;
                await disconnectFromDuoPlayer();

                showNoti();
                },
              child: const Text('Desconectar'),
            ),
          ] else ...[
            StreamBuilder(stream: _isStateRepeatingController.stream,
                initialData: _isStateRepeating, builder: (context,snapshot){
                  final isRepeating = snapshot.data ?? false;
                  return IconButton(
                      icon: Icon(isRepeating ? Icons.repeat_one : Icons.repeat),
                      onPressed: () {
            showTopNotification(context, "Controles manejados por el anfitrión.");

                      });
                }),
            ElevatedButton(
              onPressed: () async {
              connectDistonnectFollowing();
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
  Future<void> connectDistonnectFollowing()async{
    PlayerNotifier.instance.notify();
    setState(() {
      _isFollowerConnected = !_isFollowerConnected;
    });

    showNoti();
    if (_isFollowerConnected) {

      PlayerNotifier.instance.notify();
      audioHandler.ensureReady();
    }
    _sendPlayerCommand(
        _isFollowerConnected ? 'follower-connect' : 'follower-disconnect');
  }


  Future<void> showNoti()async {
    final songs = await _cloudSongs;
    final songIndex = songs.indexWhere((s) => s.audioId == _currentSong?.audioId);
    if (_duoState==DuoState.hosting || (_duoState==DuoState.following && _isDuoConnected) ) {
      audioHandler.isFromDuo=true;
      audioHandler.updateNotificationInfo(_currentSong!);
      if (audioHandler.player.playing) {
        await audioHandler.player.stop();
      }
      if(_duoState==DuoState.hosting){
        audioHandler.isHost=true;
      }
      else{
        audioHandler.isHost=false;
      }
      audioHandler.playbackState.add(audioHandler.playbackState.value.copyWith(
        isPlayingFromDuo: true,
        playing: _isPlaying,
        queueIndex: songIndex,
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        processingState: AudioProcessingState.ready,
      ));
      await audioHandler.player.stop();
      await audioHandler.ensureReady();
    } else if(_duoState==DuoState.following && _isDuoConnected){
      audioHandler.isFromDuo=false;


      await audioHandler.stop();

      audioHandler.playbackState.add(audioHandler.playbackState.value.copyWith(
        playing: false,

        processingState: AudioProcessingState.idle,
      ));
    }
  }
  Widget _buildPlaylist(bool isHost) {

      return FutureBuilder<List<AudioDTO>>(
        future: _currentPlaylist,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay canciones en este directorio.'));
          }

          final songs = snapshot.data!;

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              bool isCurrentSong=_currentSong?.audioId == song.audioId;




              return Container(
                color: isCurrentSong ? Colors.grey : null,
                child: ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(
                    song.nombreAudio,
                    style: TextStyle(
                      color: isCurrentSong ? Colors.black : Colors.white,
                    ),

                  ),
                  onTap:
                      () {
                    setState(() {
                      if(isHost) {
                        _changeSong(song.audioId);
                      }
                      else{

                        showTopNotification(context,"Controles manejados por el anfitrión." );

                      }
                    });
                  },
                ),
              );
            },
          );
        },
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

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
            content: const Text(
                'Para garantizar una experiencia óptima y una sincronización precisa en la reproducción compartida, '
                    'es fundamental contar con una conexión a internet estable y de alta velocidad. '
                    'Las fluctuaciones en la red podrían afectar la calidad del audio o causar interrupciones durante el uso de esta función.'
            )
,
          actions: <Widget>[
            TextButton(
              child: const Text('Aceptar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        )
        ;

      },
    );

  }
}
