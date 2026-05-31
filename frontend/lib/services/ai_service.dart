import 'dart:convert';

import 'api_service.dart';

class AIService {
  AIService({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  static const List<Map<String, dynamic>> _tourismHotspots = [
    {
      'name': 'Maliba Lodge',
      'district': 'Botha-Bothe',
      'score': 95,
      'category': 'Luxury Lodge',
    },
    {
      'name': 'Afriski Mountain Resort',
      'district': 'Botha-Bothe',
      'score': 92,
      'category': 'Ski Resort',
    },
    {
      'name': 'Sani Pass',
      'district': 'Qacha\'s Nek',
      'score': 89,
      'category': 'Mountain Pass',
    },
    {
      'name': 'Katse Dam',
      'district': 'Thaba-Tseka',
      'score': 87,
      'category': 'Dam/Scenic',
    },
    {
      'name': 'Ts\'ehlanyane National Park',
      'district': 'Leribe',
      'score': 85,
      'category': 'National Park',
    },
    {
      'name': 'Morija Museum',
      'district': 'Morija',
      'score': 82,
      'category': 'Cultural',
    },
    {
      'name': 'Thaba-Bosiu',
      'district': 'Maseru',
      'score': 80,
      'category': 'Historical',
    },
  ];

  static const List<Map<String, dynamic>> _tourismActivities = [
    {
      'name': 'Skiing at Afriski',
      'season': 'Winter',
      'popularity': 92,
      'category': 'Adventure',
    },
    {
      'name': 'Hiking in Maloti Mountains',
      'season': 'All year',
      'popularity': 88,
      'category': 'Adventure',
    },
    {
      'name': 'Cultural Tour - Morija',
      'season': 'All year',
      'popularity': 85,
      'category': 'Culture',
    },
    {
      'name': 'Pony Trekking',
      'season': 'Summer',
      'popularity': 82,
      'category': 'Adventure',
    },
    {
      'name': 'Maletsunyane Falls Abseiling',
      'season': 'Summer',
      'popularity': 84,
      'category': 'Adventure',
    },
    {
      'name': 'Sani Pass 4x4 Experience',
      'season': 'All year',
      'popularity': 81,
      'category': 'Adventure',
    },
  ];

  static const Set<String> _lowSignalMlNames = {
    'unknown',
    'edward tikiso',
    'more ralefifi',
    'farish d',
    'thetsane west',
    'teyateyaneng',
    'juju centre',
    'icraft',
    'zoeewellery',
  };

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

  List<Map<String, dynamic>> _mergeUniqueByName(
    List<Map<String, dynamic>> primary,
    List<Map<String, dynamic>> extras,
  ) {
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];

    for (final item in [...primary, ...extras]) {
      final name = (item['name'] ?? item['country'] ?? item['season'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (name.isEmpty || seen.add(name)) {
        merged.add(item);
      }
    }

    return merged;
  }

  bool _isUsefulMlItem(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString().trim().toLowerCase();
    return name.isNotEmpty && !_lowSignalMlNames.contains(name);
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
    if (response.statusCode != 200) return _tourismHotspots;
    final body = _decodeMap(response.body);
    if (body == null) return _tourismHotspots;
    final liveHotspots =
        _asListOfMaps(body['data']).where(_isUsefulMlItem).toList();
    return _mergeUniqueByName(_tourismHotspots, liveHotspots);
  }

  Future<List<Map<String, dynamic>>> getRecommendations({
    String role = 'tourist',
    Map<String, dynamic>? preferences,
  }) async {
    final response = await _api.post('/ml/recommend', {
      'role': role,
      'preferences': preferences ?? <String, dynamic>{},
    });

    if (response.statusCode != 200) return _tourismActivities;
    final body = _decodeMap(response.body);
    if (body == null) return _tourismActivities;
    final recommendations = _asMap(body['recommendations']);
    final liveActivities = _asListOfMaps(recommendations?['activities'])
        .where(_isUsefulMlItem)
        .toList();
    return _mergeUniqueByName(_tourismActivities, liveActivities);
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

  Future<Map<String, dynamic>?> getCharts() async {
    final response = await _api.get('/ml/charts');
    if (response.statusCode != 200) return null;
    final body = _decodeMap(response.body);
    if (body == null) return null;
    return _asMap(body['charts']);
  }

  Future<Map<String, dynamic>?> askScikitQuestion(String question) async {
    final response = await _api.post('/ml/ask', {
      'question': question,
    });
    if (response.statusCode != 200) return null;
    final body = _decodeMap(response.body);
    if (body == null) return null;
    return _asMap(body['result']);
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
