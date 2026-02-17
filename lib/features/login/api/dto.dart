class LoginRequest {
  final String username;
  final String password;

  LoginRequest({
    required this.username,
    required this.password,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) {
    return LoginRequest(
      username: json['username'] as String,
      password: json['password'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}
class ResponseBase {
  final String status;

  final int? httpError;
  final int? httpCode;

  final String? response;
  final String? message;

  final String? token;
  final String? username;
  final int? id; // en dart usamos int para long

  ResponseBase({
    required this.status,
    this.httpError,
    this.httpCode,
    this.response,
    this.message,
    this.token,
    this.username,
    this.id,
  });

  factory ResponseBase.fromJson(Map<String, dynamic> json) {
    return ResponseBase(
      status: json['status'] as String,
      httpError: json['httpError'] as int?,
      httpCode: json['httpCode'] as int?,
      response: json['response'] as String?,
      message: json['message'] as String?,
      token: json['token'] as String?,
      username: json['username'] as String?,
      id: json['id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "status": status,
      "httpError": httpError,
      "httpCode": httpCode,
      "response": response,
      "message": message,
      "token": token,
      "username": username,
      "id": id,
    };
  }
}
class LoginResponse extends ResponseBase {
  LoginResponse({
    required super.status,
    super.httpError,
    super.httpCode,
    super.response,
    super.message,
    super.token,
    super.username,
    super.id,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final base = ResponseBase.fromJson(json);

    return LoginResponse(
      status: base.status,
      httpError: base.httpError,
      httpCode: base.httpCode,
      response: base.response,
      message: base.message,
      token: base.token,
      username: base.username,
      id: base.id,
    );
  }
}

