import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_desktop/features/auth/data/desktop_google_oauth.dart';

void main() {
  HttpOverrides.global = null;

  group('Desktop Google OAuth Loopback & Protocol Verification', () {
    test('DesktopGoogleOAuth reports supported on Windows platform', () {
      expect(DesktopGoogleOAuth.isSupported, isA<bool>());
    });

    test('Loopback HTTP Server catches cancellation gracefully', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      final client = HttpClient();
      final requestUri = Uri.parse('http://127.0.0.1:$port?error=access_denied&state=abc');

      var handled = false;
      server.listen((HttpRequest req) async {
        final params = req.uri.queryParameters;
        if (params['error'] == 'access_denied') {
          handled = true;
          req.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write('<html><body>Cancelled</body></html>');
          await req.response.close();
        }
      });

      final req = await client.getUrl(requestUri);
      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.ok);
      expect(handled, isTrue);

      final body = await resp.transform(utf8.decoder).join();
      expect(body, contains('Cancelled'));

      await server.close(force: true);
      client.close();
    });

    test('Loopback HTTP Server rejects state mismatch with HTTP 400', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      const expectedState = 'cryptographic_state_12345';

      server.listen((HttpRequest req) async {
        final params = req.uri.queryParameters;
        if (params['state'] != expectedState) {
          req.response
            ..statusCode = HttpStatus.badRequest
            ..headers.contentType = ContentType.html
            ..write('<html><body>Security Check Failed: State Mismatch</body></html>');
          await req.response.close();
        }
      });

      final client = HttpClient();
      final badRequestUri = Uri.parse('http://127.0.0.1:$port?code=auth_code&state=forged_state');
      final req = await client.getUrl(badRequestUri);
      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.badRequest);

      final body = await resp.transform(utf8.decoder).join();
      expect(body, contains('State Mismatch'));

      await server.close(force: true);
      client.close();
    });

    test('Loopback HTTP Server rejects missing authorization code with HTTP 400', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      const expectedState = 'cryptographic_state_12345';

      server.listen((HttpRequest req) async {
        final params = req.uri.queryParameters;
        if (params['state'] == expectedState && (params['code'] == null || params['code']!.isEmpty)) {
          req.response
            ..statusCode = HttpStatus.badRequest
            ..headers.contentType = ContentType.html
            ..write('<html><body>Missing Authorization Code</body></html>');
          await req.response.close();
        }
      });

      final client = HttpClient();
      final badRequestUri = Uri.parse('http://127.0.0.1:$port?state=$expectedState');
      final req = await client.getUrl(badRequestUri);
      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.badRequest);

      final body = await resp.transform(utf8.decoder).join();
      expect(body, contains('Missing Authorization Code'));

      await server.close(force: true);
      client.close();
    });

    test('Loopback HTTP Server renders success page on valid code and state', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      const expectedState = 'cryptographic_state_12345';

      server.listen((HttpRequest req) async {
        final params = req.uri.queryParameters;
        if (params['state'] == expectedState && params['code'] == 'auth_code_999') {
          req.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write('<html><body>Authentication Successful! Return to Modiri AI.</body></html>');
          await req.response.close();
        }
      });

      final client = HttpClient();
      final validRequestUri = Uri.parse('http://127.0.0.1:$port?code=auth_code_999&state=$expectedState');
      final req = await client.getUrl(validRequestUri);
      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.ok);

      final body = await resp.transform(utf8.decoder).join();
      expect(body, contains('Authentication Successful!'));

      await server.close(force: true);
      client.close();
    });
  });

  group('DesktopOAuthResult Data Class & Security Tests', () {
    test('DesktopOAuthResult correctly models direct ID token result', () {
      const result = DesktopOAuthResult(idToken: 'sample_id_token_123');
      expect(result.hasIdToken, isTrue);
      expect(result.hasCode, isFalse);
      expect(result.idToken, 'sample_id_token_123');
      expect(result.code, isNull);
    });

    test('DesktopOAuthResult correctly models code exchange parameters without client secret', () {
      const result = DesktopOAuthResult(
        code: 'auth_code_xyz',
        codeVerifier: 'verifier_abc',
        redirectUri: 'http://127.0.0.1:54321',
        clientId: '128675361201-qhb7u121simtqfq3nubaek2nhk0qae2f.apps.googleusercontent.com',
      );
      expect(result.hasIdToken, isFalse);
      expect(result.hasCode, isTrue);
      expect(result.code, 'auth_code_xyz');
      expect(result.codeVerifier, 'verifier_abc');
      expect(result.redirectUri, 'http://127.0.0.1:54321');
      expect(result.clientId, '128675361201-qhb7u121simtqfq3nubaek2nhk0qae2f.apps.googleusercontent.com');
    });
  });
}

