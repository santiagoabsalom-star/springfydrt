import 'package:flutter/material.dart';
import 'package:springfydrt/features/notifier/notifier.dart';
import 'package:springfydrt/features/playerpage/playerglobal.dart';
import '../home/dtos/LocalSong.dart';

class PlayerPage extends StatefulWidget {
  final List<LocalSong> playlist;
  final int initialIndex;
  final bool isOpeningFromMiniPlayer;

  const PlayerPage({
    super.key,
    required this.playlist,
    required this.initialIndex,
    this.isOpeningFromMiniPlayer = false,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final player = GlobalAudioPlayer.instance;

  @override
  void initState() {
    super.initState();
    PlayerNotifier.instance.addListener(quitar);

    if (!widget.isOpeningFromMiniPlayer) {
      player.setPlaylist(
        widget.playlist,
        startIndex: widget.initialIndex,
      );
    }
  }
  Future<void> quitar()async{
    player.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reproductor'),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<LocalSong?>(
        stream: player.currentSongStream,
        initialData: player.currentSong,
        builder: (context, songSnapshot) {
          final song = songSnapshot.data;
          if (song == null) return const Center(child: Text("No hay canción seleccionada"));

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const Icon(Icons.music_note, size: 200, color: Colors.grey),
                const Spacer(),
                
                Text(
                  song.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 40),

                StreamBuilder<DurationState>(
                  stream: player.durationState,
                  initialData: player.currentDurationState,
                  builder: (context, snapshot) {
                    final state = snapshot.data;
                    final position = state?.position ?? Duration.zero;
                    final total = state?.total ?? Duration.zero;

                    return Column(
                      children: [
                        Slider(
                          min: 0,
                          max: total.inMilliseconds.toDouble(),
                          value: position.inMilliseconds
                              .clamp(0, total.inMilliseconds)
                              .toDouble(),
                          onChanged: (value) {
                            player.seek(Duration(milliseconds: value.toInt()));
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_format(position)),
                              Text(_format(total)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                StreamBuilder<bool>(
                  stream: player.isPlayingStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data ?? false;

                    return StreamBuilder<bool>(
                      stream: player.isRepeatingStream,
                      initialData: player.isRepeating,
                      builder: (context, snapRepeat) {
                        final repeating = snapRepeat.data ?? false;


                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          iconSize: 25,
                          icon: Icon(repeating ? Icons.repeat_one : Icons.repeat),
                          onPressed: player.repeat,
                        ),
                        IconButton(
                          iconSize: 48,
                          icon: const Icon(Icons.skip_previous),
                          onPressed: player.previous,
                        ),
                        IconButton(
                          iconSize: 80,
                          icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                          onPressed: player.toggle,
                        ),
                        IconButton(
                          iconSize: 48,
                          icon: const Icon(Icons.skip_next),
                          onPressed: player.next,
                        ),
                      ],
                    );
                  });
                        },
                ),
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
