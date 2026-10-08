/// Mirrors the backend's uniform error shape exactly
/// ({ error: true, message, code } — see backend/src/middlewares/error.middleware.js).
class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message, this.code});

  final int statusCode;
  final String message;
  final String? code;

  bool get isUnauthorized => statusCode == 401;
  bool get isValidation => code == 'VALIDATION_ERROR';

  @override
  String toString() => message;
}
