import 'package:dio/dio.dart';

import '../database/local_storage.dart';
import '../network/api_client.dart';

class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.name,
    this.isDefault = false,
    this.isAvailable = true,
  });

  final String code;
  final String name;
  final bool isDefault;
  final bool isAvailable;

  factory LanguageOption.fromApi(Map<String, dynamic> json) {
    return LanguageOption(
      code: (json['code'] ?? 'fr-FR').toString(),
      name: (json['name'] ?? 'Francais').toString(),
      isDefault: json['is_default'] == true,
      isAvailable: json['is_available'] != false,
    );
  }
}

class TranslationService {
  TranslationService(this._apiClient);

  final ApiClient _apiClient;

  static const String _settingsBox = 'settings';
  static const String _localLanguageKey = 'preferred_language';

  static Future<String> restorePreferredLanguage() async {
    final local = await LocalStorage.get<String>(_settingsBox, _localLanguageKey);
    if (local != null && local.trim().isNotEmpty) {
      return local.trim();
    }
    return 'fr-FR';
  }

  Future<String> getPreferredLanguage() async {
    return restorePreferredLanguage();
  }

  Future<void> setPreferredLanguage(String languageCode) async {
    final code = languageCode.trim();
    if (code.isEmpty) {
      return;
    }

    await LocalStorage.put<String>(_settingsBox, _localLanguageKey, code);
    await _apiClient.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'preferred_language': code},
    );
  }

  Future<List<LanguageOption>> getAvailableLanguages() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/languages',
        queryParameters: const {'available': 'true'},
      );
      final payload =
          (response.data?['data'] as List<dynamic>?) ??
          (response.data as List<dynamic>?) ??
          <dynamic>[];
      final options = payload
          .whereType<Map<String, dynamic>>()
          .map(LanguageOption.fromApi)
          .where((entry) => entry.isAvailable)
          .toList(growable: false);

      if (options.isNotEmpty) {
        return options;
      }
    } catch (_) {
      // Network fallback below.
    }

    return const <LanguageOption>[
      LanguageOption(code: 'fr-FR', name: 'Francais', isDefault: true),
      LanguageOption(code: 'en-US', name: 'English'),
    ];
  }

  Future<Map<String, String>> getTranslations(String languageCode) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/translations/$languageCode',
      );
      final payload =
          (response.data?['data'] as Map<String, dynamic>?) ??
          response.data ??
          const <String, dynamic>{};
      return payload.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } on DioException {
      return const <String, String>{};
    }
  }
}
