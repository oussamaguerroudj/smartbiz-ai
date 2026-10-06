import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_exception.dart';
import 'session.dart';

enum RefreshResult {
  refreshed,
  invalidToken,
  networkUnavailable,
}

class ApiClient {
  ApiClient(this._ref);

  final Ref _ref;

  static const String _envApiUrl = String.fromEnvironment('API_URL', defaultValue: '');
  static const String defaultBaseUrl = _envApiUrl.isNotEmpty ? _envApiUrl : 'http://127.0.0.1:4000/api';
  static const String lanFallbackBaseUrl = 'http://10.33.166.30:4000/api';
  static String baseUrl = defaultBaseUrl;

  static Future<void> initBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('server_base_url');
      if (saved != null && saved.trim().isNotEmpty) {
        baseUrl = saved.trim();
      } else {
        unawaited(detectBestBaseUrl());
      }
    } catch (_) {}
  }

  /// Automatically tests if 127.0.0.1:4000 is reachable (e.g. adb reverse over USB).
  /// If unreachable (e.g. phone running over Wi-Fi without USB), transparently
  /// switches to the local network LAN IP so real device scanning works out-of-the-box.
  static Future<void> detectBestBaseUrl() async {
    if (baseUrl.contains('127.0.0.1') || baseUrl.contains('localhost')) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      try {
        final req = await client.getUrl(Uri.parse('http://127.0.0.1:4000/health'));
        final res = await req.close();
        if (res.statusCode == 200) {
          client.close();
          return; // 127.0.0.1 works (adb reverse active)
        }
      } catch (_) {
        // 127.0.0.1 unreachable (no adb reverse), probe LAN IP
        try {
          final lanReq = await client.getUrl(Uri.parse('http://10.33.166.30:4000/health'));
          final lanRes = await lanReq.close();
          if (lanRes.statusCode == 200) {
            baseUrl = lanFallbackBaseUrl;
          }
        } catch (_) {}
      } finally {
        client.close();
      }
    }
  }

  static Future<void> setBaseUrl(String url) async {
    var clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (!clean.endsWith('/api')) {
      clean = '$clean/api';
    }
    baseUrl = clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_base_url', baseUrl);
    } catch (_) {}
  }

  Map<String, String> get _headers {
    final token = _ref.read(sessionProvider).accessToken;

    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query,
    );
  }

  dynamic _decode(http.Response response) {
    dynamic body;

    try {
      body = response.body.isEmpty ? {} : jsonDecode(response.body);
    } catch (_) {
      body = {};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: (body is Map && body['message'] != null)
          ? body['message'].toString()
          : 'Request failed (${response.statusCode})',
      code: body is Map ? body['code']?.toString() : null,
    );
  }

  Future<http.Response> _request(
    Future<http.Response> Function() request, {
    Duration? timeout,
    bool isRetryAfterRefresh = false,
  }) async {
    http.Response response;

    try {
      response = await request().timeout(
        timeout ?? const Duration(seconds: 15),
      );
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Cannot connect to server ($baseUrl). Check network or server URL in Settings.',
        code: 'CONNECTION_ERROR',
      );
    } on HttpException {
      throw ApiException(
        statusCode: 0,
        message: 'Network error connecting to $baseUrl.',
        code: 'NETWORK_ERROR',
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        message: 'Server connection timed out ($baseUrl).',
        code: 'TIMEOUT',
      );
    } on FormatException {
      throw ApiException(
        statusCode: 0,
        message: 'Invalid server response.',
        code: 'INVALID_RESPONSE',
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        statusCode: 0,
        message: e.message.isNotEmpty ? e.message : 'Connection closed.',
        code: 'CLIENT_ERROR',
      );
    }

    // FIX (reported bug): a merely-expired access token (30 min TTL —
    // see backend env.js) used to surface as a raw 401 on whatever
    // screen the user happened to be on, with nothing renewing the
    // session — indistinguishable from being logged out. Now: on the
    // FIRST 401 for a given request, try the refresh token once; if
    // that succeeds, transparently retry the exact same request with
    // the new access token. Only if refresh itself fails (refresh
    // token also expired/revoked, or there wasn't one) does the
    // session actually get cleared — that's the one case update where
    // logging the user out is actually correct.
    if (response.statusCode == 401 && !isRetryAfterRefresh) {
      final refreshResult = await _tryRefreshSession();

      if (refreshResult == RefreshResult.refreshed) {
        return _request(request, timeout: timeout, isRetryAfterRefresh: true);
      }

      if (refreshResult == RefreshResult.invalidToken) {
        // Explicitly rejected by server (401/403) or missing refresh token: clear session
        await _ref.read(sessionProvider.notifier).clear();
      }
      // If networkUnavailable, do NOT clear session! The user remains authenticated in offline mode.
    }

    return response;
  }

  /// Directly hits /auth/refresh with http (not through this class's
  /// own get/post helpers) to avoid recursing back into _request.
  /// Distinguishes between network/timeout failure and explicit server rejection.
  Future<RefreshResult> _tryRefreshSession() async {
    final refreshToken = _ref.read(sessionProvider).refreshToken;

    if (refreshToken == null || refreshToken.isEmpty) {
      return RefreshResult.invalidToken;
    }

    try {
      final response = await http
          .post(
            _uri('/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) {
        return RefreshResult.invalidToken;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return RefreshResult.networkUnavailable;
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return RefreshResult.networkUnavailable;

      await _ref.read(sessionProvider.notifier).apply(data);
      return RefreshResult.refreshed;
    } on SocketException {
      return RefreshResult.networkUnavailable;
    } on HttpException {
      return RefreshResult.networkUnavailable;
    } on TimeoutException {
      return RefreshResult.networkUnavailable;
    } on http.ClientException {
      return RefreshResult.networkUnavailable;
    } catch (_) {
      return RefreshResult.networkUnavailable;
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _request(
      () => http.get(
        _uri(path, query),
        headers: _headers,
      ),
    );

    return _decode(response);
  }

  /// Ch. 7/9 printing (Clinic remaining-issues pass) — for endpoints
  /// that return a binary body (application/pdf) instead of JSON, so
  /// _decode's jsonDecode would just fail/return {}. Same auth/refresh
  /// handling as [get] (goes through the same [_request]); only the
  /// response parsing differs.
  Future<Uint8List> getBytes(String path, {Map<String, String>? query}) async {
    final response = await _request(
      () => http.get(
        _uri(path, query),
        headers: _headers,
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    dynamic body;
    try {
      body = response.body.isEmpty ? {} : jsonDecode(response.body);
    } catch (_) {
      body = {};
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: (body is Map && body['message'] != null)
          ? body['message'].toString()
          : 'Request failed (${response.statusCode})',
      code: body is Map ? body['code']?.toString() : null,
    );
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Duration? timeout,
    http.Client? client,
  }) async {
    final response = await _request(
      () => client != null
          ? client.post(
              _uri(path),
              headers: _headers,
              body: body != null ? jsonEncode(body) : null,
            )
          : http.post(
              _uri(path),
              headers: _headers,
              body: body != null ? jsonEncode(body) : null,
            ),
      timeout: timeout,
    );

    return _decode(response);
  }

  Future<dynamic> put(
    String path, {
    Object? body,
  }) async {
    final response = await _request(
      () => http.put(
        _uri(path),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );

    return _decode(response);
  }

  /// Added alongside the Restaurant module: every PATCH-declared route
  /// in this backend (clinic appointments, restaurant tables/orders/
  /// menu/reservations) previously had no matching client verb — only
  /// get/post/put/delete existed. Purely additive; no existing call
  /// site is touched.
  Future<dynamic> patch(
    String path, {
    Object? body,
  }) async {
    final response = await _request(
      () => http.patch(
        _uri(path),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );

    return _decode(response);
  }

  Future<dynamic> delete(
    String path, {
    Object? body,
  }) async {
    final response = await _request(
      () => http.delete(
        _uri(path),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );

    return _decode(response);
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref),
);

