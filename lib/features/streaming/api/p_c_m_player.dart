
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

class PcmPlayer {
  final int sampleRate = 48000;
  final int channelCount = 2;

  bool isPaused = false;

  bool _ready = false;
  Future<void>? _initFuture;
Future<void>initialize(){
  _initFuture ??= () async {
    await FlutterPcmSound.setup(
      sampleRate: sampleRate,
      channelCount: channelCount,
      iosAllowBackgroundAudio: true,
    );

    FlutterPcmSound.start();

    isPaused = false;
    _ready = true;
  }();

  return _initFuture!;
}
  Future<void> ensureReady() async{
    if (_ready) return Future.value();

    isPaused = false;
    _ready = true;
    FlutterPcmSound.start();
  }

  Future<void> play(PcmArrayInt16 buffer) async {
    if (isPaused) return;

    await ensureReady();
    await FlutterPcmSound.feed(buffer);
  }

  Future<void> pause() async {
    if (isPaused) return;

    isPaused = true;


    // al hacer release, ya NO está ready
    _ready = false;
    _initFuture = null;
  }

  Future<void> resume() async {
    if (!isPaused) return;

    isPaused = false;
    await ensureReady();
  }

  Future<void> stop() async {
    isPaused = true;

    _ready = false;
    _initFuture = null;
  }

  Future<void> close() async {
    await stop();
  }
}

