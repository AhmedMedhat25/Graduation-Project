import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'https://emotion-detection.runasp.net/api';

  static const String _tokenKey = 'auth_token';
  static const Duration _timeout = Duration(seconds: 45);
  static const Duration _multipartTimeout = Duration(seconds: 90);

  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove('user_data');
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await getToken();

    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  ApiResponse _handle(http.Response response, Uri uri) {
    debugPrint('📥 [API] ${response.statusCode} -> $uri');
    debugPrint('📥 [API] Body: ${response.body}');

    if (response.statusCode == 401) {
      clearToken();
      throw SessionExpiredException();
    }

    dynamic body;
    try {
      body = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (_) {
      body = response.body;
    }

    return ApiResponse(
      statusCode: response.statusCode,
      body: body,
      isSuccess: response.statusCode >= 200 && response.statusCode < 300,
    );
  }

  Future<ApiResponse> get(
      String path, {
        Map<String, String>? queryParams,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
      debugPrint('🚀 GET: $uri');

      final response =
      await http.get(uri, headers: await _headers()).timeout(_timeout);

      return _handle(response, uri);
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('❌ API Error (GET): $e');
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse> post(
      String path, {
        Map<String, dynamic>? body,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      debugPrint('🚀 POST: $uri');
      if (body != null) {
        debugPrint('📤 POST Body: ${jsonEncode(body)}');
      }

      final response = await http
          .post(
        uri,
        headers: await _headers(),
        body: body != null ? jsonEncode(body) : null,
      )
          .timeout(_timeout);

      return _handle(response, uri);
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('❌ API Error (POST): $e');
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse> postMultipart(
      String path, {
        required File file,
        required String fileField,
        Map<String, String>? fields,
        Duration? timeout,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      debugPrint('🚀 MULTIPART POST: $uri');
      debugPrint('📤 File: ${file.path}');
      debugPrint('📤 File field: $fileField');
      if (fields != null) {
        debugPrint('📤 Fields: $fields');
      }

      final request = http.MultipartRequest('POST', uri);

      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      request.files.add(
        await http.MultipartFile.fromPath(fileField, file.path),
      );

      if (fields != null && fields.isNotEmpty) {
        request.fields.addAll(fields);
      }

      final streamed = await request
          .send()
          .timeout(timeout ?? _multipartTimeout);

      final response = await http.Response.fromStream(streamed);
      return _handle(response, uri);
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('❌ API Error (MULTIPART): $e');
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse> put(
      String path, {
        Map<String, dynamic>? body,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      debugPrint('🚀 PUT: $uri');
      if (body != null) {
        debugPrint('📤 PUT Body: ${jsonEncode(body)}');
      }

      final response = await http
          .put(
        uri,
        headers: await _headers(),
        body: body != null ? jsonEncode(body) : null,
      )
          .timeout(_timeout);

      return _handle(response, uri);
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('❌ API Error (PUT): $e');
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse> delete(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      debugPrint('🚀 DELETE: $uri');

      final response =
      await http.delete(uri, headers: await _headers()).timeout(_timeout);

      return _handle(response, uri);
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('❌ API Error (DELETE): $e');
      return ApiResponse.error(e.toString());
    }
  }
}

class ApiResponse {
  final int statusCode;
  final dynamic body;
  final bool isSuccess;

  const ApiResponse({
    required this.statusCode,
    required this.body,
    required this.isSuccess,
  });

  factory ApiResponse.error(String message) {
    return ApiResponse(
      statusCode: 0,
      body: {'message': message},
      isSuccess: false,
    );
  }

  dynamic get data => body is Map ? body['data'] : null;

  List<String> get errors {
    if (body is Map && body['errors'] is List) {
      return (body['errors'] as List).map((e) => e.toString()).toList();
    }

    if (body is Map && body['errors'] is Map) {
      final map = body['errors'] as Map;
      final list = <String>[];
      for (final value in map.values) {
        if (value is List) {
          list.addAll(value.map((e) => e.toString()));
        } else {
          list.add(value.toString());
        }
      }
      return list;
    }

    return [];
  }

  String get message {
    final errs = errors;
    if (errs.isNotEmpty) return errs.first;

    if (body is Map) {
      return (body['message'] ?? body['title'] ?? 'Request failed ($statusCode)')
          .toString();
    }

    if (body is String && (body as String).isNotEmpty) {
      return body as String;
    }

    return 'Request failed ($statusCode)';
  }
}

class SessionExpiredException implements Exception {
  @override
  String toString() => 'Session expired. Please log in again.';
}