import 'dart:async';
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
      final saved = prefs.getString('desktop_custom_api_url');
      if (saved != null && saved.isNotEmpty) {
        _configuredUrl = saved;
      }
    } catch (_) {}
  }

  static Future<void> persistCustomUrl(String url) async {
    setCustomBaseUrl(url);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('desktop_custom_api_url', _configuredUrl);
    } catch (_) {}
  }

  ApiClient(this._ref);

  Map<String, String> _buildHeaders() {
    final session = _ref.read(sessionProvider);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (session.accessToken != null && session.accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    if (session.companyId != null && session.companyId!.isNotEmpty) {
      headers['X-Company-Id'] = session.companyId!;
    }

    return headers;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    return _sendRequest(() {
      final uri = _buildUri(path, queryParams);
      return http.get(uri, headers: _buildHeaders());
    });
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    return _sendRequest(() {
      final uri = _buildUri(path);
      return http.post(
        uri,
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }

  Future<dynamic> put(String path, {dynamic body}) async {
    return _sendRequest(() {
      final uri = _buildUri(path);
      return http.put(
        uri,
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }

  Future<dynamic> delete(String path) async {
    return _sendRequest(() {
      final uri = _buildUri(path);
      return http.delete(uri, headers: _buildHeaders());
    });
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final full = '$baseUrl$cleanPath';
    final uri = Uri.parse(full);
    if (queryParams != null && queryParams.isNotEmpty) {
      final stringParams = queryParams.map((k, v) => MapEntry(k, v.toString()));
      return uri.replace(queryParameters: stringParams);
    }
    return uri;
  }

  Future<dynamic> _sendRequest(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 30));
    } on http.ClientException catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Cannot reach backend server at $baseUrl: ${e.message}',
        code: 'CONNECTION_ERROR',
      );
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        message: 'Server request timed out after 30 seconds.',
        code: 'TIMEOUT',
      );
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error: $e',
        code: 'UNKNOWN_NETWORK_ERROR',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    }

    if (response.statusCode == 401) {
      // Token expired or invalid
      throw const ApiException(
        statusCode: 401,
        message: 'Authentication session expired. Please sign in again.',
        code: 'UNAUTHORIZED',
      );
    }

    String errorMsg = 'Server returned status code ${response.statusCode}';
    String? code;
    try {
      final errData = jsonDecode(response.body);
      if (errData is Map && errData['message'] != null) {
        errorMsg = errData['message'].toString();
      }
      if (errData is Map && errData['code'] != null) {
        code = errData['code'].toString();
      }
    } catch (_) {}

    throw ApiException(
      statusCode: response.statusCode,
      message: errorMsg,
      code: code,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref);
});
