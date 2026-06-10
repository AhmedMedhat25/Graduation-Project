import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'https://emotion-detection.runasp.net/api';

  static const String _tokenKey = 'auth_token';
  static const Duration _timeout = Duration(seconds: 45);
  static const Duration _multipartTimeout = Duration(seconds: 90);

  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  // =========================
  // TOKEN MANAGEMENT
  // =========================

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

  // =========================
  // HEADERS
  // =========================

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await getToken();

    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  // =========================
  // RESPONSE HANDLER
  // =========================

  ApiResponse _handle(http.Response response, Uri uri) {
    debugPrint('📥 [${response.statusCode}] $uri');
    debugPrint('📥 BODY: ${response.body}');

    if (response.statusCode == 401) {
      clearToken();
      throw SessionExpiredException();
    }

    dynamic body;

    try {
      body = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : null;
    } catch (_) {
      body = response.body;
    }

    return ApiResponse(
      statusCode: response.statusCode,
      body: body,
      isSuccess: response.statusCode >= 200 &&
          response.statusCode < 300,
    );
  }

  // =========================
  // GET
  // =========================

  Future<ApiResponse> get(
      String path, {
        Map<String, String>? queryParams,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$path')
          .replace(queryParameters: queryParams);

      debugPrint('🚀 GET: $uri');

      final response = await http
          .get(uri, headers: await _headers())
          .timeout(_timeout);

      return _handle(response, uri);
    } catch (e) {
      debugPrint('❌ GET ERROR: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // =========================
  // POST
  // =========================

  Future<ApiResponse> post(
      String path, {
        Map<String, dynamic>? body,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      debugPrint('🚀 POST: $uri');
      debugPrint('📤 BODY: $body');

      var response = await http
          .post(
        uri,
        headers: await _headers(),
        body: body != null ? jsonEncode(body) : null,
      )
          .timeout(_timeout);

      if (response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          debugPrint('🔄 Following POST Redirect: $location');
          final redirectUri = Uri.parse(location);
          response = await http
              .post(
            redirectUri,
            headers: await _headers(),
            body: body != null ? jsonEncode(body) : null,
          )
              .timeout(_timeout);
        }
      }

      return _handle(response, uri);
    } catch (e) {
      debugPrint('❌ POST ERROR: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // =========================
  // PUT
  // =========================

  Future<ApiResponse> put(
      String path, {
        Map<String, dynamic>? body,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      debugPrint('🚀 PUT: $uri');
      debugPrint('📤 BODY: $body');

      final response = await http
          .put(
        uri,
        headers: await _headers(),
        body: body != null ? jsonEncode(body) : null,
      )
          .timeout(_timeout);

      return _handle(response, uri);
    } catch (e) {
      debugPrint('❌ PUT ERROR: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // =========================
  // PATCH
  // =========================

  Future<ApiResponse> patch(
      String path, {
        Map<String, dynamic>? body,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      debugPrint('🚀 PATCH: $uri');
      debugPrint('📤 BODY: $body');

      final response = await http
          .patch(
        uri,
        headers: await _headers(),
        body: body != null ? jsonEncode(body) : null,
      )
          .timeout(_timeout);

      return _handle(response, uri);
    } catch (e) {
      debugPrint('❌ PATCH ERROR: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // =========================
  // DELETE
  // =========================

  Future<ApiResponse> delete(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      debugPrint('🚀 DELETE: $uri');

      final response = await http
          .delete(uri, headers: await _headers())
          .timeout(_timeout);

      return _handle(response, uri);
    } catch (e) {
      debugPrint('❌ DELETE ERROR: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // =========================
  // RAW POST (external APIs)
  // =========================

  Future<ApiResponse> postRaw(
      String url, {
        Map<String, dynamic>? body,
      }) async {
    try {
      final uri = Uri.parse(url);

      debugPrint('🚀 POST RAW: $uri');
      debugPrint('📤 BODY: $body');

      var response = await http
          .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body != null ? jsonEncode(body) : null,
      )
          .timeout(_timeout);

      if (response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          debugPrint('🔄 Following POST RAW Redirect: $location');
          final redirectUri = Uri.parse(location);
          response = await http
              .post(
            redirectUri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body != null ? jsonEncode(body) : null,
          )
              .timeout(_timeout);
        }
      }

      return _handle(response, uri);
    } catch (e) {
      debugPrint('❌ POST RAW ERROR: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // =========================
  // MULTIPART
  // =========================

  Future<ApiResponse> postMultipart(
      String path, {
        required File file,
        required String fileField,
        Map<String, String>? fields,
        Duration? timeout,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      debugPrint('🚀 MULTIPART: $uri');

      final request = http.MultipartRequest('POST', uri);

      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.headers['Accept'] = 'application/json';

      request.files.add(
        await http.MultipartFile.fromPath(fileField, file.path),
      );

      if (fields != null) {
        request.fields.addAll(fields);
      }

      var streamed = await request
          .send()
          .timeout(timeout ?? _multipartTimeout);

      var response = await http.Response.fromStream(streamed);

      if (response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          debugPrint('🔄 Following MULTIPART Redirect: $location');
          final redirectUri = Uri.parse(location);
          final redirectRequest = http.MultipartRequest('POST', redirectUri);
          if (token != null && token.isNotEmpty) {
            redirectRequest.headers['Authorization'] = 'Bearer $token';
          }
          redirectRequest.headers['Accept'] = 'application/json';
          redirectRequest.files.add(
            await http.MultipartFile.fromPath(fileField, file.path),
          );
          if (fields != null) {
            redirectRequest.fields.addAll(fields);
          }
          streamed = await redirectRequest
              .send()
              .timeout(timeout ?? _multipartTimeout);
          response = await http.Response.fromStream(streamed);
        }
      }

      return _handle(response, uri);
    } catch (e) {
      debugPrint('❌ MULTIPART ERROR: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // =========================
  // RAW MULTIPART
  // =========================

  Future<ApiResponse> postRawMultipart(
      String url, {
        required File file,
        required String fileField,
        Map<String, String>? fields,
      }) async {
    try {
      final uri = Uri.parse(url);

      debugPrint('🚀 RAW MULTIPART: $uri');

      final request = http.MultipartRequest('POST', uri);

      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.headers['Accept'] = 'application/json';

      MediaType? mediaType;

      final path = file.path.toLowerCase();

      // Audio
      if (path.endsWith('.wav')) {
        mediaType = MediaType('audio', 'wav');
      } else if (path.endsWith('.m4a')) {
        mediaType = MediaType('audio', 'mp4');
      } else if (path.endsWith('.mp3')) {
        mediaType = MediaType('audio', 'mpeg');
      } else if (path.endsWith('.aac')) {
        mediaType = MediaType('audio', 'aac');
      } else if (path.endsWith('.ogg')) {
        mediaType = MediaType('audio', 'ogg');
      }
      // Image
      else if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
        mediaType = MediaType('image', 'jpeg');
      } else if (path.endsWith('.png')) {
        mediaType = MediaType('image', 'png');
      } else if (path.endsWith('.webp')) {
        mediaType = MediaType('image', 'webp');
      } else if (path.endsWith('.gif')) {
        mediaType = MediaType('image', 'gif');
      } else if (path.endsWith('.bmp')) {
        mediaType = MediaType('image', 'bmp');
      }
      // Video
      else if (path.endsWith('.mp4')) {
        mediaType = MediaType('video', 'mp4');
      } else if (path.endsWith('.mov')) {
        mediaType = MediaType('video', 'quicktime');
      } else if (path.endsWith('.avi')) {
        mediaType = MediaType('video', 'x-msvideo');
      } else if (path.endsWith('.mkv')) {
        mediaType = MediaType('video', 'x-matroska');
      } else if (path.endsWith('.webm')) {
        mediaType = MediaType('video', 'webm');
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          file.path,
          contentType: mediaType,
        ),
      );

      if (fields != null) {
        request.fields.addAll(fields);
      }

      var streamed = await request.send().timeout(_multipartTimeout);

      var response = await http.Response.fromStream(streamed);

      if (response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          debugPrint('🔄 Following RAW MULTIPART Redirect: $location');
          final redirectUri = Uri.parse(location);
          final redirectRequest = http.MultipartRequest('POST', redirectUri);
          if (token != null && token.isNotEmpty) {
            redirectRequest.headers['Authorization'] = 'Bearer $token';
          }
          redirectRequest.headers['Accept'] = 'application/json';
          redirectRequest.files.add(
            await http.MultipartFile.fromPath(
              fileField,
              file.path,
              contentType: mediaType,
            ),
          );
          if (fields != null) {
            redirectRequest.fields.addAll(fields);
          }
          streamed = await redirectRequest.send().timeout(_multipartTimeout);
          response = await http.Response.fromStream(streamed);
        }
      }

      return _handle(response, uri);
    } catch (e) {
      debugPrint('❌ RAW MULTIPART ERROR: $e');
      return ApiResponse.error(e.toString());
    }
  }
}

// =========================
// RESPONSE MODEL
// =========================

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
      return List<String>.from(body['errors']);
    }
    return [];
  }

  String get message {
    if (body is Map) {
      return (body['detail'] ??
          body['message'] ??
          body['title'] ??
          body['error'] ??
          'Request failed ($statusCode)')
          .toString();
    }
    if (body is String && (body as String).isNotEmpty) return body as String;
    return 'Request failed ($statusCode)';
  }
}

// =========================
// EXCEPTION
// =========================

class SessionExpiredException implements Exception {
  @override
  String toString() => 'Session expired. Please log in again.';
}