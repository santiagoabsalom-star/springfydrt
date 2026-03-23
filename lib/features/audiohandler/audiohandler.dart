import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:springfydrt/custom/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:springfydrt/features/notifier/notifier.dart';
import 'package:springfydrt/features/streaming/api/p_c_m_player.dart';

import '../../core/log.dart';
import '../cloud/dto/audioDto.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final player = AudioPlayer();
  final PcmPlayer _pcmPlayer = PcmPlayer();
  bool isFromDuo = false;
  final _pcmPlayingSubject = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get pcmPlayingStream => _pcmPlayingSubject.stream;
  bool isHost= false;

  Future<void> reset() async {
    if(isFromDuo){
      mediaItem.add(null);
      await player.pause();
      await player.setAudioSource(ConcatenatingAudioSource(children: []));
      queue.add([]);
      isFromDuo = false;
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
        isPlayingFromDuo: false,
        queueIndex: null,
      ));
    }
  
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(
      playbackState.value.copyWith(
        repeatMode: repeatMode,
      ),
    );

    await player.setLoopMode(
      repeatMode == AudioServiceRepeatMode.one
          ? LoopMode.one
          : LoopMode.all,
    );
  }

  MyAudioHandler() {
    final playbackStateStream = Rx.combineLatest4<PlaybackEvent, LoopMode, bool, int?, PlaybackState>(
        player.playbackEventStream,
        player.loopModeStream,
        player.playingStream,
        player.currentIndexStream,
            (event, loopMode, playing, index) {
          final repeatMode = const {
            LoopMode.off: AudioServiceRepeatMode.none,
            LoopMode.one: AudioServiceRepeatMode.one,
            LoopMode.all: AudioServiceRepeatMode.all,
          }[loopMode] ??
              AudioServiceRepeatMode.none;

          return PlaybackState(
            controls: [
              MediaControl.skipToPrevious,
              if (playing) MediaControl.pause else MediaControl.play,
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
            }[event.processingState] ??
                AudioProcessingState.idle,
            playing: playing,
            updatePosition: player.position,
            bufferedPosition: event.bufferedPosition,
            speed: player.speed,
            queueIndex: index,
            repeatMode: repeatMode,
          );
        });

    Rx.combineLatest2<PlaybackState, Duration, PlaybackState>(
      playbackStateStream,
      player.positionStream,
          (state, position) => state.copyWith(updatePosition: position),
    ).listen((state) {
      if (!isFromDuo) {
        playbackState.add(state);
      }
    });

    player.currentIndexStream.listen((index) {
      if (!isFromDuo && index != null && queue.value.isNotEmpty && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });

    player.durationStream.listen((duration) {
      if (!isFromDuo) {
        final item = mediaItem.value;
        if (item != null && duration != null) {
          mediaItem.add(item.copyWith(duration: duration));
        }
      }
    });

    player.processingStateStream.listen((state) async {
      if (!isFromDuo && state == ProcessingState.completed) {
        final loopMode = player.loopMode;
        if (loopMode == LoopMode.one) return;
        await skipToNext();
      }
    });
    _pcmPlayingSubject.listen((playing) {

      if (isFromDuo) {
        playbackState.add(playbackState.value.copyWith(
          playing: playing,
          controls: [
            MediaControl.skipToPrevious,
            playing ? MediaControl.pause : MediaControl.play, // Cambia el botón
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
        ));
      }
    });
    PlayerNotifier.instance.addListener(stopAndClearPlayer);
  }

  Future<void> updateNotificationInfo(AudioDTO song) async {
    final item = song.toMediaItem();
    mediaItem.add(item);
  }

  @override
  Future<void> onTaskRemoved() {
    PlayerNotifier.instance.removeListener(stopAndClearPlayer);
    player.dispose();
    _pcmPlayer.close();
    return super.onTaskRemoved();
  }

  Future<void> playFromDuo() async {
    Log.d('Inicializando duo y quitando el miniaudioPlayer');
    isFromDuo = true;
    if (player.playing) {
      await player.pause();
    }

    playbackState.add(playbackState.value.copyWith(
        playing: true,
        isPlayingFromDuo: true,
        processingState: AudioProcessingState.ready,
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
    ));
  }

  Future<void> playFromPlayer() async {
    isFromDuo = false;
    isHost=false;
    if (playbackState.value.isPlayingFromDuo == true) {
      playbackState.add(playbackState.value.copyWith(
          isPlayingFromDuo: false,
          processingState: AudioProcessingState.ready
      ));
    }
  }

  Future<void> stopAndClearPlayer() async {
    mediaItem.add(null);
    playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
    ));
  }

  Stream<bool> get isRepeatingStream =>
      player.loopModeStream.map((mode) => mode != LoopMode.off);

  @override
  Future<void> play() async {
    if (isFromDuo ) {
      if(isHost){
      await resumepcm();
      customEvent.add('play');}
      return;
    }
    await player.play();
  }

  @override
  Future<void> pause() async {
    if (isFromDuo) {
      if(isHost) {
        await pausepcm();
        customEvent.add('pause');
      }
      return;
    }
    await player.pause();
  }

  @override
  Future<void> stop() async {
    if (isFromDuo) {
      if((isHost) ) {
        await stoppcm();


        return super.stop();
      }
      }
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await player.stop();
  }

  @override
  Future<void> skipToNext() async {
    if (isFromDuo) {
      if(isHost) {
        customEvent.add('skipToNext');
      }
      return;
    }
    if (player.loopMode == LoopMode.one) {
      await player.setLoopMode(LoopMode.all);
      await player.seekToNext();
      await player.setLoopMode(LoopMode.one);
    } else {
      await player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (isFromDuo) {
      if (isHost){
        customEvent.add('skipToPrevious');
    }return;
    }
    if (player.loopMode == LoopMode.one) {
      await player.setLoopMode(LoopMode.all);
      await player.seekToPrevious();
      await player.setLoopMode(LoopMode.one);
    } else {
      await player.seekToPrevious();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (isFromDuo) {
      if(isHost){
      customEvent.add({'action': 'seek', 'position': position.inSeconds});}
      return;
    }
    await player.seek(position);
  }

  Future<void> loadPlaylist(List<MediaItem> items, bool isFromDuo, {int startIndex = 0}) async {
    this.isFromDuo = isFromDuo;

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
    if (items.isNotEmpty) {
      mediaItem.add(items[startIndex]);
      playbackState.add(playbackState.value.copyWith(queueIndex: startIndex));
    }

    if (!this.isFromDuo) {
      await player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: startIndex,
      );
      play();
    }
  }

  //PCM PLAYER METODOS
  Future<void> initialize() async {
    await _pcmPlayer.initialize();
  }

  Future<void> resumepcm() async {
    await _pcmPlayer.resume();
    if (isFromDuo) {
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
      ));
      _pcmPlayingSubject.add(true);
    }
  }

  Future<void> ensureReady() async {
    await _pcmPlayer.ensureReady();
  }

  Future<void> playpcm(PcmArrayInt16 buffer) async {
    await _pcmPlayer.play(buffer);
  }

  Future<void> pausepcm() async {
    await _pcmPlayer.pause();
    if (isFromDuo) {
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.ready,
      ));
      _pcmPlayingSubject.add(false);
    }
  }

  Future<void> stoppcm() async {
    await _pcmPlayer.stop();
    if (isFromDuo) {
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ));
    }
    _pcmPlayingSubject.add(false);
  }

  Future<void> close() async {
    await _pcmPlayer.close();
  }
}
