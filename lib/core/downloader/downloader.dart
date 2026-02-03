import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<File> saveMp3ToStorageWithTitle(
    Uint8List mp3Bytes,
    String title,
    String videoId,
    ) async {

  final directory = await getApplicationDocumentsDirectory();

  final safeTitle = sanitizeFileName(title);
  // Formato: videoId_titulo.mp3
  final filePath = '${directory.path}/${videoId}_$safeTitle.mp3';

  final file = File(filePath);

  await file.writeAsBytes(mp3Bytes, flush: true);

  return file;
}
String sanitizeFileName(String input) {
  return input
  // 1. Limpiar entidades HTML
      .replaceAll("&amp;", "and")
      .replaceAll("&quot;", "")
      .replaceAll("&#39;", "")
     .replaceAll('ñ', 'n')
      .replaceAll('Ñ', 'N')
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')

  // 3. Eliminar caracteres reservados que MPV usa como comandos
      .replaceAll(RegExp(r'[\\/:*?"<>|()\[\]]'), '')

  // 4. Reemplazar espacios por guiones bajos
      .replaceAll(RegExp(r'\s+'), '_')

  // 5. Limpieza final
      .trim();
}
