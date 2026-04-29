import 'dart:convert';

import 'api_service.dart';

class MlService {
  MlService({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Map<String, dynamic>? _decodeMap(String body) {
    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    return null;
  }

  List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => item.map(
            (key, val) => MapEntry(key.toString(), val),
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>?> fetchDashboard() async {
    final response = await _apiService.get('/ml/dashboard');
    if (response.statusCode != 200) return null;
    final body = _decodeMap(response.body);
    if (body == null) return null;
    return _asMap(body['dashboard']);
  }

  Future<List<Map<String, dynamic>>> fetchRecommendations({
    String role = 'tourist',
    Map<String, dynamic>? preferences,
  }) async {
    final response = await _apiService.post('/ml/recommend', {
      'role': role,
      'preferences': preferences ?? <String, dynamic>{},
    });

    if (response.statusCode != 200) return const [];
    final body = _decodeMap(response.body);
    if (body == null) return const [];
    final recommendations = _asMap(body['recommendations']);
    return _asListOfMaps(recommendations?['activities']);
  }

  Future<List<Map<String, dynamic>>> fetchHotspots() async {
    final response = await _apiService.get('/ml/hotspots');
    if (response.statusCode != 200) return const [];
    final body = _decodeMap(response.body);
    if (body == null) return const [];
    return _asListOfMaps(body['data']);
  }

  Future<List<Map<String, dynamic>>> fetchForecast() async {
    final response = await _apiService.get('/ml/forecast');
    if (response.statusCode != 200) return const [];
    final body = _decodeMap(response.body);
    if (body == null) return const [];
    return _asListOfMaps(body['forecast']);
  }
}
