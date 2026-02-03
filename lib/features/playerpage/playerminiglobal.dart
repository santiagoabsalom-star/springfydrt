import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../home/dtos/LocalSong.dart';
import 'playerglobal.dart';
import 'playerpage.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = GlobalAudioPlayer.instance;
    StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final song = snapshot.data;
        if (song == null) return const SizedBox.shrink();
        return Row(
          children: [
            Text(song.title),
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => audioHandler.play(),
            ),
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: () => audioHandler.pause(),
            ),
          ],
        );
      },
    );

    return StreamBuilder<LocalSong?>(
      stream: player.currentSongStream,
      initialData: player.currentSong,
      builder: (context, songSnap) {
        final song = songSnap.data;
        if (song == null) return const SizedBox();

        return StreamBuilder<DurationState>(
          stream: player.durationState,
          initialData: player.currentDurationState,
          builder: (context, durSnap) {
            final state = durSnap.data;
            final position = state?.position ?? Duration.zero;
            final total = state?.total ?? Duration.zero;

            return StreamBuilder<bool>(
              stream: player.isPlayingStream,
              initialData: player.isPlaying,
              builder: (context, playSnap) {
                final playing = playSnap.data ?? false;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerPage(
                          playlist: player.currentPlaylist,
                          initialIndex: player.currentIndex,
                          isOpeningFromMiniPlayer: true,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 70,
                    color: Theme.of(context).cardColor,
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: total.inMilliseconds == 0
                              ? 0
                              : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0),
                          minHeight: 2,
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(Icons.music_note),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_previous),
                                onPressed: player.previous,
                              ),
                              IconButton(
                                icon: Icon(
                                  playing ? Icons.pause : Icons.play_arrow,
                                ),
                                onPressed: player.toggle,
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_next),
                                onPressed: player.next,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
