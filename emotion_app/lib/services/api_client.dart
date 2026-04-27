import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// 🌐 API CLIENT — Centralised HTTP wrapper
// ============================================================

class ApiClient {
  static const String baseUrl = 'https://emotion-detection.runasp.net/api';
  static const String _tokenKey = 'auth_token';
  static const Duration _timeout = Duration(seconds: 30);

  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  // ================= TOKEN =================

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

  // ================= RESPONSE =================

  ApiResponse _handle(http.Response response) {
    debugPrint('📥 Response (${response.statusCode}): ${response.body}');

    if (response.statusCode == 401) {
      clearToken(); // 🔥 IMPORTANT FIX
      throw SessionExpiredException();
    }

    dynamic body;

    try {
      body = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (_) {
      body = response.body;
    }

    bool isSuccess = false;

    if (body is Map) {
      isSuccess =
          body['is_success'] == true ||
              body['isSuccess'] == true ||
              (response.statusCode >= 200 && response.statusCode < 300);
    } else {
      isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    }

    return ApiResponse(
      statusCode: response.statusCode,
      body: body,
      isSuccess: isSuccess,
    );
  }

  // ================= GET =================

  Future<ApiResponse> get(String path,
      {Map<String, String>? queryParams}) async {
    try {
      final uri =
      Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);

      debugPrint('🌐 GET $uri');

      final response = await http
          .get(uri, headers: await _headers())
          .timeout(_timeout);

      return _handle(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // ================= POST =================

  Future<ApiResponse> post(String path,
      {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      debugPrint('🌐 POST $uri');

      final response = await http
          .post(
        uri,
        headers: await _headers(),
        body: body != null ? jsonEncode(body) : null,
      )
          .timeout(_timeout);

      return _handle(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // ================= MULTIPART =================

  Future<ApiResponse> postMultipart(
      String path, {
        required File file,
        required String fileField,
        Map<String, String>? fields,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      debugPrint('🌐 POST MULTIPART $uri');

      final request = http.MultipartRequest('POST', uri);

      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await http.MultipartFile.fromPath(fileField, file.path));

      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamed =
      await request.send().timeout(const Duration(seconds: 60));

      final response = await http.Response.fromStream(streamed);

      return _handle(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // ================= PUT =================

  Future<ApiResponse> put(String path,
      {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      final response = await http
          .put(
        uri,
        headers: await _headers(),
        body: body != null ? jsonEncode(body) : null,
      )
          .timeout(_timeout);

      return _handle(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // ================= DELETE =================

  Future<ApiResponse> delete(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      final response = await http
          .delete(uri, headers: await _headers())
          .timeout(_timeout);

      return _handle(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
}

// ============================================================
// RESPONSE MODEL
// ============================================================

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
      statusCode: 500,
      body: {'message': message},
      isSuccess: false,
    );
  }

  List<String> get errors {
    if (body is Map && body['errors'] is List) {
      return (body['errors'] as List)
          .map((e) => e.toString())
          .toList();
    }
    return [];
  }

  String get message {
    final errs = errors;
    if (errs.isNotEmpty) return errs.first;

    if (body is Map) {
      return (body['message'] ??
          body['title'] ??
          'Request failed ($statusCode)')
          .toString();
    }

    if (body is String && body.isNotEmpty) {
      return body;
    }

    return 'Request failed ($statusCode)';
  }
}

// ============================================================
// SESSION EXCEPTION
// ============================================================

class SessionExpiredException implements Exception {
  @override
  String toString() => 'Session expired. Please log in again.';
}