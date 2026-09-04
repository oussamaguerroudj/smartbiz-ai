import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_exception.dart';
import 'session.dart';

/// Thin wrapper over package:http that:
///  - injects the Bearer token from [sessionProvider] on every request
///  - always sends/expects JSON
///  - throws [ApiException] with the backend's own {message, code} on
///    any non-2xx response, so callers can catch one exception type
///
/// BASE URL: this points at the backend from Phase 5. Android emulators
/// reach the host machine's localhost via 10.0.2.2 — that's the
/// default here. Change it if you're on:
///   - iOS Simulator: 'http://127.0.0.1:4000/api' (localhost works directly)
///   - a physical device: 'http://<your-computer's-LAN-IP>:4000/api'
///   - a deployed backend: its real https:// URL
class ApiClient {
  ApiClient(this._ref);

  final Ref _ref;

  static String get baseUrl => kIsWeb ? 'http://localhost:4000/api' : 'http://10.0.2.2:4000/api';

  Map<String, String> get _headers {
    final token = _ref.read(sessionProvider).accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  dynamic _decode(http.Response response) {
    final body = response.body.isEmpty ? {} : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: (body is Map && body['message'] != null)
          ? body['message'] as String
          : 'Request failed (${response.statusCode})',
      code: (body is Map) ? body['code'] as String? : null,
    );
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final response = await http.get(_uri(path, query), headers: _headers);
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final response =
        await http.post(_uri(path), headers: _headers, body: body != null ? jsonEncode(body) : null);
    return _decode(response);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final response =
        await http.put(_uri(path), headers: _headers, body: body != null ? jsonEncode(body) : null);
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(_uri(path), headers: _headers);
    return _decode(response);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref));
