import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<File> saveMp3ToStorageWithTitle(
    Uint8List mp3Bytes,
    String title,
    String videoId, Directory directory,
    ) async {




  final filePath = '${directory.path}/$title.mp3';

  final file = File(filePath);

  await file.writeAsBytes(mp3Bytes, flush: true);

  return file;
}

