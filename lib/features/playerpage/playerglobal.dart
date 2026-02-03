import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:rxdart/rxdart.dart';

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
    // Listen to player events and update our duration state subject
    _player.positionStream.listen((_) => _updateDurationState());
    _player.durationStream.listen((_) => _updateDurationState());
    _player.playingStream.listen((_) => _updateDurationState());

    // Periodic update for smooth progress bar and to ensure sync
    Stream.periodic(const Duration(milliseconds: 200)).listen((_) {
      if (_player.isPlaying) {
        _updateDurationState();
      }
    });

    _player.playerCompletionStream.listen((_) {
      next();
    });
  }

  void _updateDurationState() {
    if (!_durationStateSubject.isClosed) {
      final newState = currentDurationState;
      // Only add if it's different to avoid unnecessary rebuilds
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

    if (_currentIndex >= 0 && _currentIndex < _currentPlaylist.length) {
      await _playIndex(_currentIndex);
    }
  }

  Future<void> _playIndex(int index) async {
    final song = _currentPlaylist[index];
    
    // Update UI immediately for song title
    _currentSongSubject.add(song);
    
    // Reset duration state immediately so the bar doesn't show old values
    _durationStateSubject.add(DurationState(Duration.zero, Duration.zero));
    
    await _player.playFile(song.path);
    
    // After playing starts, update state again to be sure
    _updateDurationState();
  }

  void play() => _player.resume();
  void pause() => _player.pause();
  void toggle() => _player.isPlaying ? pause() : play();

  void seek(Duration d) {
    _player.seek(d);
    // Optimistically update the UI position
    _durationStateSubject.add(DurationState(d, _player.duration ?? Duration.zero));
  }

  void next() {
    if (_currentIndex + 1 < _currentPlaylist.length) {
      _currentIndex++;
      _playIndex(_currentIndex);
    }
  }

  void previous() {
    if (_currentIndex - 1 >= 0) {
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
  final just_audio.AudioPlayer _player = just_audio.AudioPlayer();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<void> get playerCompletionStream => _player.processingStateStream
      .where((state) => state == just_audio.ProcessingState.completed)
      .map((_) => null);

  @override
  bool get isPlaying => _player.playing;

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  Future<void> playFile(String path) async {
    await _player.stop();
    await _player.setFilePath(path);
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.play();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
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
