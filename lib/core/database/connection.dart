import 'package:drift/drift.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../features/home/dtos/LocalSong.dart';
import '../log.dart';

part 'connection.g.dart';

class Songs extends Table {
  TextColumn get id => text()();
  TextColumn get directoryPath => text()();

  @override
  Set<Column> get primaryKey => {id, directoryPath};
}
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  TextColumn get displayName => text()();

}
@DriftDatabase(tables: [Songs,Folders])
class MyDatabase extends _$MyDatabase {
  MyDatabase._internal() : super(_openConnection());
  static final MyDatabase instance = MyDatabase._internal();

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(folders);
      }
    },
  );
  @override
  int get schemaVersion => 2;
  Stream<int> watchDirectoryCount() {
    final countExp = folders.id.count();
    final query = selectOnly(folders)..addColumns([countExp]);

    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }


  Stream<Map<String, int>> watchAllSongCounts() {
    final countExp = songs.id.count();
    final query = selectOnly(songs)
      ..addColumns([songs.id, countExp])
      ..groupBy([songs.id]);
    return query.watch().map((rows) {
      return {
        for (final row in rows)
          row.read(songs.id)!: row.read(countExp)!,
      };
    });
  }
  Future<bool> folderExistsByPath(String path) async {
    final query = select(folders)..where((t) => t.path.equals(path));
    final result = await query.getSingleOrNull();
    return result != null;
  }

  Future<int> countDirectories()async{
    return select(folders).get().then((rows) => rows.length);
  }
  Future<int> addSongToDirectory(String id, String path) {
    return into(songs).insert(
      SongsCompanion.insert(id: id, directoryPath: path),
      mode: InsertMode.insertOrReplace,
    );
  }
  Stream<int> watchSongAppearances(String id) {
    return (select(songs)..where((t) => t.id.equals(id)))
        .watch()
        .map((rows) => rows.length);
  }

  Future<int> removeSongFromDirectory(String id, String path) {
    return (delete(songs)
      ..where((t) => t.id.equals(id))
      ..where((t) => t.directoryPath.equals(path)))
        .go();
  }
  Future<void> syncSongs(List<LocalSong> songsFromFiles) async {

  if(songsFromFiles.isNotEmpty){
    await batch((b) {
      for (var song in songsFromFiles) {
        b.insert(
          songs,
          SongsCompanion.insert(
            id: song.videoId ==null ? "null" : song.videoId!,
            directoryPath: song.path,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });}
  return;
  }

  Future<void> addDirectory(Directory directory, String nombre) async{
      into(folders).insert(FoldersCompanion.insert(path: directory.path, displayName:nombre), mode: InsertMode.insertOrReplace);
  }
  Future<int> countSongAppearances(String id) async {
    final query = select(songs)..where((t) => t.id.equals(id));
    final result = await query.get();
    return result.length;
  }
  Future<int> countDirectoriesForSong(String songId) async {
    final query = select(songs)..where((t) => t.id.equals(songId));
    final result = await query.get();
    return result.length;
  }
  Future<void> changeFolderName(String oldPath, String newPath) async {
    await (update(songs)..where((t) => t.directoryPath.equals(oldPath)))
        .write(SongsCompanion(
      directoryPath: Value(newPath),
    ));
  }
  Future<void> syncAndClean(List<Directory> dirs, List<LocalSong> songs1) async {
    for(var song in songs1){
      Log.d("${song.videoId}");
    }
    await transaction(() async {
    await clearAllData();

      await addAllDirectoriesAndSongs(dirs, songs1);
    });
  }
  Future<void> addAllDirectoriesAndSongs(
      List<Directory> directories,
      List<LocalSong> songsFromFiles
      ) async {
    if (directories.isEmpty && songsFromFiles.isEmpty) return;

    await transaction(() async {

      for (final dir in directories) {
       await into(folders).insertOnConflictUpdate(
          FoldersCompanion.insert(
            path: dir.path,
            displayName: dir.path.split('/').last,
          ),
        );
      }

      await batch((b) {
        for (final song in songsFromFiles) {

            b.insert(
              songs,
              SongsCompanion.insert(
                id: song.videoId!,
                directoryPath: song.path,
              ),
              mode: InsertMode.insertOrReplace,
            );

        }
      });
    });
  }

  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(songs).go();
      await delete(folders).go();
    });
  }

    Future<int> deleteDirectory(String path) async {
      if(await folderExistsByPath(path)){
      await (delete(folders)..where((t) => t.path.equals(path))).go();}

      return await (delete(songs)..where((t) => t.directoryPath.equals(path))).go();

  }

  Future<void> moveSong(String audioId, String oldPath, String newPath) async {

    await (update(songs)
      ..where((t) => t.id.equals(audioId))
      ..where((t) => t.directoryPath.equals(oldPath)))
        .write(SongsCompanion(
      directoryPath: Value(newPath),
    ));
  }

  Future<void> deleteSong(String audioId) async{
    await (delete(songs)..where((t) => t.id.equals(audioId))).go();
  }

}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}
