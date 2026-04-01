import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../database/local_storage.dart';
import '../network/api_client.dart';
import 'app_version_models.dart';

class AppVersionService {
  AppVersionService(this._apiClient);

  final ApiClient _apiClient;

  static const _cacheBox = 'app_runtime';
  static const _cacheKey = 'app_version_policy_cache';
  static const _cachedAtKey = 'app_version_policy_cached_at';
  static const _defaultTtl = Duration(hours: 1);

  Future<AppVersionCheckResult> check() async {
    final info = await PackageInfo.fromPlatform();
    final installedVersion = info.version;

    if (kIsWeb) {
      return AppVersionCheckResult(
        decision: AppVersionDecision.upToDate,
        policy: const AppVersionPolicy(
          minVersion: '0.0.0',
          recommendedVersion: '0.0.0',
          storeUrlAndroid: '',
          storeUrlIos: '',
          messageForceUpdate: '',
          messageSoftUpdate: '',
          status: 'up_to_date',
          ttlSeconds: 3600,
        ),
        installedVersion: installedVersion,
      );
    }

    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'android',
    };

    final cachedPolicy = await _loadCachedPolicy();
    final policy =
        cachedPolicy ?? await _fetchAndCachePolicy(platform, installedVersion);

    final decision = _decisionFromPolicy(policy, installedVersion);

    return AppVersionCheckResult(
      decision: decision,
      policy: policy,
      installedVersion: installedVersion,
    );
  }

  Future<AppVersionPolicy> _fetchAndCachePolicy(
    String platform,
    String appVersion,
  ) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/app/version',
      queryParameters: {'platform': platform, 'app_version': appVersion},
    );

    final envelope = response.data ?? <String, dynamic>{};
    final payload = (envelope['data'] is Map<String, dynamic>)
        ? envelope['data'] as Map<String, dynamic>
        : envelope;

    final policy = AppVersionPolicy.fromJson(payload);

    await LocalStorage.put<String>(
      _cacheBox,
      _cacheKey,
      jsonEncode(policy.toJson()),
    );
    await LocalStorage.put<int>(
      _cacheBox,
      _cachedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    return policy;
  }

  Future<AppVersionPolicy?> _loadCachedPolicy() async {
    final raw = await LocalStorage.get<String>(_cacheBox, _cacheKey);
    final cachedAt = await LocalStorage.get<int>(_cacheBox, _cachedAtKey);
    if (raw == null || cachedAt == null) {
      return null;
    }

    final ttl = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(cachedAt),
    );
    if (ttl > _defaultTtl) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AppVersionPolicy.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  AppVersionDecision _decisionFromPolicy(
    AppVersionPolicy policy,
    String installed,
  ) {
    if (_compareVersions(installed, policy.minVersion) < 0) {
      return AppVersionDecision.forceUpdate;
    }

    if (_compareVersions(installed, policy.recommendedVersion) < 0) {
      return AppVersionDecision.softUpdate;
    }

    return AppVersionDecision.upToDate;
  }

  int _compareVersions(String left, String right) {
    final l = _normalizeParts(left);
    final r = _normalizeParts(right);
    final max = l.length > r.length ? l.length : r.length;

    while (l.length < max) {
      l.add(0);
    }
    while (r.length < max) {
      r.add(0);
    }

    for (var i = 0; i < max; i++) {
      if (l[i] < r[i]) return -1;
      if (l[i] > r[i]) return 1;
    }

    return 0;
  }

  List<int> _normalizeParts(String version) {
    final clean = version.trim().replaceFirst(
      RegExp('^v', caseSensitive: false),
      '',
    );
    return clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }
}
