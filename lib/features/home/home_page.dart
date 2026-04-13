import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:springfydrt/custom/audio_service.dart';
import '../../core/directories.dart';
import '../../core/log.dart';
import '../../main.dart';
import '../../core/network/api_connect.dart';
import '../cloud/api/api_cloud.dart';
import '../notifier/notifier.dart';
import 'api/download_api.dart';
import 'api/search_api.dart';
import 'dtos/LocalSong.dart';
import 'dtos/song_dto.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin{
  @override
  bool get wantKeepAlive => true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  late bool _isConnected= true;
  final SearchApi _searchApi = SearchApi();
  final ApiCloud _apiCloud = ApiCloud();
  Timer? _debounce;
  final DownloadApi _downloadApi = DownloadApi();
  final TextEditingController _searchController = TextEditingController();

  List<VideoInfo> _results = [];
  final Set<String> _cloudDownloaded = {};

  String _query = '';
@override
void initState() {
  DownloadsNotifier.instance.addListener(setAppAndCloudDownloaded);
    setAppAndCloudDownloaded();
  _connectivitySubscription =
      Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
    super.initState();

  }
  @override
  void dispose() {
    super.dispose();
    _searchController.dispose();
    _connectivitySubscription.cancel();

    DownloadsNotifier.instance.removeListener(setAppAndCloudDownloaded);
  }

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



  Future<void> setAppAndCloudDownloaded() async {
    final cloudSongs = await _apiCloud.allOnCloud();
    for(final cloud in  cloudSongs){
      _cloudDownloaded.add(cloud.audioId);
    }



  }
  Future<void> openPlayerFromCloud(BuildContext context, VideoInfo song) async {
    try{



      showTopNotification(context, "Iniciando cancion");
      final bytes = await _downloadApi.sampleOnApp(song.videoId);
      final tempDir = await getTemporaryDirectory();

      final file = File('${tempDir.path}/${song.videoId}.mp3');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      LocalSong localsong = LocalSong(
          title: song.title,
          path: file.path,
          videoId: song.videoId
      );
      StreamFromPlayerNotifier.instance.notify();
      audioHandler.loadPlaylist([localsong.toMediaItem()], false, startIndex: 0 );
    } catch (e) {
      Log.d("Error: $e");
    }
  }
  void _updateConnectionStatus(List<ConnectivityResult> result) {
    setState(() {
      _isConnected = !result.contains(ConnectivityResult.none);

    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                  suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                  IconButton(
                  icon: const Icon(Icons.clear, size: 20),
          onPressed: () {
            _searchController.clear();
            _onSearchChanged('');
          },
        )]),
              )
              ,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final video = _results[index];
                  return _SearchResultTile(

                    video: video,
                    cloudDownloaded: _cloudDownloaded.contains(video.videoId),
                    onTap: () => {
                      if(_isConnected){
                      openPlayerFromCloud(context, video)}else{
                        showTopNotification(context, "Tienes que tener internet para navegar")


                      }},
                    onCloudDownload: () async {
                      await _downloadApi.downloadOnCloud(video.videoId);
                      CloudNotifier.instance.notify();
                      setState(() => _cloudDownloaded.add(video.videoId));
                    },
                    onLocalDownload: () async {
                    final directory = await openDownloadDialog(video.videoId);
                    if(directory!=null) {

                      await saveAudio(video, video.videoId, directory);
                      DownloadsNotifier.instance.notify();
                      StreamFolderNotifier.instance.notify();
                      showTopNotification(context, "Cancion guardada en la playlist correctamente");
                    }
                    else{

                      showTopNotification(context, "Debes seleccionar una playlist");

                    }

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
  Future<void> saveAudio(VideoInfo info,String videoId,Directory directory)async{
    RootIsolateToken? rootToken = RootIsolateToken.instance;
    await compute(executeDownloadInBackground, DownloadParams(
      info,
      videoId,
      directory.path,
      rootToken!,
    ));
    DownloadsNotifier.instance.notify();
    StreamFolderNotifier.instance.notify();

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
  
  final VoidCallback onTap;
  final VoidCallback onCloudDownload;
  final VoidCallback onLocalDownload;

  const _SearchResultTile({
    required this.video,
    required this.cloudDownloaded,

    required this.onTap,
    required this.onCloudDownload,
    required this.onLocalDownload,
  });

  @override
  Widget build(BuildContext context)  {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child:

      ListTile(
        leading: const CircleAvatar(child: Icon(Icons.music_note_outlined)),
        title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: onTap,
        subtitle: Text(video.channelTitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.cloud_download,
                  color: cloudDownloaded ? Colors.green : null),
              onPressed: cloudDownloaded ? null : onCloudDownload,
            ),
            ListenableBuilder(
                listenable:DownloadsNotifier.instance,
                builder: (context,_){
                  return
            FutureBuilder<bool>(
              future: isSongOnAllDirectories(video.videoId),
              builder: (context, snapshot) {
                final bool isDownloadedOnAll = snapshot.data ?? false;
                return
                FutureBuilder<bool>(
                  future: isSongOnAnyDirectoryButNotInAll(video.videoId),
                  builder: (context, snapshot) {
                    final bool isSongOnAnyDirectoryButNotInAll= snapshot.data ?? false;

                    return IconButton(
                      icon: Icon(
                        isDownloadedOnAll ? Icons.check_circle : Icons.download,
                        color: (isSongOnAnyDirectoryButNotInAll || isDownloadedOnAll)?Colors.green : null,
                      ),
                      onPressed: isDownloadedOnAll? null :onLocalDownload,
                    );
                  });
              },
            );})
          ],
        ),
      ),
    );
  }

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
