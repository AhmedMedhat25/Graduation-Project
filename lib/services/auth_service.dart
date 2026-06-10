import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/emotion_result.dart';
import 'api_client.dart';

// ============================================================
//  🔑  AUTH SERVICE
// ============================================================
class AuthService {
  final _api = ApiClient();
  static const String _userKey = 'user_data';

  // ── Login ────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _api.post('/auth/login', body: {
        'email': email,
        'password': password,
      });

      if (!response.isSuccess) {
        return {'success': false, 'message': response.message};
      }

      final data = response.body as Map<String, dynamic>;
      // Handle both unwrapped and wrapped (data: {...}) responses
      final payload = data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : data;

      // Token may be at payload['token'] or payload['accessToken']
      final token = payload['token'] as String? ?? payload['accessToken'] as String?;
      if (token != null) await _api.saveToken(token);

      final user = payload['user'] as Map<String, dynamic>? ?? {};
      // Merge user-relevant fields from the payload
      for (final key in payload.keys) {
        if (key != 'token' && key != 'accessToken') {
          user[key] ??= payload[key];
        }
      }
      user['email'] ??= email; // guarantee email exists

      // Extract account name from JWT if missing
      if (token != null) {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payloadStr = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
            final jwtPayload = jsonDecode(payloadStr) as Map<String, dynamic>;
            user['firstName'] ??= jwtPayload['firstName'] ??
                jwtPayload['GivenName'] ??
                jwtPayload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname'];
            user['lastName'] ??= jwtPayload['lastName'] ??
                jwtPayload['Surname'] ??
                jwtPayload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname'];
            user['name'] ??= jwtPayload['name'] ??
                jwtPayload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'];
          }
        } catch (e) {
          debugPrint('Error parsing JWT for user name: $e');
        }
      }

      await _saveUser(user);
      return {'success': true, 'user': user};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  // ── Register ─────────────────────────────────────────────
  Future<Map<String, dynamic>> register(
      String firstName, String lastName, String email, String password) async {
    try {
      final response = await _api.post('/auth/register', body: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
      });

      if (response.isSuccess) {
        return {
          'success': true,
          'email': email,
          'needsEmailConfirmation': true,
          'message': response.message.contains('Success') 
              ? 'Please check your email to confirm your account.'
              : response.message,
        };
      } else {
        final data = response.body;
        String? validationMessage;
        if (data is Map && data['errors'] != null && data['errors'] is Map) {
          final Map<String, dynamic> errors = data['errors'];
          if (errors.isNotEmpty) {
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              validationMessage = firstError.first.toString();
            }
          }
        }
        return {'success': false, 'message': validationMessage ?? response.message};
      }
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }


  // ── Forgot Password ─────────────────────────────────────
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _api.post('/auth/forgot-password', body: {'email': email});
      if (response.isSuccess) {
        return {'success': true, 'message': 'Reset link sent to your email.'};
      } else {
        return {'success': false, 'message': response.message};
      }
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  // ── Reset Password ──────────────────────────────────────
  Future<Map<String, dynamic>> resetPassword(
      String email, String token, String newPassword) async {
    try {
      final response = await _api.post('/auth/reset-password', body: {
        'email': email,
        'token': token,
        'new_password': newPassword,
      });

      if (response.isSuccess) {
        return {'success': true, 'message': 'Password reset successfully.'};
      } else {
        return {'success': false, 'message': response.message};
      }
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  // ── Change Password ─────────────────────────────────────
  Future<Map<String, dynamic>> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final response = await _api.put('/user/change-password', body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });

      return {
        'success': response.isSuccess,
        'message': response.message,
      };
    } on SessionExpiredException {
      return {'success': false, 'message': 'Session expired. Please log in again.'};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  // ── Get Profile from Cloud (via JWT refresh) ────────────
  // The API has no /user/profile endpoint, so we extract
  // user info from the stored JWT token claims instead.
  Future<Map<String, dynamic>> getCloudProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not logged in.'};
      }
      final user = _extractUserFromJwt(token);
      if (user != null) {
        await _saveUser(user);
        return {'success': true, 'user': user};
      }
      return {'success': false, 'message': 'Could not read profile from token.'};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  // ── Logout ───────────────────────────────────────────────
  Future<void> logout() async {
    await _api.clearToken();
  }

  // ── Edit Profile (local + best-effort cloud) ────────────
  Future<bool> saveProfile(String name, String avatarColorHex, String email) async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      final user = jsonDecode(userData) as Map<String, dynamic>;
      user['name'] = name;
      user['avatar_url'] = avatarColorHex;
      user['email'] = email;

      // Clear split name fields to ensure the new unified 'name' is used
      user.remove('firstName');
      user.remove('lastName');

      await _saveUser(user);
      return true;
    }
    return false;
  }

  // ── Delete Account ──────────────────────────────────────
  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final api = ApiClient();
      final response = await api.delete('/user/account');
      if (response.isSuccess) {
        await logout();
        return {'success': true, 'message': 'Account deleted.'};
      }
      return {'success': false, 'message': response.message};
    } on SessionExpiredException {
      return {'success': false, 'message': 'Session expired. Please log in again.'};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  // ── Helpers ──────────────────────────────────────────────
  Future<bool> isLoggedIn() async {
    final token = await _api.getToken();
    return token != null;
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    Map<String, dynamic>? userJson;

    if (userData != null) {
      userJson = jsonDecode(userData) as Map<String, dynamic>;
    }

    // Always try to enrich with JWT claims (authoritative source for name)
    final token = await _api.getToken();
    if (token != null) {
      final jwtUser = _extractUserFromJwt(token);
      if (jwtUser != null) {
        if (userJson == null) {
          userJson = jwtUser;
        } else {
          // JWT claims are authoritative — override stale/empty cached fields
          for (final key in jwtUser.keys) {
            if (jwtUser[key] != null &&
                (userJson[key] == null ||
                    userJson[key].toString().isEmpty ||
                    userJson[key] == 'Unknown')) {
              userJson[key] = jwtUser[key];
            }
          }
        }
        // Persist enriched data
        await prefs.setString(_userKey, jsonEncode(userJson));
      }
    }

    if (userJson != null) {
      return UserModel.fromJson(userJson);
    }
    return null;
  }

  /// Decode the JWT and extract user fields from claims.
  Map<String, dynamic>? _extractUserFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payloadStr =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;

      final firstName = payload['firstName'] ??
          payload['GivenName'] ??
          payload['given_name'] ??
          payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname'];
      final lastName = payload['lastName'] ??
          payload['Surname'] ??
          payload['family_name'] ??
          payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname'];
      final name = payload['fullName'] ?? 
          payload['full_name'] ??
          payload['name'] ??
          payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'];
      final email = payload['email'] ??
          payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'] ??
          payload['sub'];

      return {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (name != null) 'name': name,
        if (email != null) 'email': email,
      };
    } catch (e) {
      debugPrint('JWT decode error: $e');
      return null;
    }
  }

  Future<String?> getToken() => _api.getToken();

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }
}
