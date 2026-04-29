import 'dart:convert';

import 'api_service.dart';

class AIService {
  AIService({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

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

  Future<Map<String, dynamic>?> getDashboard() async {
    final response = await _api.get('/ml/dashboard');
    if (response.statusCode != 200) return null;
    final body = _decodeMap(response.body);
    if (body == null) return null;
    return _asMap(body['dashboard']);
  }

  Future<List<Map<String, dynamic>>> getForecast() async {
    final response = await _api.get('/ml/forecast');
    if (response.statusCode != 200) return const [];
    final body = _decodeMap(response.body);
    if (body == null) return const [];
    return _asListOfMaps(body['forecast']);
  }

  Future<List<Map<String, dynamic>>> getHotspots() async {
    final response = await _api.get('/ml/hotspots');
    if (response.statusCode != 200) return const [];
    final body = _decodeMap(response.body);
    if (body == null) return const [];
    return _asListOfMaps(body['data']);
  }

  Future<List<Map<String, dynamic>>> getRecommendations({
    String role = 'tourist',
    Map<String, dynamic>? preferences,
  }) async {
    final response = await _api.post('/ml/recommend', {
      'role': role,
      'preferences': preferences ?? <String, dynamic>{},
    });

    if (response.statusCode != 200) return const [];
    final body = _decodeMap(response.body);
    if (body == null) return const [];
    final recommendations = _asMap(body['recommendations']);
    return _asListOfMaps(recommendations?['activities']);
  }

  Future<Map<String, dynamic>?> getLtdcOverview() async {
    final response = await _api.get('/ml/ltdc/overview');
    if (response.statusCode != 200) return null;
    final body = _decodeMap(response.body);
    if (body == null) return null;
    return _asMap(body['overview']);
  }

  Future<List<Map<String, dynamic>>> getLtdcInsights() async {
    final response = await _api.get('/ml/ltdc/insights');
    if (response.statusCode != 200) return const [];
    final body = _decodeMap(response.body);
    if (body == null) return const [];
    return _asListOfMaps(body['insights']);
  }

  Future<Map<String, dynamic>?> queryLtdcKnowledge(
    String query, {
    int topK = 5,
  }) async {
    final response = await _api.post('/ml/ltdc/knowledge', {
      'query': query,
      'top_k': topK,
    });
    if (response.statusCode != 200) return null;
    return _decodeMap(response.body);
  }

  Future<Map<String, dynamic>?> analyzeReviews(
    List<Map<String, dynamic>> reviews,
  ) async {
    final response = await _api.post('/ml/reviews/analyze', {
      'reviews': reviews,
    });
    if (response.statusCode != 200) return null;
    final body = _decodeMap(response.body);
    if (body == null) return null;
    return _asMap(body['analysis']);
  }
}
