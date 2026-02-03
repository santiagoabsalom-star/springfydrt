import 'package:flutter/material.dart';

import '../../core/directories.dart';
import '../home/dtos/LocalSong.dart';
import '../notifier/notifier.dart';
import '../playerpage/playerglobal.dart';
import '../playerpage/playerpage.dart';

class DownloadedSongsPage extends StatefulWidget {
  const DownloadedSongsPage({super.key});

  @override
  State<DownloadedSongsPage> createState() => _DownloadedSongsPageState();
}

class _DownloadedSongsPageState extends State<DownloadedSongsPage> {
  late Future<List<LocalSong>> songs;
  final player = GlobalAudioPlayer.instance;

  @override
  void initState() {
    super.initState();
    _loadSongs();
    DownloadsNotifier.instance.addListener(_loadSongs);


  }
  @override
  void dispose() {
    DownloadsNotifier.instance.removeListener(_loadSongs);
    super.dispose();
  }

  void _loadSongs() {
    setState(() {
      songs = getLocalSongs();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Descargados')),
      body: FutureBuilder<List<LocalSong>>(
        future: songs,
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay canciones descargadas'));
          }

          final list = snapshot.data!;

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final song = list[index];

              return ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(song.title),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerPage(
                        playlist: list,
                        initialIndex: index,
                      ),
                    ),
                  );
                },


              );
            },
          );
        },
      ),
    );
  }
}
