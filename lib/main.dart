import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:springfydrt/custom/audio_service.dart';

import 'package:springfydrt/features/audiohandler/audiohandler.dart';


import 'app/app.dart';
import 'core/log.dart';
late final MyAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if(Platform.isLinux){
    fixLinuxNumericLocale();
    JustAudioMediaKit.ensureInitialized();
  }

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
//await initialize();
//await showNotification("Hola", "No entendiste nada de lo que hice", "PAYLOAD TEST");
//Mira como cuando cambio a segundo plano me llega una notificacion:D voy a intetnar
  runApp(const MyApp());
}

typedef SetLocaleC = Pointer<Int8> Function(Int32 category, Pointer<Int8> locale);
typedef SetLocaleDart = Pointer<Int8> Function(int category, Pointer<Int8> locale);

void fixLinuxNumericLocale() {
  if (Platform.isLinux) {
    try {
      final DynamicLibrary stdlib = DynamicLibrary.open('libc.so.6');

      final SetLocaleDart setLocale = stdlib
          .lookup<NativeFunction<SetLocaleC>>('setlocale')
          .asFunction();

      const int lcNumeric = 1;

      final Pointer<Int8> cLocale = StringUtf8Pointer('C').toNativeUtf8().cast<Int8>();
      setLocale(lcNumeric, cLocale);

      Log.d('Linux LC_NUMERIC set to "C" successfully.');
    } catch (e) {
      Log.d(' Failed to set Linux locale: $e');
    }
  }
}

extension on String {
  Pointer<Int8> toNativeUtf8() {
    final units = utf8.encode(this);
    final Pointer<Int8> result = calloc<Int8>(units.length + 1);
    for (int i = 0; i < units.length; i++) {
      result[i] = units[i];
    }
    result[units.length] = 0;
    return result;
  }
}
//Ejemplo de notificacion para linux
/*
NotificationDetails notificationDetails =  NotificationDetails(
    linux: LinuxNotificationDetails(
      icon: AssetsLinuxIcon(
        'assets/icon.png',
        ),
        actions: <LinuxNotificationAction>[
          LinuxNotificationAction(key: 'ACTION_1', label:"HOla" ),
          LinuxNotificationAction(key: 'ACTION_2', label:"HOLA" )
        ]
    )
);
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
Future<void> initialize() async {
const LinuxInitializationSettings initializationSettingsLinux = LinuxInitializationSettings(defaultActionName: 'Open');
const InitializationSettings initializationSettings =
InitializationSettings(linux: initializationSettingsLinux);
await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

}

 Future<void> showNotification(String title, String body, String payload)async {

  flutterLocalNotificationsPlugin.show(id: 1,title: title,body: body, notificationDetails: notificationDetails, payload: payload);

}*/
