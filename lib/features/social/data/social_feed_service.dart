import '../../../core/database/local_storage.dart';
import '../../../core/network/api_client.dart';
import '../../contacts/data/contacts_repository.dart';
import '../models/social_feed_post.dart';

class SocialFeedService {
  const SocialFeedService(this._api);

  final ApiClient _api;

  static const String _box = 'social_feed';
  static const String _key = 'local_posts';

  Future<List<SocialFeedPost>> fetchFeed({
    required String currentUserId,
    required int limit,
    required int offset,
  }) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/social/feed',
        queryParameters: {
          'limit': '$limit',
          'offset': '$offset',
        },
      );

      final rows = (response.data?['data'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      return rows
          .map((row) => SocialFeedPost.fromApi(row, currentUserId: currentUserId))
          .toList(growable: false);
    } catch (_) {
      return _fetchLocalFeed(currentUserId: currentUserId, limit: limit, offset: offset);
    }
  }

  Future<void> shareMatch({
    required String currentUserId,
    required String currentUsername,
    String? currentUserAvatarUrl,
    required String matchId,
    required String mode,
    required String setsScore,
    required String resultLabel,
    required String description,
  }) async {
    final payload = <String, dynamic>{
      'match_id': matchId,
      'description': description,
    };

    try {
      await _api.post<Map<String, dynamic>>('/social/posts', data: payload);
      return;
    } catch (_) {
      final local = await _loadLocalPosts();
      local.insert(
        0,
        SocialFeedPost(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          authorId: currentUserId,
          authorName: currentUsername,
          authorAvatarUrl: currentUserAvatarUrl,
          matchId: matchId,
          mode: mode,
          setsScore: setsScore,
          resultLabel: resultLabel,
          description: description,
          createdAt: DateTime.now(),
          isMine: true,
        ),
      );
      await _saveLocalPosts(local);
    }
  }

  Future<List<SocialFeedPost>> _fetchLocalFeed({
    required String currentUserId,
    required int limit,
    required int offset,
  }) async {
    final posts = await _loadLocalPosts();
    final friendIds = await _friendIds();
    final visible = posts.where((post) {
      return post.authorId == currentUserId || friendIds.contains(post.authorId);
    }).toList(growable: false);

    if (offset >= visible.length) {
      return const <SocialFeedPost>[];
    }

    final end = (offset + limit).clamp(0, visible.length);
    return visible.sublist(offset, end);
  }

  Future<List<SocialFeedPost>> _loadLocalPosts() async {
    final raw = await LocalStorage.get<dynamic>(_box, _key);
    if (raw is! List) {
      return const <SocialFeedPost>[];
    }

    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .map((json) => SocialFeedPost.fromApi(json, currentUserId: ''))
        .toList(growable: false);
  }

  Future<void> _saveLocalPosts(List<SocialFeedPost> posts) {
    return LocalStorage.put<dynamic>(
      _box,
      _key,
      posts.map((post) => post.toJson()).toList(growable: false),
    );
  }

  Future<Set<String>> _friendIds() async {
    try {
      final repository = ContactsRepository(_api);
      final friends = await repository.fetchFriends();
      return friends.map((friend) => friend.id).toSet();
    } catch (_) {
      return <String>{};
    }
  }
}
