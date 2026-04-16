import 'dart:convert';

import '../../../core/network/api_connect.dart';
import '../dtos/song_dto.dart';
class SearchApi {

  Future<SongDto> searchByName(String name) async {
    final response = await ApiConnect.instance.postWithArgs(
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


