import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:springfydrt/features/home/dtos/song_dto.dart';

import '../../../core/downloader/downloader.dart';
import '../../../core/log.dart';
import '../../../core/network/api_connect.dart';

class DownloadApi {

  Future<Map<String, dynamic>> downloadOnCloud(String videoId) async {
    Log.d(ApiConnect.baseUrl);
    final response = await ApiConnect.instance.postWithArgs(
      '/api/download/downloadOnCloud',
      true,
      {
        'videoId': videoId,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {

      throw Exception('Error al descargar en la nube: ${response.body}');
    }

    return jsonDecode(response.body);
  }
  Future<Uint8List> sampleOnApp(String videoId) async{
    final response = await ApiConnect.instance.postWithArgs(
        '/api/download/sampleOnApp',
        true,
        {
          'videoId': videoId,
        }
    );
    if(response.statusCode != 200){
      throw Exception('MP3 no encontrado');
    }
    return response.bodyBytes;
  }
  Future<Uint8List> downloadOnApp(String videoId) async {
    Log.d(ApiConnect.baseUrl);
    final response = await ApiConnect.instance.postWithArgs(
      '/api/download/downloadOnApp',
        true,
      {
        'videoId': videoId,
      }
    );

    if (response.statusCode != 200) {
      throw Exception('MP3 no encontrado');
    }

    return response.bodyBytes;
  }

  Future<File> saveAudioFromVideo(VideoInfo video, String videoId, Directory directory) async {

    final bytes = await downloadOnApp(videoId);

    final file = await saveMp3ToStorageWithTitle(
      bytes,
      video.title,
      videoId, directory
    );

    Log.d('Guardado como: ${file.path}');
    return file;
  }


}
class DownloadParams {
final VideoInfo videoInfo;
final String audioId;
final String directoryPath;
final RootIsolateToken rootToken;
final String baseUrl;
DownloadParams(this.videoInfo, this.audioId, this.directoryPath, this.rootToken,this.baseUrl);

}

Future<void> executeDownloadInBackground(DownloadParams params) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootToken);

  final api = DownloadApi();
  ApiConnect.baseUrl=params.baseUrl;
  await api.saveAudioFromVideo(
    params.videoInfo,
    params.audioId,
    Directory(params.directoryPath),
  );
}
