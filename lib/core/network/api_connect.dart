import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../features/login/api/token.dart';
class ApiConnect {


  static String baseUrl = 'http://springfy.tplinkdns.com:3051';


  Future<http.Response> post(
      String path,
      bool auth,
      Map<String, dynamic> body, {
        Map<String, String>? extraHeaders,
      }) async {
    final uri = Uri.parse('$baseUrl$path');
    String? token;
    if (auth) {
      token = await TokenStorage.getToken();
    }
    final response = await http.post(
      uri,
      headers: {


        'Content-Type': 'application/json',
        'Application-id':'sp-rin-g-fy-id-application-android/29912/',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (extraHeaders != null) ...extraHeaders,
      },
      body: jsonEncode(body),
    );

    return response;
  }
  Future<http.Response> get(

      String path,  ) async {
    String? token;

      token = await TokenStorage.getToken();

    final uri = Uri.parse('$baseUrl$path');
    final response = await http.get(
      uri,
        headers: {


          'Content-Type': 'application/json',
              'Application-id':'sp-rin-g-fy-id-application-android/29912/',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        });

    return response;
  }

}

