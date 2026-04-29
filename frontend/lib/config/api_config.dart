import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_apiBaseUrl.isNotEmpty) {
      return _apiBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:3001/api';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator uses 10.0.2.2; real phones should pass API_BASE_URL.
        return 'http://10.0.2.2:3001/api';
      default:
        return 'http://localhost:3001/api';
    }
  }

  static String get deviceSetupHint =>
      'For a real phone run with --dart-define=API_BASE_URL=http://YOUR-PC-IP:3001/api';

  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;
}
