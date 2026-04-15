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
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'liked_by_me': isLikedByCurrentUser,
      'comments': comments.map((comment) => comment.toJson()).toList(),
    };
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
