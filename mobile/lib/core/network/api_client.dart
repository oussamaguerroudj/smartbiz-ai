import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/app_platform.dart';
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

  static const String definedApiUrl = String.fromEnvironment('API_URL', defaultValue: '');
  static const String productionApiUrl = 'https://smartbiz-ai-backend-1cij.onrender.com/api';

  static String normalizeBaseUrl(String raw) => normalizeUrl(raw);

  static String normalizeUrl(String raw) {
    var clean = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isEmpty) return '';
    if (clean.endsWith('/apicd')) {
      clean = clean.substring(0, clean.length - 2);
    }
    if (!clean.endsWith('/api')) {
      clean = '$clean/api';
    }
    return clean;
  }

  static String get defaultBaseUrl {
    if (definedApiUrl.isNotEmpty) {
      return normalizeUrl(definedApiUrl);
    }
    if (kIsWeb) {
      if (kReleaseMode) {
        return productionApiUrl;
      }
      return 'http://127.0.0.1:4000/api';
    }
    // In debug mode only, provide local server URL if none defined
    if (!kReleaseMode) {
      if (AppPlatform.isDesktop) {
        return 'http://127.0.0.1:4000/api';
      }
      return 'http://10.0.2.2:4000/api';
    }
    return productionApiUrl;
  }

  static String baseUrl = defaultBaseUrl;

  static Future<void> initBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('server_base_url');
      if (kReleaseMode && definedApiUrl.isNotEmpty) {
        // In release builds, compile-time API_URL is authoritative.
        baseUrl = defaultBaseUrl;
        if (saved != baseUrl) {
          await prefs.setString('server_base_url', baseUrl);
        }
      } else if (saved != null && saved.trim().isNotEmpty) {
        baseUrl = normalizeUrl(saved);
      } else {
        baseUrl = defaultBaseUrl;
      }
    } catch (_) {
      baseUrl = defaultBaseUrl;
    }
  }

  /// In debug mode only, test if adb reverse 127.0.0.1:4000 is reachable.
  static Future<void> detectBestBaseUrl() async {
    if (kReleaseMode || kIsWeb) return;
    if (baseUrl.contains('127.0.0.1') || baseUrl.contains('localhost')) {
      final client = http.Client();
      try {
        final res = await client
            .get(Uri.parse('http://127.0.0.1:4000/health'))
            .timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          return;
        }
      } catch (_) {
        baseUrl = 'http://10.0.2.2:4000/api';
      } finally {
        client.close();
      }
    }
  }

  static Future<void> setBaseUrl(String url) async {
    baseUrl = normalizeUrl(url);
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

  void _logDebugRequest(String method, String path, Uri uri) {
    debugPrint('=== [API REQUEST] ===');
    debugPrint('API base URL: $baseUrl');
    debugPrint('HTTP method: $method');
    debugPrint('request path: $path');
    debugPrint('final URL: $uri');
  }

  void _logDebugResponse(int statusCode, String body) {
    debugPrint('=== [API RESPONSE] ===');
    debugPrint('HTTP status: $statusCode');
    debugPrint('response body: $body');
    debugPrint('======================');
  }

  dynamic _decode(
    http.Response response, {
    String? method,
    String? path,
    Uri? uri,
  }) {
    dynamic body;

    try {
      body = response.body.isEmpty ? {} : jsonDecode(response.body);
    } catch (_) {
      body = {};
    }

    _logDebugResponse(response.statusCode, response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final rawMessage = (body is Map && body['message'] != null)
        ? body['message'].toString()
        : 'Request failed (${response.statusCode})';

    final displayMessage = kReleaseMode
        ? rawMessage
        : '$rawMessage\n\nMETHOD: ${method ?? 'UNKNOWN'}\nFULL URL: ${uri ?? '$baseUrl$path'}\nPATH: ${path ?? 'UNKNOWN'}\nSTATUS: ${response.statusCode}\nRESPONSE: ${response.body}';

    throw ApiException(
      statusCode: response.statusCode,
      message: displayMessage,
      code: body is Map ? body['code']?.toString() : null,
      method: method,
      url: uri?.toString() ?? '$baseUrl$path',
      path: path,
      responseBody: response.body,
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
        timeout ?? const Duration(seconds: 45),
      );
    } on http.ClientException catch (e) {
      final isPermission = e.message.toLowerCase().contains('permission denied');
      throw ApiException(
        statusCode: 0,
        message: isPermission
            ? 'Network permission denied by device (Permission denied).'
            : 'Cannot reach server at $baseUrl. Please check internet connection or server availability.',
        code: isPermission ? 'PERMISSION_DENIED' : 'CONNECTION_ERROR',
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        message: 'Server connection timed out ($baseUrl). The server may be waking up, please try again.',
        code: 'TIMEOUT',
      );
    } on FormatException {
      throw ApiException(
        statusCode: 0,
        message: 'Invalid server response.',
        code: 'INVALID_RESPONSE',
      );
    }

    // FIX (reported bug): a merely-expired access token (30 min TTL  - 
    // see backend env.js) used to surface as a raw 401 on whatever
    // screen the user happened to be on, with nothing renewing the
    // session  -  indistinguishable from being logged out. Now: on the
    // FIRST 401 for a given request, try the refresh token once; if
    // that succeeds, transparently retry the exact same request with
    // the new access token. Only if refresh itself fails (refresh
    // token also expired/revoked, or there wasn't one) does the
    // session actually get cleared  -  that's the one case update where
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
    final uri = _uri(path, query);
    _logDebugRequest('GET', path, uri);
    final response = await _request(
      () => http.get(
        uri,
        headers: _headers,
      ),
    );

    return _decode(response, method: 'GET', path: path, uri: uri);
  }

  /// Ch. 7/9 printing (Clinic remaining-issues pass)  -  for endpoints
  /// that return a binary body (application/pdf) instead of JSON, so
  /// _decode's jsonDecode would just fail/return {}. Same auth/refresh
  /// handling as [get] (goes through the same [_request]); only the
  /// response parsing differs.
  Future<Uint8List> getBytes(String path, {Map<String, String>? query}) async {
    final uri = _uri(path, query);
    _logDebugRequest('GET', path, uri);
    final response = await _request(
      () => http.get(
        uri,
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
    final rawMsg = (body is Map && body['message'] != null)
        ? body['message'].toString()
        : 'Request failed (${response.statusCode})';
    final displayMessage = kReleaseMode
        ? rawMsg
        : '$rawMsg\n\nMETHOD: GET\nFULL URL: $uri\nPATH: $path\nSTATUS: ${response.statusCode}\nRESPONSE: ${response.body}';
    throw ApiException(
      statusCode: response.statusCode,
      message: displayMessage,
      code: body is Map ? body['code']?.toString() : null,
      method: 'GET',
      url: uri.toString(),
      path: path,
      responseBody: response.body,
    );
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Duration? timeout,
    http.Client? client,
  }) async {
    final uri = _uri(path);
    _logDebugRequest('POST', path, uri);
    final response = await _request(
      () => client != null
          ? client.post(
              uri,
              headers: _headers,
              body: body != null ? jsonEncode(body) : null,
            )
          : http.post(
              uri,
              headers: _headers,
              body: body != null ? jsonEncode(body) : null,
            ),
      timeout: timeout,
    );

    return _decode(response, method: 'POST', path: path, uri: uri);
  }

  Future<dynamic> put(
    String path, {
    Object? body,
  }) async {
    final uri = _uri(path);
    _logDebugRequest('PUT', path, uri);
    final response = await _request(
      () => http.put(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );

    return _decode(response, method: 'PUT', path: path, uri: uri);
  }

  /// Added alongside the Restaurant module: every PATCH-declared route
  /// in this backend (clinic appointments, restaurant tables/orders/
  /// menu/reservations) previously had no matching client verb  -  only
  /// get/post/put/delete existed. Purely additive; no existing call
  /// site is touched.
  Future<dynamic> patch(
    String path, {
    Object? body,
  }) async {
    final uri = _uri(path);
    _logDebugRequest('PATCH', path, uri);
    final response = await _request(
      () => http.patch(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );

    return _decode(response, method: 'PATCH', path: path, uri: uri);
  }

  Future<dynamic> delete(
    String path, {
    Object? body,
  }) async {
    final uri = _uri(path);
    _logDebugRequest('DELETE', path, uri);
    final response = await _request(
      () => http.delete(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );

    return _decode(response, method: 'DELETE', path: path, uri: uri);
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref),
);

