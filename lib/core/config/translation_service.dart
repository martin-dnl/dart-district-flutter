import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../database/local_storage.dart';
import '../network/api_client.dart';

class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.countryName,
    required this.languageName,
    required this.flagEmoji,
    this.isDefault = false,
    this.isAvailable = true,
  });

  final String code;
  final String countryName;
  final String languageName;
  final String flagEmoji;
  final bool isDefault;
  final bool isAvailable;

  String get name => '$flagEmoji $countryName ($languageName)';

  factory LanguageOption.fromApi(Map<String, dynamic> json) {
    return LanguageOption(
      code: (json['code'] ?? 'fr-FR').toString(),
      countryName: (json['country_name'] ?? 'France').toString(),
      languageName: (json['language_name'] ?? 'Francais').toString(),
      flagEmoji: (json['flag_emoji'] ?? '🇫🇷').toString(),
      isDefault: json['is_default'] == true,
      isAvailable: json['is_available'] != false,
    );
  }
}

class TranslationService {
  TranslationService([this._apiClient]);
  static final TranslationService instance = TranslationService();

  static const String _settingsBox = 'settings';
  static const String _localLanguageKey = 'preferred_language';
  static const String _translationBox = 'app_settings';
  static const String _translationLanguageKey = 'language_code';
  static const String _translationDataKey = 'translations';

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Map<String, String> _translations = const <String, String>{};
  String _currentLanguage = 'fr-FR';

  String get currentLanguage => _currentLanguage;

  Future<void> loadFromLocal() async {
    final code = await LocalStorage.get<String>(
      _translationBox,
      _translationLanguageKey,
    );
    final cached = await LocalStorage.get<dynamic>(
      _translationBox,
      _translationDataKey,
    );

    if (code != null && code.trim().isNotEmpty) {
      _currentLanguage = code.trim();
    }

    if (cached is Map) {
      _translations = cached.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      revision.value++;
    }
  }

  Future<void> loadTranslations(
    String languageCode,
    Map<String, String> translations,
  ) async {
    _currentLanguage = languageCode;
    _translations = translations;

    await LocalStorage.put<String>(
      _translationBox,
      _translationLanguageKey,
      languageCode,
    );
    await LocalStorage.put<dynamic>(
      _translationBox,
      _translationDataKey,
      Map<String, String>.from(translations),
    );

    revision.value++;
  }

  String translate(String key, {String? fallback}) {
    if (_translations.containsKey(key)) {
      return _translations[key] ?? fallback ?? key;
    }
    return fallback ?? key;
  }

  final ApiClient? _apiClient;

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
    await _apiClient!.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'preferred_language': code},
    );

    final translations = await getTranslations(code);
    if (translations.isNotEmpty) {
      await loadTranslations(code, translations);
    }
  }

  Future<List<LanguageOption>> getAvailableLanguages() async {
    final api = _apiClient;
    if (api == null) {
      return const <LanguageOption>[
        LanguageOption(
          code: 'fr-FR',
          countryName: 'France',
          languageName: 'Francais',
          flagEmoji: '🇫🇷',
          isDefault: true,
        ),
        LanguageOption(
          code: 'en-US',
          countryName: 'United States',
          languageName: 'English',
          flagEmoji: '🇺🇸',
        ),
      ];
    }

    try {
      final response = await api.get<Map<String, dynamic>>(
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
      LanguageOption(
        code: 'fr-FR',
        countryName: 'France',
        languageName: 'Francais',
        flagEmoji: '🇫🇷',
        isDefault: true,
      ),
      LanguageOption(
        code: 'en-US',
        countryName: 'United States',
        languageName: 'English',
        flagEmoji: '🇺🇸',
      ),
    ];
  }

  Future<Map<String, String>> getTranslations(String languageCode) async {
    final api = _apiClient;
    if (api == null) {
      return const <String, String>{};
    }

    try {
      final response = await api.get<Map<String, dynamic>>(
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

String t(String key, {String? fallback}) {
  return TranslationService.instance.translate(key, fallback: fallback);
}
