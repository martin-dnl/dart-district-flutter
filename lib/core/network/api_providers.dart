import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'google_places_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final googlePlacesServiceProvider = Provider<GooglePlacesService>((ref) {
  return GooglePlacesService();
});
