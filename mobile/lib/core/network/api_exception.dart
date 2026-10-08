/// Mirrors the backend's uniform error shape exactly
/// ({ error: true, message, code } — see backend/src/middlewares/error.middleware.js).
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.method,
    this.url,
    this.path,
    this.responseBody,
  });

  final int statusCode;
  final String message;
  final String? code;
  final String? method;
  final String? url;
  final String? path;
  final String? responseBody;

  bool get isUnauthorized => statusCode == 401;
  bool get isValidation => code == 'VALIDATION_ERROR';

  @override
  String toString() => message;
}
