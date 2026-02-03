import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:rxdart/rxdart.dart';
import '../../main.dart'; // Para acceder a audioHandler

import '../home/dtos/LocalSong.dart';

class GlobalAudioPlayer {
  GlobalAudioPlayer._internal() {
    _init();
  }

  static final GlobalAudioPlayer instance = GlobalAudioPlayer._internal();

  final AppAudioPlayer _player = AppAudioPlayer();

  final List<LocalSong> _currentPlaylist = [];
  int _currentIndex = -1;

  AppAudioPlayer get player => _player;
  List<LocalSong> get currentPlaylist => List.unmodifiable(_currentPlaylist);

  final BehaviorSubject<LocalSong?> _currentSongSubject =
      BehaviorSubject.seeded(null);

  Stream<LocalSong?> get currentSongStream => _currentSongSubject.stream;
  LocalSong? get currentSong => _currentSongSubject.value;

  final BehaviorSubject<DurationState> _durationStateSubject =
      BehaviorSubject.seeded(DurationState(Duration.zero, Duration.zero));

  Stream<DurationState> get durationState => _durationStateSubject.stream;

  void _init() {
    _player.positionStream.listen((_) => _updateDurationState());
    _player.durationStream.listen((_) => _updateDurationState());
    _player.playingStream.listen((_) => _updateDurationState());

    Stream.periodic(const Duration(milliseconds: 200)).listen((_) {
      if (_player.isPlaying) {
        _updateDurationState();
      }
    });

    _player.playerCompletionStream.listen((_) {
      next();
    });

    // Sincronizar el estado del audioHandler con el sujeto local para la UI
    if (Platform.isAndroid) {
      audioHandler.mediaItem.listen((item) {
        if (item != null) {
          final song = _currentPlaylist.firstWhere(
            (s) => s.path == item.id,
            orElse: () => LocalSong(title: item.title, path: item.id),
          );
          _currentSongSubject.add(song);
        }
      });
    }
  }

  void _updateDurationState() {
    if (!_durationStateSubject.isClosed) {
      final newState = currentDurationState;
      if (newState.position != _durationStateSubject.value.position ||
          newState.total != _durationStateSubject.value.total) {
        _durationStateSubject.add(newState);
      }
    }
  }

  DurationState get currentDurationState => DurationState(
        _player.position,
        _player.duration ?? Duration.zero,
      );

  Stream<bool> get isPlayingStream =>
      _player.playingStream.startWith(_player.isPlaying).distinct();

  bool get isPlaying => _player.isPlaying;
  int get currentIndex => _currentIndex;

  Future<void> setPlaylist(
    List<LocalSong> songs, {
    int startIndex = 0,
  }) async {
    if (songs.isEmpty) return;

    _currentPlaylist
      ..clear()
      ..addAll(songs);

    _currentIndex = startIndex;

    if (Platform.isAndroid) {
      final mediaItems = songs.map((s) => MediaItem(
        id: s.path,
        album: "Local",
        title: s.title,
        artist: "Desconocido",
      )).toList();
      await audioHandler.loadPlaylist(mediaItems, startIndex: startIndex);
    } else {
      if (_currentIndex >= 0 && _currentIndex < _currentPlaylist.length) {
        await _playIndex(_currentIndex);
      }
    }
  }

  Future<void> _playIndex(int index) async {
    final song = _currentPlaylist[index];
    _currentSongSubject.add(song);
    _durationStateSubject.add(DurationState(Duration.zero, Duration.zero));
    await _player.playFile(song.path);
    _updateDurationState();
  }

  void play() => _player.resume();
  void pause() => _player.pause();
  void toggle() => _player.isPlaying ? pause() : play();

  void seek(Duration d) {
    _player.seek(d);
    _durationStateSubject.add(DurationState(d, _player.duration ?? Duration.zero));
  }

  void next() {
    if (Platform.isAndroid) {
      audioHandler.skipToNext();
    } else if (_currentIndex + 1 < _currentPlaylist.length) {
      _currentIndex++;
      _playIndex(_currentIndex);
    }
  }

  void previous() {
    if (Platform.isAndroid) {
      audioHandler.skipToPrevious();
    } else if (_currentIndex - 1 >= 0) {
      _currentIndex--;
      _playIndex(_currentIndex);
    }
  }

  void dispose() {
    _player.dispose();
    _currentSongSubject.close();
    _durationStateSubject.close();
  }
}

class DurationState {
  final Duration position;
  final Duration total;
  DurationState(this.position, this.total);
}

abstract class AppAudioPlayer {
  factory AppAudioPlayer() {
    if (Platform.isLinux) {
      return LinuxAudioPlayer();
    } else {
      return AndroidAudioPlayer();
    }
  }

  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;
  Stream<void> get playerCompletionStream;
  bool get isPlaying;
  Duration get position;
  Duration? get duration;

  Future<void> playFile(String path);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class AndroidAudioPlayer implements AppAudioPlayer {
  // Usamos el audioHandler global en lugar de una instancia privada de just_audio
  
  @override
  Stream<Duration> get positionStream => AudioService.position;

  @override
  Stream<Duration?> get durationStream => audioHandler.mediaItem.map((item) => item?.duration);

  @override
  Stream<bool> get playingStream => audioHandler.playbackState.map((state) => state.playing);

  @override
  Stream<void> get playerCompletionStream => audioHandler.playbackState
      .where((state) => state.processingState == AudioProcessingState.completed)
      .map((_) => null);

  @override
  bool get isPlaying => audioHandler.playbackState.value.playing;

  @override
  Duration get position => audioHandler.playbackState.value.position;

  @override
  Duration? get duration => audioHandler.mediaItem.value?.duration;

  @override
  Future<void> playFile(String path) async {
    // Esto lo maneja setPlaylist cargando la cola en el handler
  }

  @override
  Future<void> pause() => audioHandler.pause();

  @override
  Future<void> resume() => audioHandler.play();

  @override
  Future<void> stop() => audioHandler.stop();

  @override
  Future<void> seek(Duration position) => audioHandler.seek(position);

  @override
  Future<void> dispose() async {
    // El handler es global, no lo destruimos aquí
  }
}

class LinuxAudioPlayer implements AppAudioPlayer {
  final audioplayers.AudioPlayer _player = audioplayers.AudioPlayer();

  Duration _position = Duration.zero;
  Duration? _duration;

  LinuxAudioPlayer() {
    _player.onPositionChanged.listen((p) => _position = p);
    _player.onDurationChanged.listen((d) => _duration = d);
  }

  @override
  Stream<Duration> get positionStream => _player.onPositionChanged;

  @override
  Stream<Duration?> get durationStream => _player.onDurationChanged;

  @override
  Stream<bool> get playingStream =>
      _player.onPlayerStateChanged.map((s) => s == audioplayers.PlayerState.playing);

  @override
  Stream<void> get playerCompletionStream => _player.onPlayerComplete;

  @override
  bool get isPlaying => _player.state == audioplayers.PlayerState.playing;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  Future<void> playFile(String path) async {
    await _player.play(audioplayers.DeviceFileSource(path));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}
