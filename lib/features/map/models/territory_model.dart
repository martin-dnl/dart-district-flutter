enum TerritoryStatus { available, locked, alert, conquered, conflict }

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

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
          _asDouble(json['latitude']) != 0
            ? _asDouble(json['latitude'])
            : _asDouble(json['centroid_lat']),
      longitude:
          _asDouble(json['longitude']) != 0
            ? _asDouble(json['longitude'])
            : _asDouble(json['centroid_lng']),
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
          _asDouble(json['centroid_lat']) != 0
            ? _asDouble(json['centroid_lat'])
            : (_asDouble(json['lat']) != 0
              ? _asDouble(json['lat'])
              : _asDouble(json['latitude'])),
      longitude:
          _asDouble(json['centroid_lng']) != 0
            ? _asDouble(json['centroid_lng'])
            : (_asDouble(json['lng']) != 0
              ? _asDouble(json['lng'])
              : _asDouble(json['longitude'])),
    );
  }
}
