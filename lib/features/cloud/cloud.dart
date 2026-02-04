import 'package:flutter/material.dart';
import 'package:springfydrt/features/cloud/api/api_cloud.dart';
import 'package:springfydrt/features/cloud/dto/audioDto.dart';
import 'package:springfydrt/features/home/api/download_api.dart';
import 'package:springfydrt/features/home/dtos/song_dto.dart';
import 'package:springfydrt/features/home/dtos/LocalSong.dart';
import 'package:springfydrt/core/directories.dart';

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
    setState(() {
      _cloudSongs = _apiCloud.allOnCloud();
    });
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
    // AHORA COMPARAMOS POR VIDEO ID
    return _localSongs.any((local) => local.videoId == audio.videoId);
  }

  void _downloadSong(AudioDTO audio) async {
    if (_isDownloaded(audio) || _downloadingIds.contains(audio.videoId)) return;

    setState(() {
      _downloadingIds.add(audio.videoId);
    });

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Descargando ${audio.nombreAudio}...')),
        );
      }

      final videoInfo = VideoInfo(
        videoId: audio.videoId,
        title: audio.nombreAudio,
        channelTitle: 'Cloud',
      );

      await _downloadApi.saveAudioFromVideo(videoInfo, audio.videoId);

      DownloadsNotifier.instance.notify();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${audio.nombreAudio} descargado con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(audio.videoId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cloud Songs"),
        actions: [
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
            return song.nombreAudio.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          if (songs.isEmpty && _searchQuery.isNotEmpty) {
            return const Center(child: Text("No se encontraron coincidencias"));
          }

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final downloaded = _isDownloaded(song);
              final isDownloading = _downloadingIds.contains(song.videoId);

              return ListTile(
                leading: const Icon(Icons.cloud_queue),
                title: Text(song.nombreAudio),
                subtitle: Text(song.videoId),
                trailing: isDownloading 
                  ? const SizedBox(
                      width: 24, 
                      height: 24, 
                      child: CircularProgressIndicator(strokeWidth: 2)
                    )
                  : IconButton(
                      icon: Icon(
                        downloaded ? Icons.check_circle : Icons.download,
                        color: downloaded ? Colors.green : null,
                      ),
                      onPressed: downloaded ? null : () => _downloadSong(song),
                    ),
              );
            },
          );
        },
      ),
    );
  }
}
