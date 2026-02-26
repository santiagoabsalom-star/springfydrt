import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/log.dart';
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
    _checkLoginAndNavigate();
  }

  Future<void> _checkLoginAndNavigate() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
      return;
    }


    final directory = await getApplicationDocumentsDirectory();
    final loginFile = File(p.join(directory.path, 'loginInfo.json'));

    if (await loginFile.exists()) {
      Log.d("Archivo de login encontrado. Navegando a MainPage mientras se verifica en segundo plano.");
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
      );

      _verifyLoginInBackground(loginFile);

    } else {
      Log.d("Archivo de login no encontrado. Navegando a LoginScreen.");
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _verifyLoginInBackground(File loginFile) async {
    try {
      final raw = await loginFile.readAsString();
      final Map<String, dynamic> decodedJson = jsonDecode(raw);
      final loginRequest = LoginRequest.fromJson(decodedJson);

      if (loginRequest.username.isEmpty || loginRequest.password.isEmpty) {
        throw Exception("Credenciales inválidas en el archivo local.");
      }

      final LoginResponse response = await login(loginRequest);

      if (response.httpCode != 200) {
        throw Exception("La verificación en segundo plano falló: ${response.message}");
      }

      await TokenStorage.saveLogin(
        token: response.token!,
        username: response.username ?? "",
        id: response.id ?? 0,
      );
      Log.d("Verificación en segundo plano exitosa. Token actualizado.");

    } catch (e) {
      Log.d("Error en la verificación de fondo: $e. Redirigiendo a LoginScreen.");

      if (mounted) {

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false, // Elimina todas las rutas anteriores
        );
      }
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
