import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../controller/profile_controller.dart';

class ProfileService {
  const ProfileService(this._api);

  final ApiClient _api;

  Future<List<AchievementBadge>> getMyBadges() async {
    final response = await _api.get<Map<String, dynamic>>('/users/me/badges');
    final rows = (response.data?['data'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    return rows.map((row) {
      final badge =
          row['badge'] as Map<String, dynamic>? ?? const <String, dynamic>{};

      final earnedAt = DateTime.tryParse((row['earned_at'] ?? '').toString());
      return AchievementBadge(
        id: (badge['id'] ?? row['id'] ?? '').toString(),
        key: (badge['key'] ?? '').toString(),
        name: (badge['name'] ?? '').toString(),
        description: (badge['description'] ?? '').toString(),
        icon: (badge['image_asset'] ?? '🏅').toString(),
        unlocked: true,
        earnedAt: earnedAt,
      );
    }).toList();
  }

  Future<String> uploadAvatar(File imageFile) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(imageFile.path),
    });

    final response = await _api.post<Map<String, dynamic>>(
      '/users/me/avatar',
      data: formData,
    );

    final body = response.data ?? const <String, dynamic>{};
    final data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : body;

    return (data['avatar_url'] ?? '').toString();
  }
}
