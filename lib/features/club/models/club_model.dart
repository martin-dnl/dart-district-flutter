class ClubModel {
  final String id;
  final String name;
  final String? city;
  final String? address;
  final String? postalCode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? openingHours;
  final String? codeIris;
  final String? imageUrl;
  final int memberCount;
  final int dartBoardsCount;
  final int zonesControlled;
  final int rank;
  final List<ClubMember> members;

  const ClubModel({
    required this.id,
    required this.name,
    this.city,
    this.address,
    this.postalCode,
    this.country,
    this.latitude,
    this.longitude,
    this.openingHours,
    this.codeIris,
    this.imageUrl,
    this.memberCount = 0,
    this.dartBoardsCount = 0,
    this.zonesControlled = 0,
    this.rank = 0,
    this.members = const [],
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String?,
      address: json['address'] as String?,
      postalCode: json['postalCode'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      openingHours: json['openingHours'] as Map<String, dynamic>?,
      codeIris: json['codeIris'] as String?,
      imageUrl: json['imageUrl'] as String?,
      memberCount: json['memberCount'] as int? ?? 0,
      dartBoardsCount: json['dartBoardsCount'] as int? ?? 0,
      zonesControlled: json['zonesControlled'] as int? ?? 0,
      rank: json['rank'] as int? ?? 0,
      members:
          (json['members'] as List<dynamic>?)
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
      city: json['city'] as String?,
      address: json['address'] as String?,
        postalCode: json['postal_code'] as String?,
        country: json['country'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble() ??
          double.tryParse((json['latitude'] ?? '').toString()),
        longitude: (json['longitude'] as num?)?.toDouble() ??
          double.tryParse((json['longitude'] ?? '').toString()),
        openingHours: json['opening_hours'] as Map<String, dynamic>?,
        codeIris: json['code_iris'] as String?,
      imageUrl: json['image_url'] as String?,
      memberCount:
          (json['member_count'] as num?)?.toInt() ?? membersJson.length,
      dartBoardsCount: (json['dart_boards_count'] as num?)?.toInt() ?? 0,
      zonesControlled:
          (json['zones_controlled'] as num?)?.toInt() ??
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
      avatarUrl:
          user?['avatar_url'] as String? ?? json['avatar_url'] as String?,
      elo:
          (user?['elo'] as num?)?.toInt() ??
          (json['elo'] as num?)?.toInt() ??
          1000,
      role: (json['role'] ?? 'player').toString(),
    );
  }
}
