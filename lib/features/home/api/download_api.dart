import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:springfydrt/features/home/dtos/song_dto.dart';

import '../../../core/downloader/downloader.dart';
import '../../../core/network/api_connect.dart';

class DownloadApi {
  final ApiConnect _api = ApiConnect();

  Future<Map<String, dynamic>> downloadOnCloud(String videoId) async {
    final response = await _api.post(
      '/api/download/downloadOnCloud',
      {
        'videoId': videoId,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al descargar en la nube');
    }

    return jsonDecode(response.body);
  }

  Future<Uint8List> downloadOnApp(String videoId) async {
    final response = await _api.post(
      '/api/download/downloadOnApp',
      {
        'videoId': videoId,
      },
      extraHeaders: {
        'Accept': 'audio/mpeg',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('MP3 no encontrado');
    }

    return response.bodyBytes;
  }

  Future<File> saveAudioFromVideo(VideoInfo video, String videoId) async {
    final bytes = await downloadOnApp(videoId);

    final file = await saveMp3ToStorageWithTitle(
      bytes,
      video.title,
    );

    print('Guardado como: ${file.path}');
    return file;
  }


}

