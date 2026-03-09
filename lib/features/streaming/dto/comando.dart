

class ComandoDTO {
  final String comando;
  final int currentPosition;
  final int segundosToMove;
  final String musicId;
  final int duration;
  final String seguidor, anfitrion;
  final bool isPlaying;
  final bool isRepeating;
  ComandoDTO({
    required this.isRepeating,
    required this.duration,
    required this.comando,
    required this.currentPosition,
    required this.segundosToMove,
    required this.musicId,
    required this.seguidor,
    required this.anfitrion,
    required this.isPlaying
  });

  factory ComandoDTO.fromJson(Map<String, dynamic> json) {
    return ComandoDTO(
      isRepeating: json['isRepeating'] ?? false,
      isPlaying: json['isPlaying'] ?? true,
      seguidor: json['seguidor'] ?? '',
      duration: json['duration'] ?? 0,
      anfitrion: json['anfitrion'] ?? '',
      comando: json['comando'] ?? '',
      currentPosition: json['currentPosition'] ?? 0,
      segundosToMove: json['segundosToMove'] ?? 0,
      musicId: json['musicId'] ?? '',
    );
  }
}
