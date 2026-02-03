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

  for (var file in files) {
    log('MP3: ${file.path}');
  }

  return files.map((file) {
    final name =
    file.uri.pathSegments.last.replaceAll('.mp3', '');

    return LocalSong(
      title: name,
      path: file.path,
    );
  }).toList();
}

