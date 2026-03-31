class ClubModel {
  final String id;
  final String name;
  final String? address;
  final String? imageUrl;
  final int memberCount;
  final int zonesControlled;
  final int rank;
  final List<ClubMember> members;

  const ClubModel({
    required this.id,
    required this.name,
    this.address,
    this.imageUrl,
    this.memberCount = 0,
    this.zonesControlled = 0,
    this.rank = 0,
    this.members = const [],
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      imageUrl: json['imageUrl'] as String?,
      memberCount: json['memberCount'] as int? ?? 0,
      zonesControlled: json['zonesControlled'] as int? ?? 0,
      rank: json['rank'] as int? ?? 0,
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => ClubMember.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory ClubModel.fromApi(Map<String, dynamic> json) {
    final membersJson = (json['members'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    return ClubModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Club').toString(),
      address: json['address'] as String?,
      imageUrl: json['image_url'] as String?,
      memberCount: (json['member_count'] as num?)?.toInt() ?? membersJson.length,
      zonesControlled: (json['zones_controlled'] as num?)?.toInt() ??
          (json['conquest_points'] as num?)?.toInt() ??
          0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      members: membersJson.map(ClubMember.fromApi).toList(),
    );
  }
}

class ClubMember {
  final String id;
  final String username;
  final String? avatarUrl;
  final int elo;
  final String role;

  const ClubMember({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.elo = 1000,
    this.role = 'member',
  });

  factory ClubMember.fromJson(Map<String, dynamic> json) {
    return ClubMember(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      elo: json['elo'] as int? ?? 1000,
      role: json['role'] as String? ?? 'member',
    );
  }

  factory ClubMember.fromApi(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return ClubMember(
      id: (user?['id'] ?? json['id'] ?? '').toString(),
      username: (user?['username'] ?? json['username'] ?? 'Membre').toString(),
      avatarUrl: user?['avatar_url'] as String? ?? json['avatar_url'] as String?,
      elo: (user?['elo'] as num?)?.toInt() ?? (json['elo'] as num?)?.toInt() ?? 1000,
      role: (json['role'] ?? 'player').toString(),
    );
  }
}
