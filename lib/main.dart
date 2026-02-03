import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
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
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );

  runApp(const MyApp());
}