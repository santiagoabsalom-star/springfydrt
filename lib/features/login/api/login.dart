import 'dart:convert';


import '../../../core/network/api_connect.dart';
import 'dto.dart';

Future<LoginResponse> login(LoginRequest req) async {
  final api = ApiConnect();

  final res = await api.post("/api/auth/login",false, req.toJson());


  final Map<String, dynamic> json = jsonDecode(res.body);



  return LoginResponse.fromJson(json);
}