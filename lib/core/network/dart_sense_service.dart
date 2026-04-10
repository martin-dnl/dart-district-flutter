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

class BatchDetectionResult {
  const BatchDetectionResult({
    required this.darts,
    required this.framesProcessed,
    required this.minOccurrences,
  });

  final List<DetectedDart> darts;
  final int framesProcessed;
  final int minOccurrences;
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

  Future<BatchDetectionResult> detectBatch(
    List<File> imageFiles, {
    int minOccurrences = 2,
    int maxFrames = 24,
  }) async {
    if (imageFiles.isEmpty) {
      return const BatchDetectionResult(
        darts: <DetectedDart>[],
        framesProcessed: 0,
        minOccurrences: 2,
      );
    }

    final files = imageFiles.take(maxFrames).toList(growable: false);
    final formMap = <String, dynamic>{
      'images': <MultipartFile>[],
    };

    for (final image in files) {
      (formMap['images'] as List<MultipartFile>).add(
        await MultipartFile.fromFile(image.path),
      );
    }

    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/dart-sense/detect/batch?min_occurrences=$minOccurrences&max_frames=$maxFrames',
        data: FormData.fromMap(formMap),
      );

      final payload = response.data ?? const <String, dynamic>{};
      final dartsRaw = (payload['darts'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      return BatchDetectionResult(
        darts: dartsRaw.map(DetectedDart.fromJson).toList(growable: false),
        framesProcessed:
            (payload['framesProcessed'] as num?)?.toInt() ?? files.length,
        minOccurrences:
            (payload['minOccurrences'] as num?)?.toInt() ?? minOccurrences,
      );
    } on DioException catch (error) {
      // Backward compatibility: older backends may not expose /detect/batch yet.
      if (error.response?.statusCode == 404 && files.isNotEmpty) {
        final single = await detect(files.last);
        return BatchDetectionResult(
          darts: single,
          framesProcessed: 1,
          minOccurrences: 1,
        );
      }
      rethrow;
    }
  }

  Future<void> submitTrainingFeedback({
    required File imageFile,
    required int zone,
    required int multiplier,
    String source = 'mobile_app',
    String? note,
  }) async {
    final formMap = <String, dynamic>{
      'image': await MultipartFile.fromFile(imageFile.path),
      'zone': zone,
      'multiplier': multiplier,
      'source': source,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };

    await _api.post<Map<String, dynamic>>(
      '/dart-sense/feedback',
      data: FormData.fromMap(formMap),
    );
  }
}
