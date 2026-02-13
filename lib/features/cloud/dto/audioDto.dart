import 'package:audio_service/audio_service.dart';

class AudioDTO {
  final String nombreAudio;
  final String path;
  final String audioId;

  AudioDTO({
    required this.nombreAudio,
    required this.path,
    required this.audioId,
  });


  factory AudioDTO.fromJson(Map<String, dynamic> json) {
    return AudioDTO(
      nombreAudio: json['nombreAudio'] ?? '',
      path: json['path'] ?? '',
      audioId: json['audioId'] ?? '',
    );
  }

  MediaItem toMediaItem() {
    return MediaItem(
      id: path,
      album: "Springfy Cloud",
      title: nombreAudio,
      artist: "YouTube Content", //
      extras: {'videoId': audioId},

      artUri: Uri.parse('https://img.youtube.com/vi/$audioId/0.jpg'),
    );
  }
}