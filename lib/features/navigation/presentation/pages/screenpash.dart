import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../login/api/dto.dart';
import '../../../login/api/login.dart';
import '../../../login/api/token.dart';
import '../../../login/loginpage.dart';
import 'main_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final logged = await isLogged();

    if (!mounted) return;

    if (logged) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
  Future<bool> isLogged() async {
    final directory = await getApplicationDocumentsDirectory();

    final loginFile = File(p.join(directory.path, 'loginInfo.json'));
    if (!await loginFile.exists()) {
      return false;
    }
    try {
      final raw = await loginFile.readAsString();

      final Map<String, dynamic> decodedJson = jsonDecode(raw);

      final loginRequest = LoginRequest.fromJson(decodedJson);
      if(loginRequest.username.isEmpty || loginRequest.password.isEmpty){
        return false;
      }
      final LoginResponse response= await login(loginRequest);
      if(response.httpCode!=200){

        log(response.toString());
        return false;

      }
      await TokenStorage.saveLogin(
        token: response.token!,
        username: response.username ?? "",
        id: response.id ?? 0,
      );
      return true;




    }catch(e){
      log("Error leyendo $e");
      return false;
    }


  }
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
