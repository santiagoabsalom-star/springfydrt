import 'dart:convert';

import '../../../core/network/api_connect.dart';
import '../dtos/song_dto.dart';
class SearchApi {
  final ApiConnect _api = ApiConnect();

  Future<SongDto> searchByName(String name) async {
    final response = await _api.post(
      '/api/search/by-name',
      true,
      {
        'name': name,
      },
    );

    if (response.statusCode != 200) {

      throw Exception(response.body);
    }

    return SongDto.fromJson(
      jsonDecode(response.body),
    );
  }
}


