/// Mirrors the backend's uniform error shape
/// ({ error: true, message, code, details? } — see backend/src/middlewares/error.middleware.js).
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.details,
    this.method,
    this.url,
    this.path,
    this.responseBody,
  });

  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? details;
  final String? method;
  final String? url;
  final String? path;
  final String? responseBody;

  bool get isUnauthorized => statusCode == 401;
  bool get isValidation => code == 'VALIDATION_ERROR';
  bool get isAccountSuspended => code == 'ACCOUNT_SUSPENDED';
  bool get isTrialExpired => code == 'TRIAL_EXPIRED';
  bool get isSessionRevoked => code == 'SESSION_REVOKED';

  @override
  String toString() => message;
}

