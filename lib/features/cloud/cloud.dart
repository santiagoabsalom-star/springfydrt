import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:springfydrt/core/database/connection.dart';
import 'package:springfydrt/core/text.dart';
import 'package:springfydrt/features/cloud/api/api_cloud.dart';
import 'package:springfydrt/features/cloud/dto/audioDto.dart';
import 'package:springfydrt/features/home/api/download_api.dart';
import 'package:springfydrt/features/home/dtos/song_dto.dart';
import 'package:springfydrt/core/directories.dart';
import 'package:springfydrt/main.dart';

import '../../core/log.dart';
import '../home/dtos/LocalSong.dart';
import '../notifier/notifier.dart';

class CloudPage extends StatefulWidget {
  const CloudPage({super.key});

  @override
  State<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends State<CloudPage>with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  int countOfDirectories = 0;
  final database = MyDatabase.instance;
  final ApiCloud _apiCloud = ApiCloud();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  late bool _isConnected = true;
  final DownloadApi _downloadApi = DownloadApi();
  late Future<List<AudioDTO>> _cloudSongs;
  final Set<String> _downloadingIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';


  @override
  void initState() {
    super.initState();
    _refreshData();

    CloudNotifier.instance.addListener(_refreshData);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    CloudNotifier.instance.removeListener(_refreshData);
    _searchController.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {

    setState(() {
      _cloudSongs = _apiCloud.allOnCloud();
    });


  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    setState(() {
      _isConnected = !result.contains(ConnectivityResult.none);

    });
  }


  void _downloadSong(AudioDTO audio, Directory directory) async {

    if (await isSongOnDirectory(audio.audioId, directory) || _downloadingIds.contains(audio.audioId)) return;
    Log.d(audio.audioId);
    setState(() {
      _downloadingIds.add(audio.audioId);
    });

    try {
      RootIsolateToken? rootToken= RootIsolateToken.instance;
      if (mounted) {
       showTopNotification(context, "Descargando ${audio.nombreAudio}");
      }

      final videoInfo = VideoInfo(
        videoId: audio.audioId,
        title: audio.nombreAudio,
        channelTitle: 'Cloud',
      );
        await compute(executeDownloadInBackground, DownloadParams(
        videoInfo,
        audio.audioId,
        directory.path,
          rootToken!,
        ));


      DownloadsNotifier.instance.notify();
      StreamFolderNotifier.instance.notify();
      if (mounted) {
        showTopNotification(context, "Cancion descargada");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al descargar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(audio.audioId);
        });
      }
    }
    }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
    title: const Text("Cloud Songs"),
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar en la nube...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();

                      },
                    )]),
            ),
          ),
        ),
      ),
    ),
      body: FutureBuilder<List<AudioDTO>>(
        future: _cloudSongs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(snapshot.hasError ? "Error" : "No hay canciones"));
          }

          final filteredSongs = snapshot.data!.where((song) =>
              song.nombreAudio.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();


          return StreamBuilder<int>(
            stream: database.watchDirectoryCount(),
            builder: (context, dirSnapshot) {
              final currentDirCount = dirSnapshot.data ?? 0;
              return StreamBuilder<Map<String, int>>(
                stream: database.watchAllSongCounts(),
                builder: (context, songSnapshot) {
                  final Map<String, int> countsMap = songSnapshot.data ?? {};
                  Log.d("${countsMap.values}");
                  return ListView.builder(
                    addAutomaticKeepAlives: true,
                    itemCount: filteredSongs.length,
                    itemBuilder: (context, index) {
                    Log.d(filteredSongs[index].audioId);
                return _buildSongTile(filteredSongs[index], countsMap[filteredSongs[index].audioId] ?? 0 , currentDirCount);
                    },
                  );
                },
              );
            },
          );


        },
      )

    );
  }

  Widget _buildSongTile(AudioDTO song, int count, int dirCount) {
    final bool isDownloading = _downloadingIds.contains(song.audioId);
    final bool isSongOnAll = (count == dirCount) && (dirCount > 0);
    final bool isAnyButNotAll =( count > 0 && count < dirCount) && dirCount>0;

    return PersistentSongTile(
      key: ValueKey(song.audioId),
      child: ListTile(
        leading: const Icon(Icons.cloud_queue),
        title: Text(Formatter.format(song.nombreAudio)),
        subtitle: Text(song.audioId),
        onTap: () => _handleOnTap(song),
        trailing: isDownloading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
          icon: Icon(
            isSongOnAll ? Icons.check_circle : Icons.download,
            color: (isAnyButNotAll || isSongOnAll) ? Colors.green : null,
          ),
          onPressed: isSongOnAll ? null : () => _handleDownload(song),
        ),
      ),
    );
  }

  void _handleOnTap(AudioDTO song) {
    if (_isConnected) {
      openPlayerFromCloud(context, song);
    } else {
      showTopNotification(context, "Tienes que tener internet para navegar");
    }
  }

  Future<void> _handleDownload(AudioDTO song) async {
    final folder = await openDownloadDialog(song.audioId);
    if (folder != null) {
      _downloadSong(song, folder);
      await database.addSongToDirectory(song.audioId, folder.path);
    } else {
      showTopNotification(context, "Debes seleccionar una playlist");
    }
  }

  Future<Directory?> openDownloadDialog(String videoId) {
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
                    "Guardar en playlist",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: FutureBuilder<List<Directory>>(
                      future: getDirectoriesOnFolder().then((directories) async {
                        final results = await Future.wait(
                          directories.map((dir) async {
                            final exists = await isSongOnDirectory(videoId, dir);
                            return exists ? null : dir;
                          }),
                        );
                        return results.whereType<Directory>().toList();
                      }),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final folders = snapshot.data!;
                        if (folders.isEmpty) {
                          return const Center(
                            child: Text(
                              "No hay playlist, crea una para guardar la cancion",
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: folders.length,
                          itemBuilder: (context, index) {
                            final folder = folders[index];
                            final folderName = folder.path.split('/').last;

                            return ListTile(
                              leading: const Icon(Icons.folder),
                              title: Text(folderName),
                              onTap: ()
                              {

                                Navigator.pop(context, folder);},
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
  void showTopNotification(BuildContext context, String message) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 60,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                  )
                ],
              ),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 1), () {
      entry.remove();
    });
  }
  Future<void> openPlayerFromCloud(BuildContext context, AudioDTO song) async {
    try {
      showTopNotification(context, "Iniciando cancion");
      final bytes = await _downloadApi.downloadOnApp(song.audioId);
      final tempDir = await getTemporaryDirectory();

      final file = File('${tempDir.path}/${song.audioId}.mp3');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      LocalSong localsong = LocalSong(
          title: Formatter.format(song.nombreAudio),
          path: file.path,
          videoId: song.audioId
      );
      StreamFromPlayerNotifier.instance.notify();
      audioHandler.loadPlaylist(
          [localsong.toMediaItem()], false, startIndex: 0);
    } catch (e) {
      Log.d("Error: $e");
    }
  }}
class PersistentSongTile extends StatefulWidget {
  final Widget child;
  const PersistentSongTile({super.key, required this.child});

  @override
  State<PersistentSongTile> createState() => _PersistentSongTileState();
}

class _PersistentSongTileState extends State<PersistentSongTile>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}


