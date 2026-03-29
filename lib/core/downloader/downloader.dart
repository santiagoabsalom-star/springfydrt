import 'dart:io';
import 'dart:typed_data';

import '../log.dart';

Future<File> saveMp3ToStorageWithTitle(
    Uint8List mp3Bytes,
    String title,
    String videoId, Directory directory,
    ) async {


  String filePath = '${directory.path}/$title';
  final match = RegExp(r'\[([a-zA-Z0-9_-]{11})\](?=\.mp3$)').firstMatch(filePath);

  final id = match?.group(1);

  if(id==null){
    filePath='${directory.path}/$title[$videoId].mp3';
  }
  Log.d(filePath);

  final file = File(filePath);

  await file.writeAsBytes(mp3Bytes, flush: true);

  return file;
}

