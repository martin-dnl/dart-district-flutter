class AppVersionPolicy {
  const AppVersionPolicy({
    required this.minVersion,
    required this.recommendedVersion,
    required this.storeUrlAndroid,
    required this.storeUrlIos,
    required this.messageForceUpdate,
    required this.messageSoftUpdate,
    required this.status,
    required this.ttlSeconds,
  });

  final String minVersion;
  final String recommendedVersion;
  final String storeUrlAndroid;
  final String storeUrlIos;
  final String messageForceUpdate;
  final String messageSoftUpdate;
  final String status;
  final int ttlSeconds;

  factory AppVersionPolicy.fromJson(Map<String, dynamic> json) {
    return AppVersionPolicy(
      minVersion: (json['min_version'] as String?) ?? '0.0.0',
      recommendedVersion: (json['recommended_version'] as String?) ?? '0.0.0',
      storeUrlAndroid: (json['store_url_android'] as String?) ?? '',
      storeUrlIos: (json['store_url_ios'] as String?) ?? '',
      messageForceUpdate:
          (json['message_force_update'] as String?) ??
          'Une nouvelle version est obligatoire pour continuer.',
      messageSoftUpdate:
          (json['message_soft_update'] as String?) ??
          'Une mise a jour est disponible.',
      status: (json['status'] as String?) ?? 'up_to_date',
      ttlSeconds: (json['ttl_seconds'] as int?) ?? 3600,
    );
  }

  Map<String, dynamic> toJson() => {
    'min_version': minVersion,
    'recommended_version': recommendedVersion,
    'store_url_android': storeUrlAndroid,
    'store_url_ios': storeUrlIos,
    'message_force_update': messageForceUpdate,
    'message_soft_update': messageSoftUpdate,
    'status': status,
    'ttl_seconds': ttlSeconds,
  };
}

enum AppVersionDecision { forceUpdate, softUpdate, upToDate }

class AppVersionCheckResult {
  const AppVersionCheckResult({
    required this.decision,
    required this.policy,
    required this.installedVersion,
  });

  final AppVersionDecision decision;
  final AppVersionPolicy policy;
  final String installedVersion;
}
