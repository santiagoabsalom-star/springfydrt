

class ComandoDTO {
  final String comando;
  final int segundos;
  final String musicId;
  final String seguidor, anfitrion;

  ComandoDTO({
    required this.comando,
    required this.segundos,
    required this.musicId,
    required this.seguidor,
    required this.anfitrion,
  });

  factory ComandoDTO.fromJson(Map<String, dynamic> json) {
    return ComandoDTO(
      seguidor: json['seguidor'] ?? '',
      anfitrion: json['anfitrion'] ?? '',
      comando: json['comando'] ?? '',
      segundos: json['segundos'] ?? 0,
      musicId: json['musicId'] ?? '',
    );
  }
}
