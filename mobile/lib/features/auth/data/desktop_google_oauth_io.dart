import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_exception.dart';

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
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static String _generateRandomString([int length = 64]) {
    const charset =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Performs Google OAuth 2.0 Authorization Code flow with PKCE via local loopback HTTP server.
  /// Launches system browser, listens on loopback IPv4 (127.0.0.1:<random-port>),
  /// catches authorization code, and returns the result (ID token if direct exchange succeeded,
  /// or authorization code + PKCE verifier for confidential backend completion).
  static Future<DesktopOAuthResult?> authenticate({
    required String clientId,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    if (!isSupported) {
      throw ApiException(
        statusCode: 400,
        message: 'Desktop Google OAuth is only available on Windows Desktop.',
        code: 'PLATFORM_NOT_SUPPORTED',
      );
    }

    // 1. Bind local loopback server to an ephemeral available port
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    final redirectUri = 'http://127.0.0.1:$port';

    final state = _generateRandomString(32);
    final codeVerifier = _generateRandomString(64);
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'state': state,
      'access_type': 'offline',
      'prompt': 'select_account',
    });

    // 2. Launch system browser
    final launched = await launchUrl(authUri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await server.close(force: true);
      throw ApiException(
        statusCode: 500,
        message: 'Failed to launch system browser for Google Sign-In.',
        code: 'BROWSER_LAUNCH_FAILED',
      );
    }

    // 3. Await incoming authorization callback on local loopback server
    final completer = Completer<DesktopOAuthResult?>();

    Timer? timer;
    StreamSubscription<HttpRequest>? sub;

    void cleanup() {
      timer?.cancel();
      sub?.cancel();
      server.close(force: true);
    }

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        cleanup();
        completer.completeError(
          ApiException(
            statusCode: 408,
            message: 'Google Sign-In timed out. Please try again.',
            code: 'OAUTH_TIMEOUT',
          ),
        );
      }
    });

    sub = server.listen((HttpRequest request) async {
      try {
        final queryParams = request.uri.queryParameters;

        // If request is not to the root callback, ignore (e.g. favicon)
        if (request.uri.path != '/' && request.uri.path.isNotEmpty) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        final incomingError = queryParams['error'];
        final incomingCode = queryParams['code'];
        final incomingState = queryParams['state'];

        if (incomingError != null) {
          final errorDesc = queryParams['error_description'] ?? incomingError;
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write(_buildHtmlResponse(
              title: 'Sign In Cancelled',
              heading: 'Sign In Cancelled',
              message: 'You may close this tab and return to Modiri AI.',
              isSuccess: false,
            ));
          await request.response.close();

          if (!completer.isCompleted) {
            cleanup();
            if (incomingError == 'access_denied') {
              // User cancelled Google consent screen
              completer.complete(null);
            } else {
              completer.completeError(ApiException(
                statusCode: 400,
                message: 'Google Sign-In cancelled or failed: $errorDesc',
                code: 'GOOGLE_OAUTH_CANCELLED',
              ));
            }
          }
          return;
        }

        if (incomingState != state) {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..headers.contentType = ContentType.html
            ..write(_buildHtmlResponse(
              title: 'State Mismatch',
              heading: 'Security Check Failed',
              message: 'Invalid state parameter. You may close this tab.',
              isSuccess: false,
            ));
          await request.response.close();

          if (!completer.isCompleted) {
            cleanup();
            completer.completeError(ApiException(
              statusCode: 400,
              message: 'Invalid OAuth state parameter.',
              code: 'INVALID_STATE',
            ));
          }
          return;
        }

        if (incomingCode == null || incomingCode.isEmpty) {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..headers.contentType = ContentType.html
            ..write(_buildHtmlResponse(
              title: 'Authorization Code Missing',
              heading: 'Sign In Incomplete',
              message: 'No authorization code received. You may close this tab.',
              isSuccess: false,
            ));
          await request.response.close();

          if (!completer.isCompleted) {
            cleanup();
            completer.completeError(ApiException(
              statusCode: 400,
              message: 'No authorization code received from Google.',
              code: 'MISSING_CODE',
            ));
          }
          return;
        }

        // Send success page to browser immediately
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write(_buildHtmlResponse(
            title: 'Authorization Received',
            heading: 'Modiri AI',
            message: 'Authorization received successfully! You can close this tab and return to Modiri AI to complete your account setup.',
            isSuccess: true,
          ));
        await request.response.close();

        // 4. Attempt direct exchange with Google Token Endpoint using PKCE
        String? idToken;
        try {
          final tokenResponse = await http.post(
            Uri.parse('https://oauth2.googleapis.com/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'client_id': clientId,
              'code': incomingCode,
              'code_verifier': codeVerifier,
              'grant_type': 'authorization_code',
              'redirect_uri': redirectUri,
            },
          );

          if (tokenResponse.statusCode == 200) {
            final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
            idToken = tokenData['id_token'] as String?;
          }
        } catch (_) {}

        cleanup();

        if (idToken != null && idToken.isNotEmpty) {
          if (!completer.isCompleted) {
            completer.complete(DesktopOAuthResult(
              idToken: idToken,
              clientId: clientId,
            ));
          }
        } else {
          // Native public client PKCE: code, verifier, and redirectUri are passed to backend for confidential completion
          if (!completer.isCompleted) {
            completer.complete(DesktopOAuthResult(
              code: incomingCode,
              codeVerifier: codeVerifier,
              redirectUri: redirectUri,
              clientId: clientId,
            ));
          }
        }
      } catch (err) {
        cleanup();
        if (!completer.isCompleted) {
          completer.completeError(err is ApiException
              ? err
              : ApiException(
                  statusCode: 500,
                  message: 'Unexpected loopback error: $err',
                  code: 'LOOPBACK_ERROR',
                ));
        }
      }
    });

    return completer.future;
  }

  static String _buildHtmlResponse({
    required String title,
    required String heading,
    required String message,
    required bool isSuccess,
  }) {
    final primaryColor = isSuccess ? '#4E6AF3' : '#EA4335';
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>$title</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background-color: #0A0D24;
      color: #FFFFFF;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
    }
    .card {
      background: #15193B;
      padding: 40px 32px;
      border-radius: 16px;
      text-align: center;
      max-width: 420px;
      box-shadow: 0 12px 36px rgba(0,0,0,0.4);
      border: 1px solid #252B52;
    }
    h1 {
      font-size: 24px;
      color: $primaryColor;
      margin-top: 0;
      margin-bottom: 12px;
    }
    p {
      color: #A0A5BA;
      font-size: 15px;
      line-height: 1.6;
      margin: 8px 0;
    }
  </style>
</head>
<body>
  <div class="card">
    <h1>$heading</h1>
    <p>$message</p>
  </div>
</body>
</html>''';
  }
}
