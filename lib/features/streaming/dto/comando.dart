
import 'dart:ffi';

class ComandoDTO {
  final String comando;
  final Long segundos;
  final String musicId;

  ComandoDTO({
    required this.comando,
    required this.segundos,
    required this.musicId,
  });

  factory ComandoDTO.fromJson(Map<String, dynamic> json) {
    return ComandoDTO(
      comando: json['comando'] ?? '',
      segundos: json['segundos'] ?? 0,
      musicId: json['musicId'] ?? '',
    );
  }
}
