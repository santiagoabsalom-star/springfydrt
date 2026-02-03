import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../features/home/dtos/LocalSong.dart';
Future<Directory> getAudioDirectory() async {
  final directory = await getApplicationDocumentsDirectory();
  log('Audio dir: ${directory.path}');
  return directory;
}

Future<List<File>> getDownloadedMp3s() async {
  final dir = await getAudioDirectory();

  final files = dir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.mp3'))
      .toList();

  log('MP3 encontrados: ${files.length}');
  return files;
}

Future<List<LocalSong>> getLocalSongs() async {
  final files = await getDownloadedMp3s();

  return files.map((file) {
    final fileName = file.uri.pathSegments.last;
    
    // El formato es "videoId_NombreSanitizado.mp3"
    // Buscamos el primer guion bajo para separar el ID del resto
    final firstUnderscoreIndex = fileName.indexOf('_');
    
    String? videoId;
    String title;
    
    if (firstUnderscoreIndex != -1) {
      videoId = fileName.substring(0, firstUnderscoreIndex);
      title = fileName.substring(firstUnderscoreIndex + 1).replaceAll('.mp3', '');
    } else {
      title = fileName.replaceAll('.mp3', '');
    }

    return LocalSong(
      title: title,
      path: file.path,
      videoId: videoId,
    );
  }).toList();
}
