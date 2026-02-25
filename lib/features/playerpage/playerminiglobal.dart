import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:springfydrt/features/playerpage/playerpage.dart';
import '../../main.dart';
import '../home/dtos/LocalSong.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaItemSnapshot) {
        final mediaItem = mediaItemSnapshot.data;


        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, playbackStateSnapshot) {
            final playbackState = playbackStateSnapshot.data;
            final isPlaying = playbackState?.playing ?? false;
            final int? currentIndex = playbackState?.queueIndex;
            final List<LocalSong> currentPlaylist = getCurrentPlayList();
            final processingState = playbackState?.processingState ?? AudioProcessingState.idle;

            final position = playbackState?.position;
            final duration = mediaItem?.duration ?? Duration.zero;
            if (mediaItem == null ||
                processingState == AudioProcessingState.idle) {
              return const SizedBox.shrink();
            }


            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PlayerPage(
                          playlist: currentPlaylist,
                          initialIndex: currentIndex,
                          isOpeningFromMiniPlayer: true,
                        ),
                  ),
                );
              },
              child: Container(
                height: 65,
                color: Theme
                    .of(context)
                    .colorScheme
                    .surface
                    .withOpacity(0.98),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    LinearProgressIndicator(
                      value: (duration.inMilliseconds == 0 ||
                          position!.inMilliseconds > duration.inMilliseconds)
                          ? 0.0
                          : position.inMilliseconds / duration.inMilliseconds,
                      minHeight: 2.5,
                      backgroundColor: Colors.grey.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme
                              .of(context)
                              .colorScheme
                              .primary),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          const Icon(Icons.music_note, size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  mediaItem.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                if (mediaItem.artist != null)
                                  Text(
                                    mediaItem.artist!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme
                                            .of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            onPressed: audioHandler.skipToPrevious,
                          ),
                          IconButton(
                            iconSize: 36.0,
                            icon: Icon(
                              isPlaying ? Icons.pause_circle_filled : Icons
                                  .play_circle_filled,
                            ),
                            onPressed:
                            isPlaying ? audioHandler.pause : audioHandler.play,
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            onPressed: audioHandler.skipToNext,
                          ),
                          const SizedBox(width: 8),
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
  }

  List<LocalSong> getCurrentPlayList() {
    return audioHandler.queue.value
        .map((mediaItem) =>
        LocalSong(
          title: mediaItem.title,
          path: mediaItem.id,

          videoId: mediaItem.displayTitle ?? '',
        ))
        .toList();
  }
}
