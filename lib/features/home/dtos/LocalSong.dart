import 'package:springfydrt/custom/audio_service.dart';

class LocalSong {
  late final String title;
  late  String path;
  late final String? videoId;

  LocalSong({
    required this.title,
    required this.path,
    required this.videoId,
  });
  void setVideoId(String videoId) {
    this.videoId = videoId;}
  void setPath(String path) {
    this.path = path;
  }
  void setTitle(String title) {
    this.title = title;
  }

  MediaItem toMediaItem() {
    return MediaItem(
      id: path,
      album: "Playlist",
      title: title,
      artist: "Nigga",
      extras: {'videoId': videoId},

      artUri: Uri.parse('https://img.youtube.com/vi/$videoId/0.jpg'),
    );
  }
}
