import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:springfydrt/features/cloud/api/api_cloud.dart';
import 'package:springfydrt/features/cloud/dto/audioDto.dart';
import 'package:springfydrt/features/home/api/download_api.dart';
import 'package:springfydrt/features/home/dtos/song_dto.dart';
import 'package:springfydrt/features/home/dtos/LocalSong.dart';
import 'package:springfydrt/core/directories.dart';

import '../../core/log.dart';
import '../notifier/notifier.dart';

class CloudPage extends StatefulWidget {
  const CloudPage({super.key});

  @override
  State<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends State<CloudPage> {
  final ApiCloud _apiCloud = ApiCloud();
  final DownloadApi _downloadApi = DownloadApi();
  late Future<List<AudioDTO>> _cloudSongs;
  List<LocalSong> _localSongs = [];
  final Set<String> _downloadingIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshData();
    DownloadsNotifier.instance.addListener(_refreshLocalSongs);
    CloudNotifier.instance.addListener(_refreshData);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    DownloadsNotifier.instance.removeListener(_refreshLocalSongs);
    CloudNotifier.instance.removeListener(_refreshData);
    _searchController.dispose();
    super.dispose();
  }

  void _refreshData() {
    _cloudSongs = _apiCloud.allOnCloud();
    _refreshLocalSongs();
  }

  Future<void> _refreshLocalSongs() async {
    final songs = await getLocalSongs();
    if (mounted) {
      setState(() {
        _localSongs = songs;
      });
    }
  }

  bool _isDownloaded(AudioDTO audio) {
    if(_localSongs.isEmpty) return false;
    return _localSongs.any((song) => song.videoId == audio.audioId);



  }

  void _downloadSong(AudioDTO audio, Directory directory) async {
    if (directory != null) {
      if (_isDownloaded(audio) || _downloadingIds.contains(audio.audioId))
        return;
      Log.d(audio.audioId);
      setState(() {
        _downloadingIds.add(audio.audioId);
      });

      try {
        if (mounted) {
         showTopNotification(context, "Descargando ${audio.nombreAudio}");
        }

        final videoInfo = VideoInfo(
          videoId: audio.audioId,
          title: audio.nombreAudio,
          channelTitle: 'Cloud',
        );

        await _downloadApi.saveAudioFromVideo(
          videoInfo,
          audio.audioId,
          directory,
        );

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
  }

  @override
  Widget build(BuildContext context) {
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
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No hay canciones en la nube"));
          }

          final songs = snapshot.data!.where((song) {
            return song.nombreAudio.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
          }).toList();

          if (songs.isEmpty && _searchQuery.isNotEmpty) {
            return const Center(child: Text("No se encontraron coincidencias"));
          }
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final downloaded = _isDownloaded(song);
              final isDownloading = _downloadingIds.contains(song.audioId);

              return ListTile(
                leading: const Icon(Icons.cloud_queue),
                title: Text(song.nombreAudio),
                subtitle: Text(song.audioId),
                trailing: isDownloading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(
                          downloaded ? Icons.check_circle : Icons.download,
                          color: downloaded ? Colors.green : null,
                        ),
                        onPressed: downloaded
                            ? null
                            : () {

                          openDownloadDialog().then(

                                (directory) => {

                                  _downloadSong(song, directory!)},
                              );},
                      ),
              );
            },
          );
        },
      ),
    );
  }

  Future<Directory?> openDownloadDialog() {
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
                      future: getDirectoriesOnFolder(),
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

}
