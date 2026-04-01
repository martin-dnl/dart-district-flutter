import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_providers.dart';
import 'app_version_service.dart';

final appVersionServiceProvider = Provider<AppVersionService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AppVersionService(apiClient);
});
