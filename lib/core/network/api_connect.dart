import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
class ApiConnect {


  static String baseUrl = 'http://192.168.0.102:3050' ;
  void verifyPlatform() { if(Platform.isLinux){
  baseUrl='http://localhost:3050';
  }
  }
  Future<http.Response> post(
      String path,
      Map<String, dynamic> body, {
        Map<String, String>? extraHeaders,
      }) async {
    final uri = Uri.parse('$baseUrl$path');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (extraHeaders != null) ...extraHeaders,
      },
      body: jsonEncode(body),
    );

    return response;
  }
  Future<http.Response> get(
      String path) async {

    final uri = Uri.parse('$baseUrl$path');
    final response = await http.get(
      uri,
        headers: {
          'Content-Type': 'application/json'
        });

    return response;
  }

}

