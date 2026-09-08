import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'session.dart';

class ApiClient {
  ApiClient(this._ref);

  final Ref _ref;

  static const String baseUrl = 'http://192.168.1.3:4000/api';

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
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(
        const Duration(seconds: 15),
      );
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Cannot connect to the server.',
        code: 'CONNECTION_ERROR',
      );
    } on HttpException {
      throw ApiException(
        statusCode: 0,
        message: 'Network error. Please check your connection.',
        code: 'NETWORK_ERROR',
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        message: 'Server connection timed out.',
        code: 'TIMEOUT',
      );
    } on FormatException {
      throw ApiException(
        statusCode: 0,
        message: 'Invalid server response.',
        code: 'INVALID_RESPONSE',
      );
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

  Future<dynamic> post(
    String path, {
    Object? body,
  }) async {
    final response = await _request(
      () => http.post(
        _uri(path),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ),
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

  Future<dynamic> delete(String path) async {
    final response = await _request(
      () => http.delete(
        _uri(path),
        headers: _headers,
      ),
    );

    return _decode(response);
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref),
);

