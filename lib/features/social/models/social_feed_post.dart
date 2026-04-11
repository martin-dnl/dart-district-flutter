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
  final bool isMine;

  factory SocialFeedPost.fromApi(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final author = (json['author'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return SocialFeedPost(
      id: (json['id'] ?? '').toString(),
      authorId: (author['id'] ?? json['author_id'] ?? '').toString(),
      authorName: (author['username'] ??
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
      isMine: (author['id'] ?? json['author_id'] ?? '').toString() ==
          currentUserId,
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
    };
  }
}
