import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  // Set token (synchronous)
  void setToken(String? value) {
    _token = value;
    if (value != null) {
      _saveToken(value);
    }
  }

  // Get token (async)
  Future<String?> getToken() async {
    if (_token != null) return _token;

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(Constants.tokenKey);
    return _token;
  }

  // Save token to storage
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.tokenKey, token);
  }

  // Clear token
  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Constants.tokenKey);
  }

  // Helper for headers
  Future<Map<String, String>> _getHeaders() async {
    final tokenValue = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (tokenValue != null) 'Authorization': 'Bearer $tokenValue',
    };
  }

  // GET request
  Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('${Constants.baseUrl}$endpoint');
    final headers = await _getHeaders();
    print('📡 GET: $url');
    return await http.get(url, headers: headers);
  }

  // POST request
  Future<http.Response> post(String endpoint, dynamic data) async {
    final url = Uri.parse('${Constants.baseUrl}$endpoint');
    final headers = await _getHeaders();
    print('📡 POST: $url');
    return await http.post(url, headers: headers, body: json.encode(data));
  }

  // PUT request
  Future<http.Response> put(String endpoint, dynamic data) async {
    final url = Uri.parse('${Constants.baseUrl}$endpoint');
    final headers = await _getHeaders();
    print('📡 PUT: $url');
    return await http.put(url, headers: headers, body: json.encode(data));
  }

  // ✅ PATCH request - This fixes your Admin Dashboard errors
  Future<http.Response> patch(String endpoint, dynamic data) async {
    final url = Uri.parse('${Constants.baseUrl}$endpoint');
    final headers = await _getHeaders();
    print('📡 PATCH: $url');
    return await http.patch(url, headers: headers, body: json.encode(data));
  }

  // DELETE request
  Future<http.Response> delete(String endpoint) async {
    final url = Uri.parse('${Constants.baseUrl}$endpoint');
    final headers = await _getHeaders();
    print('📡 DELETE: $url');
    return await http.delete(url, headers: headers);
  }
}
