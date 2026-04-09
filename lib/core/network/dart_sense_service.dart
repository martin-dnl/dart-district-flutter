import 'dart:io';

import 'package:dio/dio.dart';

import 'api_client.dart';

class DetectedDart {
  const DetectedDart({
    required this.zone,
    required this.multiplier,
    required this.confidence,
    required this.x,
    required this.y,
  });

  final int zone;
  final int multiplier;
  final double confidence;
  final double x;
  final double y;

  factory DetectedDart.fromJson(Map<String, dynamic> json) {
    return DetectedDart(
      zone: (json['zone'] as num?)?.toInt() ?? 0,
      multiplier: (json['multiplier'] as num?)?.toInt() ?? 1,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
    );
  }

  String get label {
    if (zone <= 0) {
      return '-';
    }
    if (zone == 25) {
      return multiplier >= 2 ? 'DB' : 'SB';
    }
    final prefix = switch (multiplier) {
      3 => 'T',
      2 => 'D',
      _ => 'S',
    };
    return '$prefix$zone';
  }

  int get score {
    if (zone <= 0) {
      return 0;
    }
    if (zone == 25) {
      return multiplier >= 2 ? 50 : 25;
    }
    return zone * multiplier;
  }
}

class DartSenseApiService {
  const DartSenseApiService(this._api);

  final ApiClient _api;

  Future<List<DetectedDart>> detect(File imageFile) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imageFile.path),
    });

    final response = await _api.post<Map<String, dynamic>>(
      '/dart-sense/detect',
      data: formData,
    );

    final payload = response.data ?? const <String, dynamic>{};
    final data =
        (payload['data'] as Map<String, dynamic>?) ?? payload;
    final rows = (data['darts'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>();

    return rows.map(DetectedDart.fromJson).toList(growable: false);
  }
}
