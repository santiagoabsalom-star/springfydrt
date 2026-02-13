import 'dart:convert';
import 'package:springfydrt/features/cloud/dto/audioDto.dart';
import '../../../core/network/api_connect.dart';

class ApiCloud {
  final ApiConnect _api = ApiConnect();

  Future<List<AudioDTO>> allOnCloud() async {
    final response = await _api.get('/api/search/search-all-mp3');
    if (response.statusCode != 200) {
      throw Exception('Error al obtener canciones de la nube');
    }

    final List<dynamic> data = jsonDecode(response.body);

    return data.map((e) => AudioDTO.fromJson(e)).toList();

  }
  Future<List<AudioDTO>> allOnCloudWav() async {
    final response = await _api.get('/api/search/search-all-wav');
    if (response.statusCode != 200) {
      throw Exception('Error al obtener canciones de la nube');
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => AudioDTO.fromJson(e)).toList();
  }
}
