
import 'package:springfydrt/core/text.dart';
import 'package:springfydrt/custom/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:springfydrt/features/notifier/notifier.dart';
import '../../main.dart';
import '../home/dtos/LocalSong.dart';

class PlayerPage extends StatefulWidget {
  final List<LocalSong> playlist;
  final int? initialIndex;
  final bool isOpeningFromMiniPlayer;
  final bool isOpenFromCloud;

  const PlayerPage({
    super.key,
    required this.playlist,
    this.initialIndex,
    required this.isOpenFromCloud,
    this.isOpeningFromMiniPlayer = false,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>with AutomaticKeepAliveClientMixin {
  late bool isOpenFromCloud= widget.isOpenFromCloud;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    audioHandler.playFromPlayer();
    super.initState();
    PlayerNotifier.instance.addListener(_onDuoModeStarted);

    if (!widget.isOpeningFromMiniPlayer) {

      final mediaItems = widget.playlist.map((song) => song.toMediaItem()).toList();

      if (mediaItems.isNotEmpty) {
        audioHandler.loadPlaylist(mediaItems,false, startIndex: widget.initialIndex ?? 0);
      }
    }
  }
  void openFromCloud(){
    isOpenFromCloud=true;
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
    super.build(context);
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
                      Formatter.format(mediaItem.title),
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
                    isOpenFromCloud ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          iconSize: 25,
                          icon: Icon(


                                 Icons.repeat
                             ,
                            color: repeatMode != AudioServiceRepeatMode.none ?  Theme.of(context).colorScheme.primary : Colors.grey,
                          ),
                          onPressed: () async {
                          if(repeatMode==AudioServiceRepeatMode.none){
                            audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
                          }
                          else if(repeatMode==AudioServiceRepeatMode.all){
                            audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
                          }
                          },

                        ),
                        IconButton(
                          iconSize: 80,
                          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                          onPressed: isPlaying ? audioHandler.pause : audioHandler.play,
                        ),

                      ],
                    )
                    :
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [

                        IconButton(
                          iconSize: 25,
                          icon: Icon(

                            repeatMode == AudioServiceRepeatMode.all
                                ? Icons.repeat
                                : audioHandler.randomSong==true?
                                Icons.shuffle:
                                Icons.repeat,
                            color: repeatMode != AudioServiceRepeatMode.none || audioHandler.randomSong ?  Theme.of(context).colorScheme.primary : Colors.grey,
                          ),
                          onPressed: () async {
                            if(repeatMode==AudioServiceRepeatMode.none && !audioHandler.randomSong){
                              await audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
                            }
                            else if(repeatMode==AudioServiceRepeatMode.all && !audioHandler.randomSong){
                              audioHandler.randomSong=true;
                              await audioHandler.setRepeatMode(AudioServiceRepeatMode.none);

                            }
                            else if(audioHandler.randomSong && repeatMode==AudioServiceRepeatMode.none){
                              audioHandler.randomSong=false;

                            }
                            /*         countWithoutCloud= repeatMode== AudioServiceRepeatMode.none ? 1 : (audioHandler.randomSong==true) ? 3 : 2;
                            Log.d('$countWithoutCloud');
                            Log.d("repeatMode: $repeatMode and ${audioHandler.randomSong}");
                            if (countWithoutCloud==1) {

                             await  audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
                            }  else if(countWithoutCloud==2  ) {
                               audioHandler.randomSong=true;
                              await audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
                            }
                            else if(countWithoutCloud==3){
                              audioHandler.randomSong=false;
                              await audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
                              countWithoutCloud=0;
                            }

                            countWithoutCloud++;
                            Log.d('$countWithoutCloud');
                            Log.d("repeatMode: $repeatMode and ${audioHandler.randomSong}");*/
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

Future<void> enableRandom(AudioServiceRepeatMode repeatMode) async {
  if(repeatMode==AudioServiceRepeatMode.one){
    audioHandler.randomSong=true;
    }
  else{
    audioHandler.randomSong=false;
  }

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
