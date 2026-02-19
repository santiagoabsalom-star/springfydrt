import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();

  static const _keyToken = "jwt_token";
  static const _keyUsername = "username";
  static const _keyUserId = "user_id";

  static Future<void> saveLogin({
    required String token,
    required String username,
    required int id,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyUserId, value: id.toString());
  }


  static Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyUserId);
  }
  static Future<String?> getUsername() async {
    return await _storage.read(key: _keyUsername);
  }

}
