import 'dart:convert';
import 'package:http/http.dart' as http;
class ApiConnect {


  static String baseUrl = 'http://springfy.tplinkdns.com:3051' ;


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
        'Application-id':'sp-rin-g-fy-id-application-android/29912/',
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

          'Content-Type': 'application/json',
              'Application-id':'sp-rin-g-fy-id-application-android/29912/',
        });

    return response;
  }

}

