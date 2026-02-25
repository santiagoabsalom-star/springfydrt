import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/directories.dart';
import '../home/dtos/LocalSong.dart';
import '../notifier/notifier.dart';
import '../playerpage/playerpage.dart';

class DownloadedSongsPage extends StatefulWidget {
  const DownloadedSongsPage({super.key});

  @override
  State<DownloadedSongsPage> createState() => _DownloadedSongsPageState();
}

class _DownloadedSongsPageState extends State<DownloadedSongsPage> {
  Directory? selectedFolder;
  List<Directory> folders = [];
  List<File> songsInFolder = [];
  bool loading = true;

  late Future<List<LocalSong>> songs;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late TextEditingController createDirController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _loadSongs();
    _loadDirectories();
    DownloadsNotifier.instance.addListener(_loadSongs);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    createDirController= TextEditingController();
  }

  @override
  void dispose() {
    DownloadsNotifier.instance.removeListener(_loadSongs);

    _searchController.dispose();
    createDirController.dispose();
    super.dispose();
  }
void _loadDirectories() {
    setState(() {
      getDirectoriesOnFolder().then((value) => folders = value);
    });
  }
  Future<void> _loadSongs() async {
    if (selectedFolder == null) {
      setState(() {
        songsInFolder = [];
        loading = false;
      });
      return;
    }

    setState(() => loading = true);

    final loaded = await loadSongsFromFolderOrdered(selectedFolder!);

    setState(() {
      songsInFolder = loaded.cast<File>();
      loading = false;
    });
  }

  Future<void> _refreshData() async{
    _loadDirectories();
    _loadSongs();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        leading: selectedFolder != null
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              selectedFolder = null;
            });
          },
        )
            : null,
        actions: [
          ? selectedFolder != null ? null:
          IconButton(
            icon: const Icon(Icons.add),
                onPressed:() async {
              final nombredir = await openCreateDirDialog();
              if(nombredir== null || nombredir.isEmpty){
                return;
              }
              await createDirectory(nombredir);
              await _refreshData();
              },
          )  ,
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
            ),
          ),
        ),
      ),

      body: selectedFolder == null
    ? FutureBuilder<List<Directory>>(
        future: getDirectoriesOnFolder(),
    builder: (context, snapshot) {
    if (!snapshot.hasData) {
    return const Center(child: CircularProgressIndicator());
    }

    final folders = snapshot.data!;

    return ListView.builder(
    itemCount: folders.length,
    itemBuilder: (context, index) {
    final folder = folders[index];
    final folderName = folder.path.split('/').last;

    return ListTile(
    leading: const Icon(Icons.folder),
    title: Text(folderName),
      trailing:       PopupMenuButton(itemBuilder: (context) =>
      [
        PopupMenuItem(
            child: TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final newnombredir = await openRenameDirDialog();
                if(newnombredir== null || newnombredir.isEmpty){
                  return;
                }
                await renameDirectory(newnombredir, folder);
                await _refreshData();
              }, child:Text("Renombrar playlist"),
            )
        ),
        PopupMenuItem(
            child: TextButton(
              onPressed: () async {
                Navigator.pop(context);

                if(await deleteDirDialog()==true){

                  await deleteFolder(folder);
                  CloudNotifier.instance.notify();
                  await _refreshData();

                }

                else{
                  return;
                }
              }, child:Text("Eliminar playlist"),
            )
        ),

      ],

      ),
    onTap: () {
    setState(() {
    selectedFolder = folder;
                                });
                            },
                         );
                     },
               );
            },

      ) :FutureBuilder<List<LocalSong>>(
        future: loadSongsFromFolderOrdered(selectedFolder!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay canciones descargadas en esta playlist'));
          }

          final list = snapshot.data!.where((song) {
            return song.title.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          if (list.isEmpty) {
            return const Center(child: Text('No se encontraron canciones'));
          }



          return ReorderableListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final song = list[index];

              return ListTile(
                key: ValueKey(song.path),
                leading: const Icon(Icons.music_note),
                title: Text(song.title),
                trailing:       PopupMenuButton(itemBuilder: (context) =>
                [
                    PopupMenuItem(
                    onTap: () async {
              await Future.delayed(const Duration(milliseconds: 0));

              final Directory? folder = await moveDialog();
              if (folder == null) return;

              await moveFile(song, folder);
              await _refreshData();
              },
                child: const Text("Mover a"),
              ),

                  PopupMenuItem(
                    onTap: () async {
                      await Future.delayed(const Duration(milliseconds: 0));

                      final ok = await deleteSongDialog();
                      if (ok != true) return;

                      await deleteFile(song.videoId!, selectedFolder!);
                      CloudNotifier.instance.notify();
                      await _refreshData();
                    },
                    child: const Text("Eliminar canción"),
                  )

                  ,
                ],

                ),

                onTap: () {
                  StreamNotifier.instance.notify();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerPage(
                        playlist: list,
                        initialIndex: index,
                      ),
                    ),
                  );
                }
                ,

              );

            }, onReorder: (oldIndex, newIndex) async {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = list.removeAt(oldIndex);
              list.insert(newIndex, item);
            });

            if (selectedFolder != null) {
              final copy = List<LocalSong>.from(list);
              await saveOrder(selectedFolder!, copy);
            }
          },


          );
        },
      ),
    );

  }
  Future<String?> openCreateDirDialog() => showDialog(context: context, builder: (context)=> AlertDialog(
    title: Text("Crear una playlist"),
    content: TextField(
      autofocus: true,
      decoration: InputDecoration(hintText:"Nombre de la playlist"),
      controller: createDirController
    ),
    actions: [

      TextButton(
        onPressed: close,
        child: Text("Cancelar"),
      ),TextButton(
        onPressed:closeAndCreate         ,
        child: Text("Aceptar"),
      ),
    ],
    )

  );
  Future<String?> openRenameDirDialog() => showDialog(context: context, builder: (context)=> AlertDialog(
    title: Text("Renombra la playlist"),
    content: TextField(
        autofocus: true,
        decoration: InputDecoration(hintText:"Nombre de la playlist"),
        controller: createDirController
    ),
    actions: [

      TextButton(
        onPressed: close,
        child: Text("Cancelar"),
      ),TextButton(
        onPressed:closeAndCreate         ,
        child: Text("Aceptar"),
      ),
    ],
  )

  );

  Future<Directory?> moveDialog() {
    return showDialog<Directory>(
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Mover a",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: FutureBuilder<List<Directory>>(
                      future: getDirectoriesOnFolder(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final folders = snapshot.data!;
                        final filteredFolders = folders.where((f) {
                          if (selectedFolder == null) return true;

                          return f.path != selectedFolder!.path;
                        }).toList();
                        if (folders.isEmpty) {
                          return const Center(child: Text("No hay playlist"));
                        }
                        if (filteredFolders.isEmpty) {
                          return const Center(child: Text("Esta es tu unica playlist, crea otra para mover la cancion"));
                        }
                        return ListView.builder(
                          itemCount: filteredFolders.length,
                          itemBuilder: (context, index) {
                            final folder = filteredFolders[index];
                            final folderName = folder.path.split('/').last;

                            return ListTile(
                              leading: const Icon(Icons.folder),
                              title: Text(folderName),
                              onTap: () => Navigator.pop(context, folder),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancelar"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Future<bool?> deleteSongDialog() => showDialog(context: context, builder: (context)=> AlertDialog(
    content:Text(
      "Seguro que quieres eliminar esta cancion?"
    ),
    actions: [

      TextButton(
        onPressed: closeAndDeny,
        child: Text("Cancelar"),
      ),TextButton(
        onPressed: closeAndAccept ,
        child: Text("Aceptar"),
      ),
    ],

  )
  );
  Future<bool?> deleteDirDialog() => showDialog(context: context, builder: (context)=> AlertDialog(
    content:Text(
        "Seguro que quieres eliminar esta playlist?"
    ),
    actions: [

      TextButton(
        onPressed: closeAndDeny,
        child: Text("Cancelar"),
      ),TextButton(
        onPressed: closeAndAccept ,
        child: Text("Aceptar"),
      ),
    ],

  )
  );

  void closeAndCreate(){
    final text = createDirController.text.trim();

    Navigator.of(context).pop(text);

    createDirController.clear();
  }
  void closeAndAccept(){
    Navigator.of(context).pop(true);
  }
  void closeAndDeny(){
    Navigator.of(context).pop(false);
  }

  void close(){
    Navigator.of(context).pop();
  }
}
