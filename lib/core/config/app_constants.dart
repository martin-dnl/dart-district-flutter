import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  // API
  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _wsBaseUrlOverride =
      String.fromEnvironment('WS_BASE_URL', defaultValue: '');
  static const String _googleServerClientIdOverride =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');
  static const String _googleWebClientIdOverride =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }

    if (kReleaseMode) {
      return 'https://dart-district.fr/api/v1';
    }

    if (kIsWeb) {
      return 'http://localhost:8080/api/v1';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8080/api/v1';
      default:
        return 'http://localhost:8080/api/v1';
    }
  }

  static String get wsBaseUrl {
    if (_wsBaseUrlOverride.isNotEmpty) {
      return _wsBaseUrlOverride;
    }

    if (kReleaseMode) {
      return 'wss://dart-district.fr/ws';
    }

    if (kIsWeb) {
      return 'ws://localhost:8080/ws';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'ws://10.0.2.2:8080/ws';
      default:
        return 'ws://localhost:8080/ws';
    }
  }

  static String? get googleServerClientId {
    if (_googleServerClientIdOverride.isEmpty) {
      return null;
    }
    return _googleServerClientIdOverride;
  }

  static String? get googleWebClientId {
    if (_googleWebClientIdOverride.isNotEmpty) {
      return _googleWebClientIdOverride;
    }
    // Fallback for simple setups where a single OAuth client id is provided.
    if (_googleServerClientIdOverride.isNotEmpty) {
      return _googleServerClientIdOverride;
    }
    return null;
  }

  // WebSocket
  static const int wsHeartbeatInterval = 30; // seconds
  static const int wsReconnectDelay = 5; // seconds

  // Game modes
  static const List<int> x01Variants = [301, 501, 701];

  // ELO
  static const int defaultElo = 1000;
  static const int kFactor = 32;

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'current_user';

  // UI
  static const double borderRadius = 16.0;
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 12.0;
  static const double horizontalPadding = 16.0;
  static const double verticalPadding = 12.0;
}
