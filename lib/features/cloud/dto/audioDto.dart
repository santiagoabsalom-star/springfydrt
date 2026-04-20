import 'package:springfydrt/custom/audio_service.dart';

class AudioDTO {
  final String nombreAudio;
  final String path;
  final String audioId;
  final int duration;
  AudioDTO({
    required this.duration,
    required this.nombreAudio,
    required this.path,
    required this.audioId,
  });


  factory AudioDTO.fromJson(Map<String, dynamic> json) {
    return AudioDTO(
      duration: json['duration'] ?? 0,
      nombreAudio: json['nombreAudio'] ?? '',
      path: json['path'] ?? '',
      audioId: json['audioId'] ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    return {

      'duration': duration,
      'nombreAudio': nombreAudio,
      'path': path,
      'audioId': audioId,
    };
  }

  MediaItem toMediaItem() {
    return MediaItem(
      id: path,
      album: "Springfy Cloud",
      title: nombreAudio,
      duration: Duration(seconds:duration),
      artist: "Nigger", //
      extras: {'videoId': audioId},

      artUri: getValidArtUri(audioId),
    );
  }
  Uri getValidArtUri(String audioId) {
    try {
      return Uri.parse('https://youtube.com');
    } catch (_) {
      // Fallback to a local asset or a placeholder if the URL is malformed
      return Uri.parse('asset:///assets/images/default_cover.png');
    }
  }

}