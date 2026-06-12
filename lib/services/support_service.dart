import 'package:flutter/foundation.dart';

import '../models/support_message.dart';
import 'api_client.dart';

class SupportService {
  static final SupportService _instance = SupportService._();
  factory SupportService() => _instance;
  SupportService._();

  final ApiClient _api = ApiClient();

  /// Submits a support message to POST /api/support/contact
  Future<SupportMessage> submitMessage(String subject, String message) async {
    try {
      final response = await _api.post(
        '/support/contact',
        body: {
          'subject': subject,
          'message': message,
        },
      );

      if (!response.isSuccess || response.body == null) {
        throw Exception(response.message);
      }

      final body = response.body;
      final data = body is Map ? body['data'] : null;
      if (data is Map) {
        return SupportMessage.fromJson(Map<String, dynamic>.from(data));
      } else if (body is Map) {
        return SupportMessage.fromJson(Map<String, dynamic>.from(body));
      }
      throw Exception('Invalid response format');
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Support submit error: $e');
      rethrow;
    }
  }

  /// Gets support messages from GET /api/support/contact
  Future<List<SupportMessage>> getMessages({
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await _api.get(
        '/support/contact',
        queryParams: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        },
      );

      if (!response.isSuccess || response.body == null) {
        throw Exception(response.message);
      }

      final body = response.body;
      final data = body is Map ? body['data'] : null;
      List items = [];

      if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else if (body is Map && body['items'] is List) {
        items = body['items'] as List;
      } else if (data is List) {
        items = data;
      }

      return items
          .whereType<Map>()
          .map((j) => SupportMessage.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Support messages fetch error: $e');
      rethrow;
    }
  }
}
