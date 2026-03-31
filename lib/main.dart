import 'dart:async';
import 'package:flutter/material.dart';
import 'package:springfydrt/custom/audio_service.dart';

import 'package:springfydrt/features/audiohandler/audiohandler.dart';


import 'app/app.dart';
late final MyAudioHandler audioHandler;
Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config:  AudioServiceConfig(
      androidNotificationChannelId: 'com.example.springfydrt.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      notificationColor: Colors.green
    ),
  );

//Mira como cuando cambio a segundo plano me llega una notificacion:D voy a intetnar
  runApp(const MyApp());
}
