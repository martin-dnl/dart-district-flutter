import 'package:dio/dio.dart';

class NominatimResult {
  final String displayName;
  final double lat;
  final double lng;

  const NominatimResult({
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}

class NominatimService {
  NominatimService() : _dio = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    headers: {
      'User-Agent': 'DartDistrict/1.0 (contact@dart-district.fr)',
      'Accept': 'application/json',
    },
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  final Dio _dio;

  Future<List<NominatimResult>> searchCity(String query) async {
    if (query.trim().length < 2) return const [];

    final response = await _dio.get<List<dynamic>>('/search', queryParameters: {
      'q': query.trim(),
      'format': 'json',
      'addressdetails': '0',
      'limit': '6',
      'countrycodes': 'fr',
      'accept-language': 'fr',
    });

    final data = response.data;
    if (data == null) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final lat = double.tryParse((item['lat'] ?? '').toString());
          final lng = double.tryParse((item['lon'] ?? '').toString());
          if (lat == null || lng == null) return null;
          return NominatimResult(
            displayName: (item['display_name'] ?? '').toString(),
            lat: lat,
            lng: lng,
          );
        })
        .whereType<NominatimResult>()
        .toList();
  }
}
