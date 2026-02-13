import 'package:flutter/material.dart';
import 'package:springfydrt/features/cloud/dto/audioDto.dart';

import '../cloud/api/api_cloud.dart';

class StreamingPage extends StatefulWidget {
  const StreamingPage({super.key});

  @override
  State<StreamingPage> createState() => _StreamingPageState();
}

class _StreamingPageState extends State<StreamingPage>{
  final ApiCloud _apiCloud = ApiCloud();
  late Future<List<AudioDTO>> _cloudSongs;

  void _refreshData() {
    setState(() {
      _cloudSongs = _apiCloud.allOnCloudWav();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Text('Duo'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshData,
              ),
            ],
        ),
        body: Center(
          child: Text('In Develop'),
        ));
  }
}