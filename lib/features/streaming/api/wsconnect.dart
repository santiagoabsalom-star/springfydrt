import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart';
import 'package:springfydrt/core/network/api_connect.dart';
import 'package:web_socket_channel/io.dart';
final Uri streamUri= Uri.parse("ws://springfy.tplinkdns.com:3051/stream");
ApiConnect _apiConnect= ApiConnect();
Map<String, String> applicationHeader= {
  'Application-id': 'sp-rin-g-fy-id-application-android/29912/'

};

Future<IOWebSocketChannel> connect(Map<String,String> headers) async {
  headers.addAll(applicationHeader);
return IOWebSocketChannel.connect(streamUri, headers: headers);


}
Future<String?> obtainUserConection() async {
  final Response response=await _apiConnect.get("/api/streaming/get-duo");
  if(response.statusCode!=200){
    return null;
  }
  return response.body;




}
Future<List<String>> allUserNames() async {
  final Response response =
  await _apiConnect.get("/api/streaming/get-all-usernames");

  final List<dynamic> data = jsonDecode(response.body);

  return data.map((e) => e.toString()).toList();
}

Future<String> createDuo(DuoRequest duorequest) async{
  final Response response=await _apiConnect.post("/api/streaming/create-duo", true, duorequest.toJson() );
    log("Body de la respuesta: ${response.body}");
  return response.body;

}

class DuoRequest {
  final String username1;
  final String username2;

  DuoRequest({
    required this.username1,
    required this.username2,
  });

  factory DuoRequest.fromJson(Map<String, dynamic> json) {
    return DuoRequest(
      username1: json['username1'],
      username2: json['username2'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username1': username1,
      'username2': username2,
    };
  }
}






