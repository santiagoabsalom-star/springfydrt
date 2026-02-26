import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:springfydrt/features/notifier/notifier.dart';
import '../../main.dart';
import '../home/dtos/LocalSong.dart';

class PlayerPage extends StatefulWidget {
  final List<LocalSong> playlist;
  final int? initialIndex;
  final bool isOpeningFromMiniPlayer;

  const PlayerPage({
    super.key,
    required this.playlist,
    this.initialIndex,
    this.isOpeningFromMiniPlayer = false,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  @override
  void initState() {
    super.initState();
    PlayerNotifier.instance.addListener(_onDuoModeStarted);

    if (!widget.isOpeningFromMiniPlayer) {
      final mediaItems = widget.playlist.map((song) => MediaItem(
        id: song.path,
        title: song.title,
        artist: "Nigga",
        extras: {'videoId': song.videoId},
      )).toList();

      if (mediaItems.isNotEmpty) {
        audioHandler.loadPlaylist(mediaItems, startIndex: widget.initialIndex ?? 0);
      }
    }
  }

  void _onDuoModeStarted() {
    audioHandler.stop();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    PlayerNotifier.instance.removeListener(_onDuoModeStarted);
    super.dispose();
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
      body: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, mediaItemSnapshot) {
          final mediaItem = mediaItemSnapshot.data;
          if (mediaItem == null) {


            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, playbackStateSnapshot) {
              final playbackState = playbackStateSnapshot.data;
              final isPlaying = playbackState?.playing ?? false;
              final position = playbackState?.position ?? Duration.zero;
              final totalDuration = mediaItem.duration ?? Duration.zero;
              final repeatMode = playbackState?.repeatMode ?? AudioServiceRepeatMode.none;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    const Icon(Icons.music_note, size: 200, color: Colors.grey),
                    const Spacer(),

                    Text(
                      mediaItem.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 40),

                    Column(
                      children: [
                        Slider(
                          min: 0,
                          max: totalDuration.inMilliseconds.toDouble(),
                          value: position.inMilliseconds
                              .clamp(0, totalDuration.inMilliseconds)
                              .toDouble(),
                          onChanged: (value) {
                            audioHandler.seek(Duration(milliseconds: value.toInt()));
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_format(position)),
                              Text(_format(totalDuration)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          iconSize: 25,
                          icon: Icon(
                            repeatMode == AudioServiceRepeatMode.one ? Icons.repeat_one : Icons.repeat,
                            color: repeatMode != AudioServiceRepeatMode.none ? Theme.of(context).colorScheme.primary : Colors.grey,
                          ),
                          onPressed: () {
                            if (repeatMode == AudioServiceRepeatMode.none) {
                              audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
                            } else if (repeatMode == AudioServiceRepeatMode.all) {
                              audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
                            } else {
                              audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
                            }
                          },
                        ),
                        IconButton(
                          iconSize: 48,
                          icon: const Icon(Icons.skip_previous),
                          onPressed: audioHandler.skipToPrevious,
                        ),
                        IconButton(
                          iconSize: 80,
                          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                          onPressed: isPlaying ? audioHandler.pause : audioHandler.play,
                        ),
                        IconButton(
                          iconSize: 48,
                          icon: const Icon(Icons.skip_next),
                          onPressed: audioHandler.skipToNext,
                        ),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }
}
