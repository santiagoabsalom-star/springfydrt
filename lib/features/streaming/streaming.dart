import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:springfydrt/features/cloud/dto/audioDto.dart';
import 'package:springfydrt/features/login/api/token.dart';
import 'package:springfydrt/features/streaming/api/wsconnect.dart';
import 'package:springfydrt/features/streaming/dto/comando.dart';
import 'package:web_socket_channel/io.dart';

import '../cloud/api/api_cloud.dart';

class StreamingPage extends StatefulWidget {
  const StreamingPage({super.key});

  @override
  State<StreamingPage> createState() => _StreamingPageState();
}

class _StreamingPageState extends State<StreamingPage>{
  final ApiCloud _apiCloud = ApiCloud();
  late Future<List<AudioDTO>> _cloudSongs;
  final isListening = ValueNotifier<bool>(false);
  bool isListeningbool=false;
  late String usuarioActual;
  @override
  void initState(){
    super.initState();
    //_obtainUser();
    //_connect();
    //_refreshData();

  }

  @override
  void dispose(){
    super.dispose();

  }
  Future<void> _obtainUser() async{
  String? usernameFromToken=await TokenStorage.getUsernameFromToken(TokenStorage.getToken() as String);
  usuarioActual=usernameFromToken as String;
  }

  Future<void>_connect() async{
    Map<String, String> userHeader= {
      'Usuario':usuarioActual
    };


        final IOWebSocketChannel channel= await connect(userHeader);
// channel.sink.add(comando);
        channel.stream.listen(
              (message){
                ComandoDTO comando= ComandoDTO.fromJson(jsonDecode(message));
                String command = comando.comando;

                if(command=="start") {
                isListening.value=true;
                isListeningbool=true;
                //hacer
                }


            },
          onDone: (){
              log("Conexion cerrada");
          }

        );



  }


 Future<void> _refreshData()async {
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
        body: ValueListenableBuilder<bool>(
          valueListenable: isListening,
          builder: (context, value, child) {
//construir una ui linda para que no vaya mal
            return value ? Text("Nadie esta conectado"
            ) : Text("El otro se conecto");

          },
        )
    );

    }

}