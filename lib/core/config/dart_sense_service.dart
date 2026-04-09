import '../database/local_storage.dart';
import '../network/api_client.dart';

enum DartSenseMode { off, on }

class DartSenseService {
  DartSenseService(this._apiClient);

  final ApiClient _apiClient;

  static const String settingsBox = 'settings';
  static const String settingKey = 'DART_SENSE.MODE';
  static const String localModeKey = 'dart_sense_mode';
  static const String pendingSyncKey = 'dart_sense_pending_sync';

  static String asRawValue(DartSenseMode mode) {
    switch (mode) {
      case DartSenseMode.off:
        return 'OFF';
      case DartSenseMode.on:
        return 'ON';
    }
  }

  static DartSenseMode fromRawValue(String? value) {
    final normalized = (value ?? '').trim().toUpperCase();
    if (normalized == 'ON') {
      return DartSenseMode.on;
    }
    return DartSenseMode.off;
  }

  Future<DartSenseMode> loadMode() async {
    final local = await LocalStorage.get<String>(settingsBox, localModeKey);
    if (local != null && local.trim().isNotEmpty) {
      return fromRawValue(local);
    }

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/users/me/settings',
        queryParameters: const {'key': settingKey},
      );
      final raw = response.data ?? const <String, dynamic>{};
      final data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
      final value = (data['value'] ?? '').toString();
      final mode = fromRawValue(value);
      await LocalStorage.put<String>(settingsBox, localModeKey, asRawValue(mode));
      return mode;
    } catch (_) {
      return DartSenseMode.off;
    }
  }

  Future<void> saveMode(DartSenseMode mode) async {
    final value = asRawValue(mode);
    await LocalStorage.put<String>(settingsBox, localModeKey, value);

    try {
      await _apiClient.patch<Map<String, dynamic>>(
        '/users/me/settings',
        data: {'key': settingKey, 'value': value},
      );
      await LocalStorage.remove(settingsBox, pendingSyncKey);
    } catch (_) {
      await LocalStorage.put<String>(settingsBox, pendingSyncKey, '1');
    }
  }
}
