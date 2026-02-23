import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../../core/directories.dart';
import '../../main.dart';
import '../../core/network/api_connect.dart';
import '../notifier/notifier.dart';
import 'api/download_api.dart';
import 'api/search_api.dart';
import 'dtos/song_dto.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SearchApi _searchApi = SearchApi();
  Timer? _debounce;
  final DownloadApi _downloadApi = DownloadApi();
  final TextEditingController _searchController = TextEditingController();

  List<VideoInfo> _results = [];
  final Set<String> _cloudDownloaded = {};
  final Set<String> _localDownloaded = {};
  String _query = '';

  void _onSearchChanged(String value) {
    _query = value;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      if (_query.trim().isEmpty) {
        setState(() => _results = []);
        return;
      }
      final response = await _searchApi.searchByName(_query);
      if (!mounted) return;
      setState(() {
        _results = response.videosInfo;
      });
    });
  }


  void _playSong(int index) {
    final mediaItems = _results.map((v) => MediaItem(
      id: '${ApiConnect.baseUrl}/api/download/downloadOnApp?videoId=${v.videoId}',
      album: "Springfy",
      title: v.title,
      artist: v.channelTitle,
      extras: {'videoId': v.videoId},
    )).toList();

    audioHandler.loadPlaylist(mediaItems, startIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '¿Qué quieres escuchar?',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final video = _results[index];
                  return _SearchResultTile(
                    video: video,
                    cloudDownloaded: _cloudDownloaded.contains(video.videoId),
                    localDownloaded: _localDownloaded.contains(video.videoId),
                    onTap: () => _playSong(index),
                    onCloudDownload: () async {
                      await _downloadApi.downloadOnCloud(video.videoId);
                      CloudNotifier.instance.notify();
                      setState(() => _cloudDownloaded.add(video.videoId));
                    },
                    onLocalDownload: () async {
                    openDownloadDialog().then(
                          (directory) async => await _downloadApi.saveAudioFromVideo(video, video.videoId, directory!)

                    );
                      DownloadsNotifier.instance.notify();
                      setState(() => _localDownloaded.add(video.videoId));
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
                          return const Center(child: CircularProgressIndicator());
                        }

                        final folders = snapshot.data!;
                        if (folders.isEmpty) {
                          return const Center(child: Text("No hay playlist, crea una para guardar la cancion"));
                        }

                        return ListView.builder(
                          itemCount: folders.length,
                          itemBuilder: (context, index) {
                            final folder = folders[index];
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
}

class _SearchResultTile extends StatelessWidget {
  final VideoInfo video;
  final bool cloudDownloaded;
  final bool localDownloaded;
  final VoidCallback onTap;
  final VoidCallback onCloudDownload;
  final VoidCallback onLocalDownload;

  const _SearchResultTile({
    required this.video,
    required this.cloudDownloaded,
    required this.localDownloaded,
    required this.onTap,
    required this.onCloudDownload,
    required this.onLocalDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(

        leading: const CircleAvatar(child: Icon(Icons.music_note_outlined)),
        title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(video.channelTitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.cloud_download, color: cloudDownloaded ? Colors.green : null),
              onPressed: cloudDownloaded ? null : onCloudDownload,
            ),
            IconButton(
              icon: Icon(Icons.download, color: localDownloaded ? Colors.green : null),
              onPressed: cloudDownloaded && !localDownloaded ? onLocalDownload : null,
            )

          ],
        ),
      ),
    );
  }

}
