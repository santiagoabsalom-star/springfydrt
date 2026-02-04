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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSongs();
    DownloadsNotifier.instance.addListener(_loadSongs);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    DownloadsNotifier.instance.removeListener(_loadSongs);
    _searchController.dispose();
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
      appBar: AppBar(
        title: const Text('Descargados'),
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
      body: FutureBuilder<List<LocalSong>>(
        future: songs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay canciones descargadas'));
          }

          final list = snapshot.data!.where((song) {
            return song.title.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          if (list.isEmpty) {
            return const Center(child: Text('No se encontraron canciones'));
          }

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
