import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// ============================================================
//  🌐  API CLIENT — Centralised HTTP wrapper
// ============================================================
/// Single source of truth for every network call in the app.
///
/// • Injects `Authorization: Bearer …` when a token exists.
/// • Returns structured [ApiResponse] with parsed body.
/// • On 401, clears token and fires [onSessionExpired] so the
///   UI can navigate to login.
class ApiClient {
  static const String baseUrl = 'https://emotion-detection.runasp.net/api';
  static const String _tokenKey = 'auth_token';
  static const Duration _timeout = Duration(seconds: 30);

  // ── Singleton ────────────────────────────────────────────
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  // ── Token helpers ────────────────────────────────────────
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Clear the stored token (used on logout or 401).
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await _getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Response handler ─────────────────────────────────────
  ApiResponse _handle(http.Response response) {
    if (response.statusCode == 401) {
      // Don't clear the token here — background calls (history, alerts)
      // catch SessionExpiredException silently and fall back to local.
      // Clearing the token here would strip it before active operations
      // (like analysis) get a chance to use it.
      // The token is overwritten on re-login via AuthService.login().
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

  // ── GET ──────────────────────────────────────────────────
  Future<ApiResponse> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    debugPrint('🌐 GET $uri');
    final response = await http.get(uri, headers: await _headers()).timeout(_timeout);
    return _handle(response);
  }

  // ── POST (JSON) ──────────────────────────────────────────
  Future<ApiResponse> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    debugPrint('🌐 POST $uri  body=${body != null ? jsonEncode(body) : "null"}');
    final response = await http.post(
      uri,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_timeout);
    return _handle(response);
  }

  // ── POST (Multipart) ────────────────────────────────────
  Future<ApiResponse> postMultipart(
    String path, {
    required File file,
    required String fileField,
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    debugPrint('🌐 POST (multipart) $uri');
    final request = http.MultipartRequest('POST', uri);

    // Auth header
    final token = await _getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // File
    request.files.add(await http.MultipartFile.fromPath(fileField, file.path));

    // Extra fields
    if (fields != null) {
      request.fields.addAll(fields);
    }

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  // ── PUT ──────────────────────────────────────────────────
  Future<ApiResponse> put(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    debugPrint('🌐 PUT $uri');
    final response = await http.put(
      uri,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_timeout);
    return _handle(response);
  }

  // ── PATCH ────────────────────────────────────────────────
  Future<ApiResponse> patch(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    debugPrint('🌐 PATCH $uri');
    final response = await http.patch(
      uri,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_timeout);
    return _handle(response);
  }

  // ── DELETE ───────────────────────────────────────────────
  Future<ApiResponse> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    debugPrint('🌐 DELETE $uri');
    final response = await http.delete(uri, headers: await _headers()).timeout(_timeout);
    return _handle(response);
  }
}

// ── Response model ──────────────────────────────────────────
class ApiResponse {
  final int statusCode;
  final dynamic body;
  final bool isSuccess;

  const ApiResponse({
    required this.statusCode,
    required this.body,
    required this.isSuccess,
  });

  /// Convenience: extract a message from common response shapes.
  String get message {
    if (body is Map) {
      return (body['message'] ?? body['title'] ?? 'Request failed ($statusCode)').toString();
    }
    if (body is String && (body as String).isNotEmpty) {
      return body as String;
    }
    return 'Request failed ($statusCode)';
  }
}

// ── Session expiry exception ────────────────────────────────
class SessionExpiredException implements Exception {
  @override
  String toString() => 'Session expired. Please log in again.';
}
