import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../utils/constants.dart';

class AuthService {
  static String get baseUrl => Constants.baseUrl;

  Map<String, dynamic> _safeDecodeResponse(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'message': decoded.toString()};
    } catch (_) {
      return {
        'message': response.body.isNotEmpty
            ? response.body
            : 'Server returned an invalid response',
      };
    }
  }

  String _fallbackMessage(
    Map<String, dynamic> data,
    String defaultMessage,
    int statusCode,
  ) {
    final message = data['message'] ?? data['error'];
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString();
    }
    return '$defaultMessage${statusCode > 0 ? ' ($statusCode)' : ''}';
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = _safeDecodeResponse(response);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'token': data['token'],
          'user': User.fromJson(data['user']),
        };
      }

      return {
        'success': false,
        'message': _fallbackMessage(data, 'Login failed', response.statusCode),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> registerTourist({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
        }),
      );

      final data = _safeDecodeResponse(response);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'token': data['token'],
          'user': User.fromJson(data['user']),
        };
      }

      return {
        'success': false,
        'message': _fallbackMessage(
          data,
          'Registration failed',
          response.statusCode,
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> registerVendor({
    required String name,
    required String email,
    required String password,
    required String businessName,
    String? phone,
    String? businessPhone,
    String? businessAddress,
    String? businessType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register-vendor'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': name,
          'email': email,
          'password': password,
          'business_name': businessName,
          'business_phone': businessPhone ?? phone,
          'business_address': businessAddress,
          'business_type': businessType,
        }),
      );

      final data = _safeDecodeResponse(response);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'token': data['token'],
          'user': User.fromJson(data['user']),
        };
      }

      return {
        'success': false,
        'message': _fallbackMessage(
          data,
          'Registration failed',
          response.statusCode,
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      final data = _safeDecodeResponse(response);
      return {
        'success': data['success'] == true,
        'message': _fallbackMessage(
          data,
          'Unable to start password reset',
          response.statusCode,
        ),
        'resetToken': data['resetToken'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'token': token,
          'password': newPassword,
        }),
      );

      final data = _safeDecodeResponse(response);
      return {
        'success': data['success'] == true,
        'message': _fallbackMessage(
          data,
          'Unable to reset password',
          response.statusCode,
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(Constants.tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Constants.tokenKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Constants.tokenKey);
    await prefs.remove(Constants.userKey);
  }
}
