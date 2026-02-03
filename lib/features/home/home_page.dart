import 'dart:async';

import 'package:flutter/material.dart';

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

  //Podemos hacer un algoritmo de recomendaciones
  List<VideoInfo> _results = [];
  final Set<String> _cloudDownloaded = {};
  final Set<String> _localDownloaded = {};

  void _onSearchChanged(String value) {
    _query = value;


    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
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



  String _query = '';

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
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              _query.isEmpty ? 'Explorar' : 'Resultados',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final video = _results[index];

                  return _SearchResultTile(
                    video: video,
                    cloudDownloaded: _cloudDownloaded.contains(video.videoId),
                    localDownloaded: _localDownloaded.contains(video.videoId),

                    onCloudDownload: () async {
                      await _downloadApi.downloadOnCloud(video.videoId);
                      setState(() {
                        _cloudDownloaded.add(video.videoId);
                      });
                    },

                    onLocalDownload: () async {
                      await _downloadApi.saveAudioFromVideo(video,video.videoId);
                      DownloadsNotifier.instance.notify();
                      setState(() {
                        _localDownloaded.add(video.videoId);
                      });
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
}
class _SearchResultTile extends StatelessWidget {
  final VideoInfo video;
  final bool cloudDownloaded;
  final bool localDownloaded;
  final VoidCallback onCloudDownload;
  final VoidCallback onLocalDownload;

  const _SearchResultTile({
    required this.video,
    required this.cloudDownloaded,
    required this.localDownloaded,
    required this.onCloudDownload,
    required this.onLocalDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(Icons.music_note),
        title: Text(video.title),
        subtitle: Text(video.channelTitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.cloud_download,
                color: cloudDownloaded ? Colors.green : null,
              ),
              onPressed: cloudDownloaded ? null : onCloudDownload,
            ),
            IconButton(
              icon: Icon(
                Icons.download,
                color: localDownloaded ? Colors.green : null,
              ),
              onPressed:
              cloudDownloaded && !localDownloaded
                  ? onLocalDownload
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}


