import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:mp_audio_stream/mp_audio_stream.dart';
import 'package:springfydrt/custom/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:springfydrt/features/notifier/notifier.dart';
import 'package:springfydrt/features/streaming/api/p_c_m_player.dart';
import '../../core/log.dart';
import '../cloud/dto/audioDto.dart';

class Song{
  late MediaItem item;
  late bool hasBeenLoaded;
  Song(this.item, this.hasBeenLoaded);
}
class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final player = AudioPlayer();
  bool isOpenFromCloud=false;
  int currentIndex=0;
  final audioStream= getAudioStream();
  bool randomSong=false;
  int? previousIndex = -1;
  final PcmPlayer _pcmPlayer = PcmPlayer();
  bool isFromDuo = false;
  final _pcmPlayingSubject = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get pcmPlayingStream => _pcmPlayingSubject.stream;
  bool isHost= false;
  bool isSkippingFromButton=true;
  List<Song> songs=[];
  List<MediaItem> customQueue = [];
  List<MediaItem> customItem=[];
  Future<void> reset({bool isHasToReset=false}) async {
    if(isHasToReset){
      songs.clear();
      customQueue.clear();
      customItem.clear();
      currentIndex=0;
    }
    if(isFromDuo){
      mediaItem.add(null);
      if(!isHasToReset) {
        await player.pause();
      }

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
      if(repeatMode==AudioServiceRepeatMode.none){
        await player.setLoopMode(LoopMode.off);
      }else {
        await player.setLoopMode(
            repeatMode == AudioServiceRepeatMode.one
                ? LoopMode.one
                : LoopMode.all


        );
      }  }

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
player.sequenceStateStream.listen((sequenceState){});
    Rx.combineLatest2<PlaybackState, Duration, PlaybackState>(
      playbackStateStream,
      player.positionStream,
          (state, position) => state.copyWith(updatePosition: position),
    ).listen((state) {
      if (!isFromDuo) {
        playbackState.add(state);
      }
    });
    player.positionDiscontinuityStream.listen((discontinuity) {
      if (discontinuity.reason == PositionDiscontinuityReason.autoAdvance) {
        Log.d('Finished current track, continuing onto next');
      }
    });
    player.playbackEventStream.listen((event) async {
      if(event.processingState==ProcessingState.completed){

        if(randomSong){

          await randomSongLoad();
        }else{
        Future.microtask(() {
          Log.d("Skipping to next DDDD");
          skipToNext();
        });}
    }});

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
  Future<void> randomSongLoad()async {
    List availableSongs = songs.where((song) => !song.hasBeenLoaded).toList();

    if (availableSongs.isEmpty) {
      for (var song in songs) {
        song.hasBeenLoaded = false;
      }
      availableSongs = List.from(songs);
    }

    if (availableSongs.isNotEmpty) {
      int randomIndex = Random().nextInt(availableSongs.length);
      var selectedSong = availableSongs[randomIndex];

      selectedSong.hasBeenLoaded = true;

      Future.microtask(() async {
        await loadSong(selectedSong.item);
      });

      previousIndex = currentIndex;
      currentIndex = randomIndex;
      songs[randomIndex].hasBeenLoaded = true;
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
  Future<int> randomSongFromPlaylist(int playListLenght,int index) async {
    //Victor va a jugar
    //TODO retornar un indice desde 0...playListLenght, random, que no sea el indice actual
      return 1;

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
    if(songs.length>1) {
      if (randomSong) {
       Future.microtask((){randomSongLoad();});
      }else{

      if (player.loopMode == LoopMode.one) {
        await player.setLoopMode(LoopMode.all);
        if (currentIndex + 1 > (songs.length)) {
          previousIndex = currentIndex;
          await loadSong(songs[0].item);
          currentIndex = 0;
          Log.d("$previousIndex");
          Log.d("$currentIndex");
        }
        await loadSong(songs[currentIndex + 1].item);
        await player.setLoopMode(LoopMode.one);
      } else {
        if (currentIndex + 1 > (songs.length-1)) {
          previousIndex = -1;
          await loadSong(songs[0].item);

          currentIndex = 0;
          Log.d("$previousIndex");
          Log.d("$currentIndex");
        }
        else {
          previousIndex = currentIndex;
          Log.d('$currentIndex');
          await loadSong(songs[currentIndex + 1].item);
          currentIndex++;
          Log.d("$previousIndex");
          Log.d("$currentIndex");
        }
      }}

    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (isFromDuo) {
      if (isHost){
        customEvent.add('skipToPrevious');
    }return;
    }
    if(songs.length>1) {
      Log.d("$previousIndex");
      Log.d("$currentIndex");

      if (player.loopMode == LoopMode.one) {
        await player.setLoopMode(LoopMode.all);
        if (previousIndex == -1) {

          previousIndex = currentIndex;
          Log.d("$previousIndex");
          await loadSong(songs[songs.length - 1].item);
          currentIndex = songs.length - 1;
        }
        await loadSong(songs[previousIndex!].item);

        await player.setLoopMode(LoopMode.one);
      } else {
        if (previousIndex == -1) {
          Log.d('$previousIndex');

          await loadSong(songs[songs.length - 1].item);
          currentIndex = songs.length - 1;
          previousIndex=currentIndex-1;
        }
        else {
          Log.d('$previousIndex');
          Log.d('$currentIndex');
          await loadSong(songs[currentIndex-1].item);

          currentIndex=currentIndex-1;
          previousIndex=currentIndex-1;

        }
      }
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
    songs.clear();

    this.isFromDuo = isFromDuo;

    /*final sources = items.map((item) {
      Uri uri;
      if (item.id.startsWith('http')) {
        uri = Uri.parse(item.id);
      } else {
        uri = Uri.file(item.id);
      }
      return AudioSource.uri(uri, tag: item);
    }).toList();*/
    for (var item in items) {
      songs.add(Song(item, false));

    }
    songs[startIndex].hasBeenLoaded=true;
    if (!this.isFromDuo) {

      currentIndex=startIndex;
      previousIndex=currentIndex-1;
      Log.d('$currentIndex and $previousIndex');
      Log.d("${songs.length}");
      await loadSong(items[startIndex]);


    }
  }
Future<void> loadSong(MediaItem item) async {
    final source=AudioSource.file((item.id), tag: item);
    mediaItem.add(item);
    playbackState.add(playbackState.value.copyWith(queueIndex: 0));
    await player.setAudioSource(source);
    play();
}
  //PCM PLAYER METODOS
  Future<void> initialize() async {
    if(Platform.isAndroid){
    await _pcmPlayer.initialize();
    }
    else{

      audioStream.init(channels: 2,
      sampleRate: 48000);
    }
  }

  Future<void> resumepcm() async {
    if(Platform.isAndroid) {
      await _pcmPlayer.resume();
    }else{
      audioStream.resume();
    }
    if (isFromDuo) {
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
      ));
      _pcmPlayingSubject.add(true);
    }
  }

  Future<void> ensureReady() async {
    if(Platform.isAndroid){
    await _pcmPlayer.ensureReady();}else{


    }
  }
  Future<void> playmp(Float32List buffer) async{
    audioStream.push(buffer);

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
