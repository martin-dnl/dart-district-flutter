import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../models/match_report_data.dart';

final matchReportProvider = FutureProvider.family<MatchReportData, String>((
  ref,
  matchId,
) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>(
    '/matches/$matchId/report',
  );
  final data =
      (response.data?['data'] as Map<String, dynamic>?) ??
      response.data ??
      const <String, dynamic>{};
  return MatchReportData.fromApi(data);
});
