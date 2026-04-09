import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/dartboard_heatmap_models.dart';
import '../../auth/models/user_model.dart';
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
    final path = imageFile.path.toLowerCase();
    final filename = imageFile.uri.pathSegments.isNotEmpty
      ? imageFile.uri.pathSegments.last
      : 'avatar.jpg';
    final contentType = path.endsWith('.png')
        ? MediaType('image', 'png')
        : MediaType('image', 'jpeg');

    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        imageFile.path,
        filename: filename,
        contentType: contentType,
      ),
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

  Future<UserModel> fetchUserById(String userId) async {
    final response = await _api.get<Map<String, dynamic>>('/users/$userId');
    final data = response.data ?? const <String, dynamic>{};
    final inner = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;
    return UserModel.fromApi(inner);
  }

  Future<Map<String, bool>> getFriendshipStatus(String userId) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/contacts/status/$userId',
    );
    final data =
        response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
    return {
      'is_friend': data['is_friend'] as bool? ?? false,
      'is_blocked': data['is_blocked'] as bool? ?? false,
      'has_pending_request': data['has_pending_request'] as bool? ?? false,
    };
  }

  Future<void> sendFriendRequest(String userId) async {
    await _api.post<Map<String, dynamic>>(
      '/contacts/requests',
      data: {'receiver_id': userId},
    );
  }

  Future<void> removeFriend(String userId) async {
    await _api.delete<Map<String, dynamic>>('/contacts/friends/$userId');
  }

  Future<void> blockUser(String userId) async {
    await _api.post<Map<String, dynamic>>('/contacts/block/$userId');
  }

  Future<DartboardHeatmapPeriods> fetchDartboardPeriods({
    String? userId,
  }) async {
    final path = userId == null
        ? '/stats/me/dartboard-periods'
        : '/stats/$userId/dartboard-periods';
    final response = await _api.get<Map<String, dynamic>>(path);
    final raw =
        (response.data?['data'] as Map<String, dynamic>?) ??
        response.data ??
        const <String, dynamic>{};
    return DartboardHeatmapPeriods.fromJson(raw);
  }

  Future<DartboardHeatmapData> fetchDartboardHeatmap({
    String? userId,
    required String period,
    int? year,
    int? month,
  }) async {
    final path = userId == null
        ? '/stats/me/dartboard-heatmap'
        : '/stats/$userId/dartboard-heatmap';
    final queryParameters = <String, dynamic>{'period': period};
    if (year != null) {
      queryParameters['year'] = year;
    }
    if (month != null) {
      queryParameters['month'] = month;
    }
    final response = await _api.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
    );
    final raw =
        (response.data?['data'] as Map<String, dynamic>?) ??
        response.data ??
        const <String, dynamic>{};
    return DartboardHeatmapData.fromJson(raw);
  }
}
