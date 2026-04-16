class SocialFeedPost {
  const SocialFeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.matchId,
    required this.mode,
    required this.setsScore,
    required this.resultLabel,
    required this.description,
    required this.createdAt,
    this.player1Name,
    this.player1Score,
    this.player2Name,
    this.player2Score,
    this.winnerUserId,
    this.matchAverage,
    this.matchCheckoutRate,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByCurrentUser = false,
    this.comments = const <SocialFeedComment>[],
    this.isMine = false,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String matchId;
  final String mode;
  final String setsScore;
  final String resultLabel;
  final String description;
  final DateTime createdAt;
  final String? player1Name;
  final int? player1Score;
  final String? player2Name;
  final int? player2Score;
  final String? winnerUserId;
  final double? matchAverage;
  final double? matchCheckoutRate;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByCurrentUser;
  final List<SocialFeedComment> comments;
  final bool isMine;

  SocialFeedPost copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLikedByCurrentUser,
    List<SocialFeedComment>? comments,
  }) {
    return SocialFeedPost(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      matchId: matchId,
      mode: mode,
      setsScore: setsScore,
      resultLabel: resultLabel,
      description: description,
      createdAt: createdAt,
      player1Name: player1Name,
      player1Score: player1Score,
      player2Name: player2Name,
      player2Score: player2Score,
      winnerUserId: winnerUserId,
      matchAverage: matchAverage,
      matchCheckoutRate: matchCheckoutRate,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      comments: comments ?? this.comments,
      isMine: isMine,
    );
  }

  factory SocialFeedPost.fromApi(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final author =
        (json['author'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final commentsRows =
        (json['comments'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    final parsedComments = commentsRows
        .map(SocialFeedComment.fromApi)
        .toList(growable: false);

    final fallbackCommentsCount =
        (json['comments_count'] as num?)?.toInt() ?? parsedComments.length;

    return SocialFeedPost(
      id: (json['id'] ?? '').toString(),
      authorId: (author['id'] ?? json['author_id'] ?? '').toString(),
      authorName:
          (author['username'] ??
                  json['author_name'] ??
                  json['username'] ??
                  'Joueur')
              .toString(),
      authorAvatarUrl: (author['avatar_url'] ?? json['author_avatar_url'])
          ?.toString(),
      matchId: (json['match_id'] ?? '').toString(),
      mode: (json['mode'] ?? '501').toString(),
      setsScore: (json['sets_score'] ?? '-').toString(),
      resultLabel: (json['result_label'] ?? 'Match').toString(),
      description: (json['description'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
          player1Name: json['player_1_name']?.toString(),
          player1Score: (json['player_1_score'] as num?)?.toInt(),
          player2Name: json['player_2_name']?.toString(),
          player2Score: (json['player_2_score'] as num?)?.toInt(),
          winnerUserId: json['winner_user_id']?.toString(),
          matchAverage: _toDouble(json['match_average']),
          matchCheckoutRate: _toDouble(json['match_checkout_rate']),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: fallbackCommentsCount,
      isLikedByCurrentUser: json['liked_by_me'] == true,
      comments: parsedComments,
      isMine:
          (author['id'] ?? json['author_id'] ?? '').toString() == currentUserId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar_url': authorAvatarUrl,
      'match_id': matchId,
      'mode': mode,
      'sets_score': setsScore,
      'result_label': resultLabel,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'player_1_name': player1Name,
      'player_1_score': player1Score,
      'player_2_name': player2Name,
      'player_2_score': player2Score,
      'winner_user_id': winnerUserId,
      'match_average': matchAverage,
      'match_checkout_rate': matchCheckoutRate,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'liked_by_me': isLikedByCurrentUser,
      'comments': comments.map((comment) => comment.toJson()).toList(),
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}

class SocialFeedComment {
  const SocialFeedComment({
    required this.id,
    required this.authorName,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String authorName;
  final String message;
  final DateTime createdAt;

  factory SocialFeedComment.fromApi(Map<String, dynamic> json) {
    final author =
        (json['author'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return SocialFeedComment(
      id: (json['id'] ?? '').toString(),
      authorName: (author['username'] ?? json['author_name'] ?? 'Joueur')
          .toString(),
      message: (json['message'] ?? json['content'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'author_name': authorName,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
