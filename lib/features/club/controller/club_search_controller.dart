import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../models/club_model.dart';

class ClubSearchState {
  final List<ClubModel> results;
  final bool isLoading;
  final String? query;
  final String? error;

  const ClubSearchState({
    this.results = const [],
    this.isLoading = false,
    this.query,
    this.error,
  });

  ClubSearchState copyWith({
    List<ClubModel>? results,
    bool? isLoading,
    String? query,
    String? error,
  }) {
    return ClubSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
      error: error,
    );
  }
}

class ClubSearchController extends StateNotifier<ClubSearchState> {
  ClubSearchController(this._ref) : super(const ClubSearchState());

  final Ref _ref;
  Timer? _debounce;

  void searchByText(String query) {
    final trimmed = query.trim();

    _debounce?.cancel();

    if (trimmed.isEmpty) {
      state = state.copyWith(
        results: const [],
        isLoading: false,
        query: '',
        error: null,
      );
      return;
    }

    state = state.copyWith(isLoading: true, query: trimmed, error: null);

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      await _search(query: trimmed);
    });
  }

  Future<void> searchByTextNow(String query) async {
    final trimmed = query.trim();
    _debounce?.cancel();

    if (trimmed.isEmpty) {
      state = state.copyWith(
        results: const [],
        isLoading: false,
        query: '',
        error: null,
      );
      return;
    }

    await _search(query: trimmed);
  }

  Future<void> searchNearby(
    double lat,
    double lng, {
    int limit = 10,
    double? radiusKm,
  }) async {
    await _search(
      query: (state.query ?? '').trim().isEmpty ? null : state.query,
      lat: lat,
      lng: lng,
      limit: limit,
      radiusKm: radiusKm,
    );
  }

  void clear() {
    _debounce?.cancel();
    state = const ClubSearchState();
  }

  Future<void> loadInitial() async {
    if (state.isLoading) {
      return;
    }
    await _search(limit: 10);
  }

  Future<void> _search({
    String? query,
    double? lat,
    double? lng,
    int? limit,
    double? radiusKm,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      query: query ?? state.query,
    );

    try {
      final api = _ref.read(apiClientProvider);
      final queryParameters = <String, dynamic>{
        'q': query?.trim(),
        'lat': lat,
        'lng': lng,
        'radius': radiusKm,
        'limit': limit ?? 10,
      };
      queryParameters.removeWhere(
        (_, value) =>
            value == null || (value is String && value.trim().isEmpty),
      );

      final response = await api.get<dynamic>(
        '/clubs/search',
        queryParameters: queryParameters,
      );

      final payload = response.data;
      final rawList = switch (payload) {
        Map<String, dynamic> map => map['data'],
        List<dynamic> list => list,
        _ => null,
      };

      final data = (rawList as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();

      state = state.copyWith(
        isLoading: false,
        results: data.map(ClubModel.fromApi).toList(),
        error: null,
      );
    } catch (e, stack) {
      debugPrint('Club search error: $e\n$stack');
      state = state.copyWith(
        isLoading: false,
        results: const [],
        error: 'Impossible de rechercher des clubs.',
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final clubSearchControllerProvider =
    StateNotifierProvider<ClubSearchController, ClubSearchState>((ref) {
      return ClubSearchController(ref);
    });
