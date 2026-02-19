import 'dart:convert';


import '../../../core/network/api_connect.dart';
import 'dto.dart';
    ApiConnect _apiConnect= ApiConnect();
Future<LoginResponse> login(LoginRequest req) async {


  final res = await _apiConnect.post("/api/auth/login",false, req.toJson());


  final Map<String, dynamic> json = jsonDecode(res.body);



  return LoginResponse.fromJson(json);
}