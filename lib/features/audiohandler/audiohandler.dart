import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  Future<void> reset() async {
    await _player.stop();
    await _player.setAudioSource(ConcatenatingAudioSource(children: []));

    queue.add([]);
    mediaItem.add(null);

    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(
      playbackState.value.copyWith(
        repeatMode: repeatMode,
      ),
    );

    await _player.setLoopMode(
      repeatMode == AudioServiceRepeatMode.one
          ? LoopMode.one
          : LoopMode.all,
    );
  }

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).listen((state) {
      playbackState.add(state.copyWith(
        repeatMode: playbackState.value.repeatMode,
      ));
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });

    _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration != null) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });

    _player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        final loopMode = _player.loopMode;

        if (loopMode == LoopMode.one) return;


        await skipToNext();
      }
    });

  }
  Stream<bool> get isRepeatingStream =>
      _player.loopModeStream.map((mode) => mode != LoopMode.off);

  @override
  Future<void> play() => _player.play();
  
  @override
  Future<void> pause() => _player.pause();
  
  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await super.stop();
  }

  @override
  Future<void> skipToNext() async{
    if(_player.loopMode==LoopMode.one) {
    _player.setLoopMode(LoopMode.all);
    _player.seekToNext();
    _player.setLoopMode(LoopMode.one);
    }
    else{
      _player.seekToNext();

    }


  }
  
  @override
  Future<void> skipToPrevious() async{
    if(_player.loopMode==LoopMode.one) {
      _player.setLoopMode(LoopMode.all);
      _player.seekToPrevious();
      _player.setLoopMode(LoopMode.one);
    }
    else{
      _player.seekToPrevious();

    }}
  
  @override
  Future<void> seek(Duration position) => _player.seek(position);



  Future<void> loadPlaylist(List<MediaItem> items, {int startIndex = 0}) async {
    final sources = items.map((item) {
      Uri uri;
      if (item.id.startsWith('http')) {
        uri = Uri.parse(item.id);
      } else {
        uri = Uri.file(item.id);
      }
      return AudioSource.uri(uri, tag: item);
    }).toList();

    queue.add(items);
    
    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: startIndex,
    );

    play();
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.playPause,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState] ?? AudioProcessingState.idle,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
