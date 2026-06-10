import 'package:flutter/foundation.dart';

import '../models/quota_status.dart';
import 'api_client.dart';

/// Service for checking the user's weekly analysis quota.
///
/// Uses `GET /api/analysis/quota` and caches the latest result
/// so multiple widgets can read it without duplicate requests.
class QuotaService {
  static final QuotaService _instance = QuotaService._();
  factory QuotaService() => _instance;
  QuotaService._();

  final ApiClient _api = ApiClient();

  /// Latest cached quota snapshot (may be null on first launch / offline).
  QuotaStatus? _cached;
  QuotaStatus? get cached => _cached;

  // ─── Fetch ─────────────────────────────────────────────────

  /// Fetches the current weekly quota from the backend.
  /// Returns `null` when the user is not logged in or the request fails,
  /// allowing a *fail-open* policy (the backend will reject over-limit
  /// requests anyway with 400/403).
  Future<QuotaStatus?> getQuota() async {
    try {
      final response = await _api.get('/analysis/quota');

      if (!response.isSuccess || response.body == null) {
        debugPrint('⚠️ Quota fetch failed: ${response.message}');
        return _cached; // return stale cache if available
      }

      final body = response.body;
      if (body is! Map) {
        debugPrint('⚠️ Quota response body is not a Map: $body');
        return _cached;
      }

      final bodyMap = Map<String, dynamic>.from(body);
      final dataVal = bodyMap['data'];
      final data = dataVal is Map ? Map<String, dynamic>.from(dataVal) : bodyMap;

      _cached = QuotaStatus.fromJson(data);
      debugPrint('📊 Quota loaded: '
          'text=${_cached!.text.used}/${_cached!.text.limit}, '
          'audio=${_cached!.audio.used}/${_cached!.audio.limit}, '
          'image=${_cached!.image.used}/${_cached!.image.limit}, '
          'video=${_cached!.video.used}/${_cached!.video.limit}');

      return _cached;
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('⚠️ Quota fetch error: $e');
      return _cached;
    }
  }

  // ─── Convenience ───────────────────────────────────────────

  /// Quick check: is the given analysis type currently blocked?
  /// Returns `true` → blocked, `false` → allowed, `null` → unknown.
  Future<bool?> isBlocked(String type) async {
    final quota = await getQuota();
    if (quota == null) return null;
    return quota.forType(type).isBlocked;
  }

  /// Clear the local cache (e.g. on logout).
  void clearCache() => _cached = null;
}
