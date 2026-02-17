import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

class PcmPlayer {
  final int sampleRate = 48000;
  final int channelCount = 2;
  bool _isPaused = false;

  Future<void> init() async {
    //Inicializar flutterpcmsound
    await FlutterPcmSound.setup(
      sampleRate: sampleRate,
      channelCount: channelCount,
      iosAllowBackgroundAudio: true,
    );
    _isPaused = false;
  }

  Future<void> play(PcmArrayInt16 buffer) async {
    if (_isPaused) {
      return;
    }
    await FlutterPcmSound.start();
    //Reproducir musica
    await FlutterPcmSound.feed(buffer);
  }

  Future<void> pause() async {
    // Pausar musica
    // The flutter_pcm_sound library does not provide a pause function.
    // We will release the player, which stops the sound.
    if (!_isPaused) {
      _isPaused = true;
      await FlutterPcmSound.release();
    }
  }

  Future<void> resume() async {
    // Reanudar musica
    // To resume, we need to re-initialize the player.
    if (_isPaused) {
      await init();
    }
  }

  Future<void> repeat() async {
    // Repetir musica en distintos modos:D
  }

  Future<void> stop() async {
    // Parar musica y liberar recursos
    _isPaused = true;
    await FlutterPcmSound.release();
  }
}
