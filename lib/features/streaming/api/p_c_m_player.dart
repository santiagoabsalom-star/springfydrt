import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

class PcmPlayer {
  final int sampleRate = 48000;
  final int channelCount = 2;

  bool _isPaused = false;

  bool _ready = false;
  Future<void>? _initFuture;

  Future<void> ensureReady() {
    _initFuture ??= () async {
      await FlutterPcmSound.setup(
        sampleRate: sampleRate,
        channelCount: channelCount,
        iosAllowBackgroundAudio: true,
      );

      await FlutterPcmSound.start();

      _isPaused = false;
      _ready = true;
    }();

    return _initFuture!;
  }

  Future<void> play(PcmArrayInt16 buffer) async {
    if (_isPaused) return;

    await ensureReady();
    await FlutterPcmSound.feed(buffer);
  }

  Future<void> pause() async {
    if (_isPaused) return;

    _isPaused = true;


    // al hacer release, ya NO está ready
    _ready = false;
    _initFuture = null;
  }

  Future<void> resume() async {
    if (!_isPaused) return;

    _isPaused = false;
    await ensureReady();
  }

  Future<void> stop() async {
    _isPaused = true;

    _ready = false;
    _initFuture = null;
  }

  Future<void> close() async {
    await stop();
  }
}

