import 'package:audio_service/audio_service.dart';

class AudioDTO {
  final String nombreAudio;
  final String pathAudio;
  final String videoId;

  AudioDTO({
    required this.nombreAudio,
    required this.pathAudio,
    required this.videoId,
  });

  // Para convertir la respuesta de tu backend/servicio a este objeto
  factory AudioDTO.fromJson(Map<String, dynamic> json) {
    return AudioDTO(
      nombreAudio: json['nombreAudio'] ?? '',
      pathAudio: json['pathAudio'] ?? '',
      videoId: json['videoId'] ?? '',
    );
  }

  // Convierte el DTO a un MediaItem para que aparezca en la Pantalla de Bloqueo
  MediaItem toMediaItem() {
    return MediaItem(
      id: pathAudio, // La URL o path del archivo
      album: "Springfy Cloud",
      title: nombreAudio,
      artist: "YouTube Content", // O el nombre que prefieras
      extras: {'videoId': videoId},
      // Puedes añadir una carátula por defecto de YT
      artUri: Uri.parse('https://img.youtube.com/vi/$videoId/0.jpg'),
    );
  }
}