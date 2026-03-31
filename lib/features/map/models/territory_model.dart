enum TerritoryStatus { available, locked, alert, conquered, conflict }

class TerritoryModel {
  final String id;
  final String codeIris;
  final String name;
  final TerritoryStatus status;
  final String? ownerClubId;
  final String? ownerClubName;
  final double latitude;
  final double longitude;

  const TerritoryModel({
    required this.id,
    required this.codeIris,
    required this.name,
    required this.status,
    this.ownerClubId,
    this.ownerClubName,
    required this.latitude,
    required this.longitude,
  });

  factory TerritoryModel.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] ?? 'available').toString();
    final status = switch (statusRaw) {
      'locked' => TerritoryStatus.locked,
      'alert' => TerritoryStatus.alert,
      'conquered' => TerritoryStatus.conquered,
      'conflict' => TerritoryStatus.conflict,
      _ => TerritoryStatus.available,
    };

    return TerritoryModel(
      id: (json['id'] ?? json['code_iris'] ?? '').toString(),
      codeIris: (json['code_iris'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['code_iris'] ?? 'Territoire').toString(),
      status: status,
      ownerClubId: json['ownerClubId'] as String?,
      ownerClubName: json['ownerClubName'] as String?,
      latitude:
          (json['latitude'] as num?)?.toDouble() ??
          (json['centroid_lat'] as num?)?.toDouble() ??
          0,
      longitude:
          (json['longitude'] as num?)?.toDouble() ??
          (json['centroid_lng'] as num?)?.toDouble() ??
          0,
    );
  }

  factory TerritoryModel.fromApi(Map<String, dynamic> json) {
    final ownerClub = json['owner_club'] as Map<String, dynamic>?;
    final statusRaw = (json['status'] ?? 'available').toString();
    final status = switch (statusRaw) {
      'locked' => TerritoryStatus.locked,
      'alert' => TerritoryStatus.alert,
      'conquered' => TerritoryStatus.conquered,
      'conflict' => TerritoryStatus.conflict,
      _ => TerritoryStatus.available,
    };

    final codeIris = (json['code_iris'] ?? json['id'] ?? '').toString();
    final ownerClubId = (json['owner_club_id'] ?? ownerClub?['id'])?.toString();

    return TerritoryModel(
      id: codeIris,
      codeIris: codeIris,
      name: (json['name'] ?? codeIris).toString(),
      status: status,
      ownerClubId: ownerClubId,
      ownerClubName: ownerClub?['name'] as String?,
      latitude:
          (json['centroid_lat'] as num?)?.toDouble() ??
          (json['lat'] as num?)?.toDouble() ??
          (json['latitude'] as num?)?.toDouble() ??
          0,
      longitude:
          (json['centroid_lng'] as num?)?.toDouble() ??
          (json['lng'] as num?)?.toDouble() ??
          (json['longitude'] as num?)?.toDouble() ??
          0,
    );
  }
}
