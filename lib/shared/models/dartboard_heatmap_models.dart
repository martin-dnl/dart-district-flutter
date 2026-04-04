class DartboardHeatHit {
  const DartboardHeatHit({
    required this.x,
    required this.y,
    this.score,
    this.label,
    this.matchId,
    this.playedAt,
  });

  final double x;
  final double y;
  final int? score;
  final String? label;
  final String? matchId;
  final DateTime? playedAt;

  bool get hasValidPosition =>
      x.isFinite && y.isFinite && x >= 0 && x <= 1 && y >= 0 && y <= 1;

  factory DartboardHeatHit.fromJson(Map<String, dynamic> json) {
    return DartboardHeatHit(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      score: (json['score'] as num?)?.toInt(),
      label: json['label']?.toString(),
      matchId: json['match_id']?.toString(),
      playedAt: DateTime.tryParse((json['played_at'] ?? '').toString()),
    );
  }
}

class DartboardHeatmapData {
  const DartboardHeatmapData({
    this.period = 'all',
    this.year,
    this.month,
    this.totalThrows = 0,
    this.totalHits = 0,
    this.hits = const [],
  });

  final String period;
  final int? year;
  final int? month;
  final int totalThrows;
  final int totalHits;
  final List<DartboardHeatHit> hits;

  bool get hasHits => hits.any((hit) => hit.hasValidPosition);

  factory DartboardHeatmapData.fromJson(Map<String, dynamic> json) {
    final rawHits = (json['hits'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(DartboardHeatHit.fromJson)
        .where((hit) => hit.hasValidPosition)
        .toList(growable: false);

    return DartboardHeatmapData(
      period: (json['period'] ?? 'all').toString(),
      year: (json['year'] as num?)?.toInt(),
      month: (json['month'] as num?)?.toInt(),
      totalThrows: (json['total_throws'] as num?)?.toInt() ?? 0,
      totalHits: (json['total_hits'] as num?)?.toInt() ?? rawHits.length,
      hits: rawHits,
    );
  }
}

class DartboardHeatmapYear {
  const DartboardHeatmapYear({required this.year, required this.months});

  final int year;
  final List<int> months;

  factory DartboardHeatmapYear.fromJson(Map<String, dynamic> json) {
    return DartboardHeatmapYear(
      year: (json['year'] as num?)?.toInt() ?? 0,
      months: (json['months'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<num>()
          .map((month) => month.toInt())
          .where((month) => month >= 1 && month <= 12)
          .toList(growable: false),
    );
  }
}

class DartboardHeatmapPeriods {
  const DartboardHeatmapPeriods({this.years = const []});

  final List<DartboardHeatmapYear> years;

  bool get hasData => years.isNotEmpty;

  factory DartboardHeatmapPeriods.fromJson(Map<String, dynamic> json) {
    return DartboardHeatmapPeriods(
      years: (json['years'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(DartboardHeatmapYear.fromJson)
          .where((entry) => entry.year > 0)
          .toList(growable: false),
    );
  }
}
