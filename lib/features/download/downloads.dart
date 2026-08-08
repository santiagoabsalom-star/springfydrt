import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:springfydrt/core/text.dart';
import 'package:springfydrt/custom/audio_service.dart';
import 'package:springfydrt/features/yourdata/api/usageApi.dart';
import 'package:springfydrt/main.dart';

import '../../core/database/connection.dart';
import '../../core/directories.dart';
import '../../core/log.dart';
import '../home/dtos/LocalSong.dart';
import '../notifier/notifier.dart';
import '../playerpage/playerpage.dart';
import '../yourdata/api/usage.dart';

class DownloadedSongsPage extends StatefulWidget {
  const DownloadedSongsPage({super.key});

  @override
  State<DownloadedSongsPage> createState() => _DownloadedSongsPageState();
}

class _DownloadedSongsPageState extends State<DownloadedSongsPage> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Directory? selectedFolder;
  List<Directory> folders = [];
  List<File> songsInFolder = [];
  bool loading = true;
  late Future<List<LocalSong>> songs;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  late bool _isConnected = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late TextEditingController createDirController = TextEditingController();
  int contadorPrimerPlano = 0;
  int contadorSegundoPlano = 0;
  bool primerPlano = true;
  final _primerPlanoSubject = BehaviorSubject<bool>.seeded(true);
  Stream<bool> get primerPlanoStream => _primerPlanoSubject.stream;
  final database = MyDatabase.instance;
  final _connectivitySubject = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get connectivityStream => _connectivitySubject.stream;
  @override
  void initState() {
    super.initState();
    _loadSongs();
    EmpezarContadorPrimerPlano();
    empezarContadoresLocales();
    syncLocalData();
    checkConectivity();
    _loadDirectories();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
    DownloadsNotifier.instance.addListener(_loadSongs);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    createDirController = TextEditingController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return PopScope(canPop: false,onPopInvokedWithResult: (bool didPop, Object? result) async {
      if (didPop) {
        return;
      }
      bool shouldPop=selectedFolder == null ? false : true;


      if (shouldPop) {

        setState(() {
          selectedFolder=null;
        });
      }
    },child:
      Scaffold(
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

          ? selectedFolder != null ? null :
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final nombredir = await openCreateDirDialog();

              if (nombredir == null || nombredir.isEmpty) {
                return;
              }
              await createDirectory(nombredir);
              await _refreshData();
            },

          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
        bottom: selectedFolder == null ? null :

        PreferredSize(
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
                fillColor: Theme
                    .of(context)
                    .cardColor,
                suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    ]),
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
              final folderName = folder.path
                  .split('/')
                  .last;

              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(folderName),
                trailing:
                PopupMenuButton(itemBuilder: (context) =>
                [
                  PopupMenuItem(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          final newnombredir = await openRenameDirDialog();
                          if (newnombredir == null || newnombredir.isEmpty) {
                            return;
                          }
                          await renameDirectory(newnombredir, folder);

                          await _refreshData();
                        }, child: Text("Renombrar playlist"),
                      )
                  ),
                  PopupMenuItem(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.pop(context);

                          if (await deleteDirDialog() == true) {
                            await deleteFolder(folder);
                            CloudNotifier.instance.notify();
                            await _refreshData();
                          }

                          else {
                            return;
                          }
                        }, child: Text("Eliminar playlist"),
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

      ) : FutureBuilder<List<LocalSong>>(
        future: loadSongsFromFolderOrdered(selectedFolder!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('No hay canciones descargadas en esta playlist'));
          }

          final list = snapshot.data!.where((song) {
            return song.title.toLowerCase().contains(
                _searchQuery.toLowerCase());
          }).toList();

          if (list.isEmpty) {
            return const Center(child: Text('No se encontraron canciones'));
          }


          return ReorderableListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final song = list[index];
              Log.d("${song.videoId}");
              return ListTile(
                key: ValueKey(song.path),
                leading: const Icon(Icons.music_note),
                title: Text(Formatter.format(song.title)),
                trailing: PopupMenuButton(itemBuilder: (context) =>
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
                      Log.d("${song.videoId}");
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
                  audioHandler.isOpenFromCloud=false;
                  audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
                  audioHandler.randomSong=false;
                  StreamFromPlayerNotifier.instance.notify();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PlayerPage(

                            playlist: list,
                            isOpenFromCloud: false,
                            initialIndex: index,
                          ),
                    ),
                  );
                },

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
    ));
  }



    void _updateConnectionStatus(List<ConnectivityResult> result) {
      Log.d("---------------------");
    Log.d("$result");
      Log.d("---------------------");
        bool isConnect= true;
        if(result.contains(ConnectivityResult.other) || result.contains(ConnectivityResult.none)) isConnect=false;
      _connectivitySubject.add(isConnect);

    setState(() {

      _isConnected = !result.contains(ConnectivityResult.none);


      if(_isConnected){
        Future.microtask(() {
          Future.delayed(const Duration(seconds: 1), () async {
            try {
              if (mounted) {
                await UsageLocalStorage.syncPendingUsage();
              }
            } catch (e) {
              Log.d("Error de canal evitado: $e");
            }
          });
        });
      }
    });
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {

      TerminarContadorPrimerPlano();
      TerminarContadorSegundoPlano();
      return AppExitResponse.exit;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {


    if(state==AppLifecycleState.resumed){
      Log.d("Emitiendo primer plano...");
      _primerPlanoSubject.add(true);


    }

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      Log.d("Emitiendo segundo plano...");

      _primerPlanoSubject.add(false);
      }



      //Si tengo internet le mando senial al servidor para que empiece contador. sino guardamos en un archivo

  }
 void empezarContadoresLocales(){
    Log.d("Escuchando cambios...");
    Rx.combineLatest3(audioHandler.player.playerStateStream,primerPlanoStream,connectivityStream, (state, isPrimerPlano, isConnected)=> [state,isPrimerPlano,isConnected]).listen((event) {

      final state = event[0] as PlayerState;
      final isPrimerPlano =   event[1] as bool;
      final isConnected = event[2] as bool;
      if(isConnected){

        if(!isPrimerPlano){
          TerminarContadorPrimerPlano();
          if(state.playing && state.processingState == ProcessingState.ready){
              Log.d("Empieza contador segundo plano online");
              EmpezarContadorSegundoPlano();
          }
        }
        else{
          Log.d("Empieza contador primer plano online");
          TerminarContadorSegundoPlano();
          EmpezarContadorPrimerPlano();
        }

      } else
      { if (!isPrimerPlano) {
        TerminarContadorPrimerPlanoLocal();
        if(state.playing && state.processingState == ProcessingState.ready){
          Log.d("Empieza contador segundo plano local");



          contadorSegundoPlano = DateTime
              .now()
              .millisecondsSinceEpoch;}

      }
      else if(isPrimerPlano){
        Log.d("Empieza contador primer plano local");

        TerminarContadorSegundoPlanoLocal();
        EmpezarContadorPrimerPlanoLocal();
      }}

    });

 }

 void EmpezarContadorPrimerPlanoLocal(){
    contadorPrimerPlano=DateTime.now().millisecondsSinceEpoch;
 }

  void TerminarContadorPrimerPlanoLocal() {

    if (contadorPrimerPlano == 0) {
      Log.d("return ");
      return;}

    final ahora = DateTime.now().millisecondsSinceEpoch;
    final segundosTranscurridos = ((ahora - contadorPrimerPlano) / 1000).round();

    contadorPrimerPlano = 0;

    Log.d("segundos: $segundosTranscurridos");
    UsageLocalStorage.saveUsageLocal(segundosTranscurridos, true);
  }
  void TerminarContadorSegundoPlanoLocal() {
    Log.d("Terminando Contador SegundoPlano");
    if (contadorSegundoPlano == 0) return;

    final ahora = DateTime.now().millisecondsSinceEpoch;
    final segundosTranscurridos = ((ahora - contadorSegundoPlano) / 1000).round();

    contadorSegundoPlano = 0;

    Log.d("segundos: $segundosTranscurridos");
    contadorSegundoPlano = 0;
    UsageLocalStorage.saveUsageLocal(segundosTranscurridos, false);
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DownloadsNotifier.instance.removeListener(_loadSongs);
    _connectivitySubscription.cancel();
    _searchController.dispose();
    createDirController.dispose();
    super.dispose();
  }
void _loadDirectories() {
    setState(() {
      getDirectoriesOnFolder().then((value) => folders = value);
    });
  }
Future<void> syncLocalData() async {
    List<Directory> folders= await getDirectoriesOnFolder();
    List<LocalSong> songs=[];
    Log.d("${folders.length}");
    if(folders.isNotEmpty){
      Log.d("${folders.length}");
      for( var dir in folders){
        List<LocalSong> localsongs= await getSongsFromFolder(dir);
        songs.addAll(localsongs);

      if(songs.isNotEmpty){
      database.syncAndClean(folders, songs);
      }
          else{
              return;
      }}
    }return;

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

  Future<void> checkConectivity() async {
    List<ConnectivityResult> result =await Connectivity().checkConnectivity();
    _isConnected = !result.contains(ConnectivityResult.none);

    _updateConnectionStatus(result);
  }
}