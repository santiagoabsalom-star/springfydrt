import 'dart:io';
import 'dart:typed_data';

Future<File> saveMp3ToStorageWithTitle(
    Uint8List mp3Bytes,
    String title,
    String videoId, Directory directory,
    ) async {



  final filePath = '${directory.path}/$title';

  final file = File(filePath);

  await file.writeAsBytes(mp3Bytes, flush: true);

  return file;
}

