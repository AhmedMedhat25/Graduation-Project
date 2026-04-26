import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/emotion_result.dart';
import 'api_client.dart';

// ============================================================
//  🔑  AUTH SERVICE
// ============================================================
class AuthService {
  static const String _baseUrl = ApiClient.baseUrl;

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // ── Login ────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server (${response.statusCode})'};
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // Handle both unwrapped and wrapped (data: {...}) responses
        final payload = data['data'] is Map<String, dynamic>
            ? data['data'] as Map<String, dynamic>
            : data;

        // Token may be at payload['token'] or payload['accessToken']
        final token = payload['token'] as String? ?? payload['accessToken'] as String?;
        if (token != null) await _saveToken(token);

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
               final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
               user['firstName'] ??= payload['firstName'] ?? payload['GivenName'] ?? payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname'];
               user['lastName'] ??= payload['lastName'] ?? payload['Surname'] ?? payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname'];
               user['name'] ??= payload['name'] ?? payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'];
            }
          } catch (e) {
            debugPrint('Error parsing JWT for user name: $e');
          }
        }

        await _saveUser(user);

        return {'success': true, 'user': user};
      } else {
        final message = data['message'] as String? ??
            data['title'] as String? ??
            'Login failed (${response.statusCode})';
        return {'success': false, 'message': message};
      }
    } on http.ClientException catch (e) {
      return {'success': false, 'message': 'Network error: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  // ── Register ─────────────────────────────────────────────
  Future<Map<String, dynamic>> register(
      String firstName, String lastName, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'password': password,
        }),
      );

      if (response.body.isEmpty) {
        if (response.statusCode == 200 || response.statusCode == 201) {
           // Success but empty body — email confirmation link was sent
           return {
             'success': true,
             'email': email,
             'needsEmailConfirmation': true,
             'message': 'Please check your email to confirm your account.',
           };
        }
        return {'success': false, 'message': 'Server returned an empty response (${response.statusCode})'};
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final message = data['message'] as String?;

        // NEVER save token on registration — user must verify email first,
        // then log in separately. This ensures no access without verification.
        return {
          'success': true,
          'email': email,
          'needsEmailConfirmation': true,
          'message': message ?? 'Please check your email to confirm your account.',
        };
      } else {
        String? validationMessage;
        if (data['errors'] != null && data['errors'] is Map) {
          final Map<String, dynamic> errors = data['errors'];
          if (errors.isNotEmpty) {
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              validationMessage = firstError.first.toString();
            }
          }
        }

        final message = validationMessage ??
            data['message'] as String? ??
            data['title'] as String? ??
            'Registration failed (${response.statusCode})';
        return {'success': false, 'message': message};
      }
    } on http.ClientException catch (e) {
      return {'success': false, 'message': 'Network error: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }


  // ── Forgot Password ─────────────────────────────────────
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Reset link sent to your email.'};
      } else {
        String message = 'Failed to send reset code (${response.statusCode})';
        if (response.body.isNotEmpty) {
          try {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            message = data['message'] as String? ?? data['title'] as String? ?? message;
          } catch (_) {}
        }
        return {'success': false, 'message': message};
      }
    } on http.ClientException catch (e) {
      return {'success': false, 'message': 'Network error: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  // ── Reset Password ──────────────────────────────────────
  Future<Map<String, dynamic>> resetPassword(
      String email, String token, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'token': token,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Password reset successfully.'};
      } else {
        String message = 'Reset failed (${response.statusCode})';
        if (response.body.isNotEmpty) {
          try {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            message = data['message'] as String? ?? data['title'] as String? ?? message;
          } catch (_) {}
        }
        return {'success': false, 'message': message};
      }
    } on http.ClientException catch (e) {
      return {'success': false, 'message': 'Network error: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  // ── Change Password ─────────────────────────────────────
  Future<Map<String, dynamic>> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final api = ApiClient();
      final response = await api.put('/user/change-password', body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });

      if (response.isSuccess) {
        return {'success': true, 'message': 'Password changed successfully.'};
      } else {
        return {'success': false, 'message': response.message};
      }
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
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
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_tokenKey);
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    Map<String, dynamic>? userJson;

    if (userData != null) {
      userJson = jsonDecode(userData) as Map<String, dynamic>;
    }

    // Always try to enrich with JWT claims (authoritative source for name)
    final token = prefs.getString(_tokenKey);
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
      final name = payload['name'] ??
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

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }
}
