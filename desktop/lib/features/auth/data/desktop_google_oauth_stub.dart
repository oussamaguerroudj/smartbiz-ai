class DesktopOAuthResult {
  final String? idToken;
  final String? code;
  final String? codeVerifier;
  final String? redirectUri;
  final String? clientId;

  const DesktopOAuthResult({
    this.idToken,
    this.code,
    this.codeVerifier,
    this.redirectUri,
    this.clientId,
  });

  bool get hasIdToken => idToken != null && idToken!.isNotEmpty;
  bool get hasCode => code != null && code!.isNotEmpty;
}

class DesktopGoogleOAuth {
  static bool get isSupported => false;

  static Future<DesktopOAuthResult?> authenticate({
    required String clientId,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    throw UnsupportedError(
      'Desktop Google OAuth is only supported on Windows Desktop.',
    );
  }
}
