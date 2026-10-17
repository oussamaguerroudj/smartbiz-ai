import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_exception.dart';
import 'session.dart';

class ApiClient {
  final Ref _ref;

  static const String defaultProductionApiUrl =
      'https://smartbiz-ai-backend-1cij.onrender.com/api';
  static const String envApiUrl =
      String.fromEnvironment('API_URL', defaultValue: '');

  static String _configuredUrl = '';

  static String get baseUrl {
    if (envApiUrl.isNotEmpty) return envApiUrl;
    if (_configuredUrl.isNotEmpty) return _configuredUrl;
    return defaultProductionApiUrl;
  }

  static void setCustomBaseUrl(String url) {
    _configuredUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static Future<void> loadPersistedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('modiri_desktop_custom_api_url');
      if (saved != null && saved.isNotEmpty) {
        _configuredUrl = saved;
      }
    } catch (_) {}
  }

  static Future<void> persistCustomUrl(String url) async {
    setCustomBaseUrl(url);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('modiri_desktop_custom_api_url', _configuredUrl);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> checkHealth([String? urlToTest]) async {
    final target = (urlToTest != null && urlToTest.trim().isNotEmpty)
        ? urlToTest.trim().replaceAll(RegExp(r'/+$'), '')
        : baseUrl;
    final stopwatch = Stopwatch()..start();
    try {
      final healthPath = target.endsWith('/api') ? '$target/health' : '$target/api/health';
      Uri uri = Uri.parse(healthPath);
      http.Response res;
      try {
        res = await http.get(uri, headers: {
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 35));
      } catch (firstErr) {
        // Fallback to /health on root domain if /api/health had issue
        final rootTarget = target.replaceAll(RegExp(r'/api$'), '');
        uri = Uri.parse('$rootTarget/health');
        res = await http.get(uri, headers: {
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 35));
      }
      stopwatch.stop();
      final isHealthy = res.statusCode >= 200 && res.statusCode < 300;
      return {
        'success': isHealthy,
        'healthy': isHealthy,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'statusCode': res.statusCode,
        'body': res.body,
        if (!isHealthy) 'error': 'HTTP ${res.statusCode}',
      };
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'healthy': false,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'error': e.toString(),
      };
    }
  }

  ApiClient(this._ref);

  Map<String, String> _buildHeaders() {
    final session = _ref.read(sessionProvider);
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client-Platform': 'windows-desktop',
    };
    if (session.accessToken != null && session.accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    return headers;
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: query);
    return _executeWithAuthRefresh(
      endpoint,
      () => http.get(uri, headers: _buildHeaders()),
    );
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _executeWithAuthRefresh(
      endpoint,
      () => http.post(
        uri,
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _executeWithAuthRefresh(
      endpoint,
      () => http.put(
        uri,
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _executeWithAuthRefresh(
      endpoint,
      () => http.patch(
        uri,
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<dynamic> delete(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _executeWithAuthRefresh(
      endpoint,
      () => http.delete(
        uri,
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<dynamic> _executeWithAuthRefresh(
    String endpoint,
    Future<http.Response> Function() requestFn, {
    bool isRetry = false,
  }) async {
    try {
      final res = await requestFn().timeout(const Duration(seconds: 45));
      final isAuthEndpoint = endpoint.startsWith('/auth/login') ||
          endpoint.startsWith('/auth/register') ||
          endpoint.startsWith('/auth/refresh');

      if (res.statusCode == 401 && !isRetry && !isAuthEndpoint) {
        final refreshed = await _tryRefreshSession();
        if (refreshed) {
          final retryRes = await requestFn().timeout(const Duration(seconds: 45));
          return _handleResponse(retryRes);
        }
      }
      return _handleResponse(res);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'Network connection error: $e');
    }
  }

  Future<bool> _tryRefreshSession() async {
    final session = _ref.read(sessionProvider);
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse('$baseUrl/auth/refresh');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 401 || res.statusCode == 403) {
        await _ref.read(sessionProvider.notifier).logout();
        return false;
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final data = decoded is Map
            ? (decoded['data'] is Map ? decoded['data'] as Map : decoded)
            : null;
        final newAccess = data?['accessToken']?.toString() ?? data?['token']?.toString();
        final newRefresh = data?['refreshToken']?.toString();
        if (newAccess != null && newAccess.isNotEmpty) {
          await _ref.read(sessionProvider.notifier).updateTokens(
                accessToken: newAccess,
                refreshToken: newRefresh,
              );
          return true;
        }
      }
      return false;
    } catch (_) {
      // Network unavailable or timeout: do NOT clear session so offline mode continues working
      return false;
    }
  }

  dynamic _handleResponse(http.Response res) {
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      json = {'message': res.body};
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json;
    }

    final message = json is Map
        ? (json['message'] ?? json['error'] ?? 'API error (${res.statusCode})')
        : 'API error (${res.statusCode})';
    final code = json is Map ? json['code']?.toString() : null;

    throw ApiException(
      statusCode: res.statusCode,
      message: message.toString(),
      code: code,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref);
});
