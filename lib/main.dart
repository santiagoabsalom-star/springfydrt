import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio_mpv/just_audio_mpv.dart';
import 'app/app.dart';
import 'dart:async';

void main() {
  runZonedGuarded(() {
    if (Platform.isLinux) {
      JustAudioMpv.registerWith();
    }
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('Caught unhandled exception: $error');
    debugPrint(stack.toString());
  });
}
