import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../features/home/dtos/LocalSong.dart';
Future<Directory> getAudioDirectory() async {
  final directory = await getApplicationDocumentsDirectory();
  log('Audio dir: ${directory.path}');
  return directory;
}


Future<List<File>> getDownloadedMp3s() async {
  final dir = await getAudioDirectory();

  final files = await dir.list().where((e) => e is  File && e.path.endsWith(".mp3")).cast<File>().toList();

  log('MP3 encontrados: ${files.length}');
  return files;
}
Future<List<File>> getDownloadedMp3sFromFolder(Directory folder) async {


  final files = await folder.list().where((e) => e is  File && e.path.endsWith(".mp3")).cast<File>().toList();

  log('MP3 encontrados: ${files.length}');
  return files;
}
Future<Directory> createDirectory(String folderName) async {
  final path = await getAudioDirectory();
  final Directory newDirectory = Directory('${path.path}/$folderName');

  if (await newDirectory.exists()) {
    return newDirectory;
  } else {
    final Directory createdDir = await newDirectory.create(recursive: true);
    log('Directorio creado en: ${createdDir.path}');
    return createdDir;
  }
}
Future<void> renameDirectory(String newName, Directory folder)async {
  final newPath = folder.path.replaceAll(folder.path.split('/').last, newName);

try {
  await folder.rename(newPath);
  log('Directorio renombrado a: $newPath');
}catch(e){
  log("error al renombrar directorio $e");
}

}

//Future list file getSongsInCarpetas async {}
//TODO: GET CARPETAS CON CANCIONES
// ALGO COMO Future<List<File>> getCarpetas() async {
// final dir = await
// }

Future<List<Directory>> getDirectoriesOnFolder() async {
  try {
    final dir = await getAudioDirectory();
    if (!await dir.exists()) return [];
    return (await dir.list(recursive: false).toList())
        .whereType<Directory>()
        .toList();

  } catch (_) {
    return [];
  }
}
Future<List<LocalSong>> getSongsFromFolder(Directory folder) async {
  final files = await getDownloadedMp3sFromFolder(folder);

  return files.map((file) {
    final fileName = p.basename(file.path);

    final match = RegExp(r'\[([^\]]+)\]').firstMatch(fileName);

    final videoId = match?.group(1);

    String title = fileName;

    if (videoId != null) {
      title = fileName.replaceAll('[$videoId]', '').trim();
    }

    title = title.replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '');
    title = title.replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '');

    return LocalSong(
      title: title,
      path: file.path,
      videoId: videoId,
    );
  }).toList();
      }

Future<void> moveFile(LocalSong song, Directory destinationFolder) async {
    final file = File(song.path);
    try{

      await file.rename('${destinationFolder.path}/${song.title}.mp3');
      song.path='${destinationFolder.path}/${song.title}.mp3';
      log('Song movida con exito');
    }catch(e){
      log("Ha habido un error $e");
    }




}
Future<void> deleteFolder(Directory folder) async {
  try {
    if(folder.existsSync()){
      await folder.delete(recursive: true);
      log("Directorio borrado con exito");
    }
    else{
      return;
    }

  }catch(e){log("Error al intentar borrar este directorio");}
}
Future<List<LocalSong>> getLocalSongs() async {
  final rootDir = await getAudioDirectory();

  final entities = await rootDir.list(recursive: true, followLinks: false).toList();

  final files = entities
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith(".mp3"))
      .toList();

  return files.map((file) {
    final fileName = p.basename(file.path);

    final match = RegExp(r'\[([^\]]+)\]').firstMatch(fileName);

    final videoId = match?.group(1);

    String title = fileName;

    if (videoId != null) {
      title = fileName.replaceAll('[$videoId]', '').trim();
    }

    title = title.replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '');
    title = title.replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '');

    return LocalSong(
      title: title,
      path: file.path,
      videoId: videoId,
    );
  }).toList();
}


Future<File> _getLocalFile(String audioId, Directory dir) async {

  final files = await dir.list().where((e) => e is File).cast<File>().toList();
  final audio = files.firstWhere((f) => f.path.contains(audioId));
  String path= audio.path;
  log(path);
  return audio;
}
Future<void> deleteFile(String audioId, Directory dir) async {
  try {
    final File file = await _getLocalFile(audioId, dir);

    if (await file.exists()) {
      await file.delete();
      log('borrado exitoso.');
    } else {

    }
  } catch (e) {
    log('Error al borrar el archivo: $e');
  }
}
Future<void> saveOrder(Directory folder, List<LocalSong> songs) async {
  try {
    final orderFile = File(p.join(folder.path, 'order.json'));

    final order = songs.map((s) => p.basename(s.path)).toList();

    await orderFile.writeAsString(jsonEncode(order), flush: true);

  } catch (e, st) {
    print('saveOrder ERROR: $e\n$st');
  }}


Future<List<LocalSong>> loadSongsFromFolderOrdered(Directory folder) async {
  if (!await folder.exists()) return [];

  final entities = await folder.list(recursive: false, followLinks: false).toList();

  final mp3Files = entities
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.mp3'))
      .toList();

  List<LocalSong> songs = mp3Files.map((file) {
    final fileName = p.basename(file.path);

    final match = RegExp(r'\[([^\]]+)\]').firstMatch(fileName);

    final videoId = match?.group(1);

    String title = fileName;

    if (videoId != null) {
      title = fileName.replaceAll('[$videoId]', '').trim();
    }

    title = title.replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '');
    title = title.replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '');

    return LocalSong(
      title: title,
      path: file.path,
      videoId: videoId,
    );
  }).toList();

  final orderFile = File(p.join(folder.path, 'order.json'));
  if (!await orderFile.exists()) {
    return songs;
  }

  try {
    final raw = await orderFile.readAsString();
    final List<dynamic> decoded = jsonDecode(raw);
    final List<String> order = decoded.map((e) => e.toString()).toList();


    final Map<String, LocalSong> map = {
      for (final s in songs) p.basename(s.path): s
    };

    final List<LocalSong> ordered = [];

    for (final filename in order) {
      final song = map.remove(filename);
      if (song != null) ordered.add(song);
    }

    ordered.addAll(map.values);
    log("returning ordered");
    return ordered;
  } catch (e, st) {
    log("returning songs");
    return songs;

  }
}




