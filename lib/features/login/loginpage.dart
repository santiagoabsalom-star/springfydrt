import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:path_provider/path_provider.dart';
import 'package:springfydrt/features/login/api/login.dart';
import 'package:springfydrt/features/navigation/presentation/pages/main_page.dart';
import 'package:path/path.dart' as p;

import 'api/dto.dart';
import 'api/token.dart';




class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  static const _logo = AssetImage('assets/icon.png');
  Future<void> saveOnFile(LoginRequest login) async {
    Directory dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, "loginInfo.json"));
    final encoder = JsonEncoder.withIndent("  ");
    final jsonString = encoder.convert(login.toJson());

    await file.writeAsString(jsonString);
  }

  Duration get loginTime => const Duration(milliseconds: 2250);

  Future<String?> _authUser(LoginData data) async {
    debugPrint('Name: ${data.name}, Password: ${data.password}');
    final LoginRequest request = LoginRequest(
        username: data.name, password: data.password);
    final LoginResponse response = await login(request);
    if (response.httpCode != 200) {
      return response.response;
    }
    saveOnFile(request);
    await TokenStorage.saveLogin(
      token: response.token!,
      username: response.username ?? "",
      id: response.id ?? 0,
    );
    return null;
  }

  Future<String?> _signupUser(SignupData data) {
    debugPrint('Signup Name: ${data.name}, Password: ${data.password}');
    return Future.delayed(loginTime).then((_) {
      return null;
    });
  }

  Future<String?> _recoverPassword(String name) {
    debugPrint('Name: $name');
    return Future.delayed(loginTime).then((_) {
      if (1==1){
        return 'User not exists';
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlutterLogin(
      userType: LoginUserType.name,

      userValidator: (value) {
        if (value == null || value
            .trim()
            .isEmpty) {
          return "El usuario es obligatorio";
        }

        if (value
            .trim()
            .length < 3) {
          return "Mínimo 3 caracteres";
        }

        return null;
      },
      passwordValidator: (value){
        if (value == null || value
            .trim()
            .isEmpty) {
          return "La contrasenia es obligatoria";
        }

        if (value
            .trim()
            .length < 3) {
          return "Mínimo 3 caracateres";
        }

        return null;
      },



      title: 'Springfy',
      logo: _logo,
      onLogin: _authUser,
      onSignup: _signupUser,
      onSubmitAnimationCompleted: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainPage()),
        );
      },
      onRecoverPassword: _recoverPassword,
    );
  }

}



