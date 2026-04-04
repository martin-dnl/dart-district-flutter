import 'package:dio/dio.dart';

import '../config/app_constants.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;
}

class OpeningPeriod {
  const OpeningPeriod({required this.open, required this.close});

  final String open;
  final String close;

  Map<String, String> toJson() => {'open': open, 'close': close};
}

class PlaceDetails {
  const PlaceDetails({
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.city,
    this.postalCode,
    this.country,
    this.openingHours = const <String, OpeningPeriod>{},
  });

  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? city;
  final String? postalCode;
  final String? country;
  final Map<String, OpeningPeriod> openingHours;
}

class GooglePlacesService {
  GooglePlacesService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: 'https://places.googleapis.com/v1',
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
          headers: const {'Content-Type': 'application/json'},
        ),
      );

  final Dio _dio;

  Future<List<PlaceSuggestion>> autocomplete(String query) async {
    final apiKey = AppConstants.googlePlacesApiKey;
    final input = query.trim();
    if (apiKey == null || apiKey.isEmpty || input.length < 3) {
      return const [];
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/places:autocomplete',
        data: {
          'input': input,
          'includedPrimaryTypes': const [
            'bar',
            'restaurant',
            'establishment',
            'sports_complex',
            'bowling_alley',
          ],
          'languageCode': 'fr',
        },
        options: Options(headers: {'X-Goog-Api-Key': apiKey}),
      );

      final payload = response.data ?? <String, dynamic>{};
      final suggestions =
          (payload['suggestions'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>();

      return suggestions
          .map((item) => item['placePrediction'])
          .whereType<Map<String, dynamic>>()
          .map((prediction) {
            final placeId = (prediction['placeId'] ?? '').toString();
            if (placeId.isEmpty) {
              return null;
            }

            final text =
                (prediction['text'] as Map<String, dynamic>? ??
                    const <String, dynamic>{});
            final structured =
                (prediction['structuredFormat'] as Map<String, dynamic>? ??
                    const <String, dynamic>{});

            final mainText =
                (structured['mainText']?['text'] ?? text['text'] ?? '')
                    .toString()
                    .trim();
            final secondaryText =
                (structured['secondaryText']?['text'] ?? '').toString().trim();

            return PlaceSuggestion(
              placeId: placeId,
              mainText: mainText.isEmpty ? 'Lieu' : mainText,
              secondaryText: secondaryText,
            );
          })
          .whereType<PlaceSuggestion>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final apiKey = AppConstants.googlePlacesApiKey;
    final id = placeId.trim();
    if (apiKey == null || apiKey.isEmpty || id.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/places/$id',
        options: Options(
          headers: {
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask':
                'displayName,formattedAddress,location,addressComponents,regularOpeningHours',
          },
        ),
      );

      final data = response.data ?? <String, dynamic>{};
      final location =
          (data['location'] as Map<String, dynamic>? ??
              const <String, dynamic>{});
      final latitude = (location['latitude'] as num?)?.toDouble();
      final longitude = (location['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        return null;
      }

      final addressComponents =
          (data['addressComponents'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);

      String? city;
      String? postalCode;
      String? country;
      for (final component in addressComponents) {
        final types =
            (component['types'] as List<dynamic>? ?? const <dynamic>[])
                .map((type) => type.toString())
                .toList(growable: false);

        final value = (component['longText'] ?? component['shortText'] ?? '')
            .toString()
            .trim();
        if (value.isEmpty) {
          continue;
        }

        if (city == null && types.contains('locality')) {
          city = value;
        }
        if (postalCode == null && types.contains('postal_code')) {
          postalCode = value;
        }
        if (country == null && types.contains('country')) {
          country = value;
        }
      }

      return PlaceDetails(
        name: (data['displayName']?['text'] ?? '').toString().trim(),
        formattedAddress: (data['formattedAddress'] ?? '').toString().trim(),
        latitude: latitude,
        longitude: longitude,
        city: city,
        postalCode: postalCode,
        country: country,
        openingHours: _parseOpeningHours(data['regularOpeningHours']),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, OpeningPeriod> _parseOpeningHours(dynamic raw) {
    final regular = raw as Map<String, dynamic>?;
    final periods =
        (regular?['periods'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    final result = <String, OpeningPeriod>{};
    for (final period in periods) {
      final open = period['open'] as Map<String, dynamic>?;
      final close = period['close'] as Map<String, dynamic>?;
      if (open == null || close == null) {
        continue;
      }

      final openDay = _googleDayToKey((open['day'] as num?)?.toInt());
      final closeDay = _googleDayToKey((close['day'] as num?)?.toInt());
      if (openDay == null || closeDay == null || openDay != closeDay) {
        continue;
      }

      final openTime = _formatGoogleTime(open['hour'], open['minute']);
      final closeTime = _formatGoogleTime(close['hour'], close['minute']);
      if (openTime == null || closeTime == null) {
        continue;
      }

      result[openDay] = OpeningPeriod(open: openTime, close: closeTime);
    }

    return result;
  }

  String? _googleDayToKey(int? day) {
    return switch (day) {
      1 => 'monday',
      2 => 'tuesday',
      3 => 'wednesday',
      4 => 'thursday',
      5 => 'friday',
      6 => 'saturday',
      0 => 'sunday',
      _ => null,
    };
  }

  String? _formatGoogleTime(dynamic hourRaw, dynamic minuteRaw) {
    final hour = (hourRaw as num?)?.toInt();
    final minute = (minuteRaw as num?)?.toInt();
    if (hour == null || minute == null) {
      return null;
    }

    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
