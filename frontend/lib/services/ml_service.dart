import 'dart:convert';

import 'api_service.dart';

class MlService {
  MlService({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  static const Map<String, dynamic> _legacyIntelligenceFallback = {
    'legacy_intelligence': {
      'peak_month': {
        'month': 'Dec',
        'arrivals': 99553,
      },
      'top_attractions': [
        {
          'name': 'Thaba Bosiu',
          'visitors': 32097,
        },
      ],
      'top_markets': [
        {
          'country': 'South Africa',
          'arrivals': 860000,
          'market_share': 94.4,
          'growth': -31,
        },
        {
          'country': 'Zimbabwe',
          'arrivals': 19200,
          'market_share': 2.1,
          'growth': 24.5,
        },
        {
          'country': 'USA',
          'arrivals': 6720,
          'market_share': 0.7,
          'growth': 52.8,
        },
        {
          'country': 'India',
          'arrivals': 5760,
          'market_share': 0.6,
          'growth': 19.5,
        },
        {
          'country': 'Netherlands',
          'arrivals': 5760,
          'market_share': 0.6,
          'growth': 161.6,
        },
      ],
      'sentiment_highlights': [
        {
          'label': 'Good Service',
          'percentage': 37.1,
        },
      ],
      'seasonal_hotspots': [
        {
          'season': 'Summer (Dec-Feb)',
          'places': ['Maletsunyane Falls', 'Sani Pass', 'Katse Dam'],
        },
        {
          'season': 'Winter (Jun-Aug)',
          'places': ['Afri Ski', 'Maletsunyane Falls', 'Thaba Bosiu'],
        },
        {
          'season': 'Spring (Sep-Nov)',
          'places': ['Morija Museum', 'Kome Caves'],
        },
        {
          'season': 'Autumn (Mar-May)',
          'places': ['Thaba Bosiu', 'Katse Dam', 'Semonkong'],
        },
      ],
    },
  };

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
      'name': 'Sehlabathebe National Park',
      'district': 'Qacha\'s Nek',
      'score': 84,
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
    {
      'name': 'Kome Caves',
      'district': 'Berea',
      'score': 78,
      'category': 'Cultural',
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
    {
      'name': 'Katse Dam Boat Tour',
      'season': 'All year',
      'popularity': 80,
      'category': 'Scenic',
    },
    {
      'name': 'Thaba-Bosiu Heritage Walk',
      'season': 'All year',
      'popularity': 79,
      'category': 'Culture',
    },
    {
      'name': 'Kome Caves Village Tour',
      'season': 'All year',
      'popularity': 78,
      'category': 'Culture',
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

  Map<String, dynamic> _mergeLegacyIntelligence(Map<String, dynamic> dashboard) {
    final merged = Map<String, dynamic>.from(dashboard);
    final fallback =
        _asMap(_legacyIntelligenceFallback['legacy_intelligence']) ?? {};
    final current = _asMap(merged['legacy_intelligence']) ?? {};
    final legacy = Map<String, dynamic>.from(current);

    legacy['peak_month'] =
        _asMap(legacy['peak_month'])?.isNotEmpty == true
            ? legacy['peak_month']
            : fallback['peak_month'];
    legacy['top_attractions'] = _mergeUniqueByName(
      _asListOfMaps(legacy['top_attractions']),
      _asListOfMaps(fallback['top_attractions']),
    );
    legacy['top_markets'] = _mergeUniqueByName(
      _asListOfMaps(legacy['top_markets']),
      _asListOfMaps(fallback['top_markets']),
    );
    legacy['sentiment_highlights'] = _mergeUniqueByName(
      _asListOfMaps(legacy['sentiment_highlights']),
      _asListOfMaps(fallback['sentiment_highlights']),
    );
    legacy['seasonal_hotspots'] = _mergeUniqueByName(
      _asListOfMaps(legacy['seasonal_hotspots']),
      _asListOfMaps(fallback['seasonal_hotspots']),
    );

    merged['legacy_intelligence'] = legacy;
    return merged;
  }

  Future<Map<String, dynamic>?> fetchDashboard() async {
    final response = await _apiService.get('/ml/dashboard');
    if (response.statusCode != 200) {
      return Map<String, dynamic>.from(_legacyIntelligenceFallback);
    }
    final body = _decodeMap(response.body);
    if (body == null) {
      return Map<String, dynamic>.from(_legacyIntelligenceFallback);
    }
    final dashboard = _asMap(body['dashboard']);
    if (dashboard == null) {
      return Map<String, dynamic>.from(_legacyIntelligenceFallback);
    }
    return _mergeLegacyIntelligence(dashboard);
  }

  Future<List<Map<String, dynamic>>> fetchRecommendations({
    String role = 'tourist',
    Map<String, dynamic>? preferences,
  }) async {
    final response = await _apiService.post('/ml/recommend', {
      'role': role,
      'preferences': preferences ?? <String, dynamic>{},
    });

    if (response.statusCode != 200) return _tourismActivities;
    final body = _decodeMap(response.body);
    if (body == null) return _tourismActivities;
    final recommendations = _asMap(body['recommendations']);
    final activities = _asListOfMaps(recommendations?['activities'])
        .where(_isUsefulMlItem)
        .toList();

    return _mergeUniqueByName(_tourismActivities, activities);
  }

  Future<List<Map<String, dynamic>>> fetchHotspots() async {
    final response = await _apiService.get('/ml/hotspots');
    if (response.statusCode != 200) return _tourismHotspots;
    final body = _decodeMap(response.body);
    if (body == null) return _tourismHotspots;
    final liveHotspots =
        _asListOfMaps(body['data']).where(_isUsefulMlItem).toList();
    return _mergeUniqueByName(_tourismHotspots, liveHotspots);
  }

  Future<List<Map<String, dynamic>>> fetchForecast() async {
    final response = await _apiService.get('/ml/forecast');
    if (response.statusCode != 200) return const [];
    final body = _decodeMap(response.body);
    if (body == null) return const [];
    return _asListOfMaps(body['forecast']);
  }
}
