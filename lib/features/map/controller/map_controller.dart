import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/app_constants.dart';
import '../../../core/network/api_providers.dart';
import '../models/territory_model.dart';

class MapState {
  final List<TerritoryModel> territories;
  final List<Map<String, dynamic>> clubRanking;
  final List<Map<String, dynamic>> clubMarkers;
  final Set<String> clubZoneCodes;
  final Set<String> activeIrisCodes;
  final bool isLoading;
  final String? selectedTerritoryId;

  const MapState({
    this.territories = const [],
    this.clubRanking = const [],
    this.clubMarkers = const [],
    this.clubZoneCodes = const <String>{},
    this.activeIrisCodes = const <String>{},
    this.isLoading = false,
    this.selectedTerritoryId,
  });

  MapState copyWith({
    List<TerritoryModel>? territories,
    List<Map<String, dynamic>>? clubRanking,
    List<Map<String, dynamic>>? clubMarkers,
    Set<String>? clubZoneCodes,
    Set<String>? activeIrisCodes,
    bool? isLoading,
    String? selectedTerritoryId,
  }) {
    return MapState(
      territories: territories ?? this.territories,
      clubRanking: clubRanking ?? this.clubRanking,
      clubMarkers: clubMarkers ?? this.clubMarkers,
      clubZoneCodes: clubZoneCodes ?? this.clubZoneCodes,
      activeIrisCodes: activeIrisCodes ?? this.activeIrisCodes,
      isLoading: isLoading ?? this.isLoading,
      selectedTerritoryId: selectedTerritoryId ?? this.selectedTerritoryId,
    );
  }
}

class MapController extends StateNotifier<MapState> {
  MapController(this._ref) : super(const MapState()) {
    _loadTerritories();
    _connectTerritorySocket();
  }

  final Ref _ref;
  io.Socket? _socket;

  List<Map<String, dynamic>> _extractMapList(dynamic payload) {
    if (payload is List) {
      return payload.whereType<Map>().map((row) {
        return row.map((key, value) => MapEntry(key.toString(), value));
      }).toList(growable: false);
    }

    if (payload is Map) {
      final mapped = payload.map((key, value) => MapEntry(key.toString(), value));
      final data = mapped['data'];
      if (data is List) {
        return data.whereType<Map>().map((row) {
          return row.map((key, value) => MapEntry(key.toString(), value));
        }).toList(growable: false);
      }
    }

    return const <Map<String, dynamic>>[];
  }

  Future<void> _loadTerritories() async {
    state = state.copyWith(isLoading: true);

    try {
      final api = _ref.read(apiClientProvider);
      
      // Load all map data at once: territories with statuses and club rankings
      final response = await api.get<Map<String, dynamic>>(
        '/territories/map/data',
      );
      final clubZonesResponse = await api.get<Map<String, dynamic>>(
        '/territories/clubs/zones',
      );
      final clubsMapResponse = await api.get<dynamic>('/clubs/map');
      // ignore: avoid_print
      print('[MapController] /clubs/map raw response type: ${clubsMapResponse.data.runtimeType}');
      final activeZonesResponse = await api.get<Map<String, dynamic>>(
        '/territories/tileset/active-zones',
      );

      final responseData =
          response.data?['data'] as Map<String, dynamic>? ?? <String, dynamic>{};

      // Parse territories with their complete info (status, owner_club, etc.)
      final territoriesData =
          (responseData['territories'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(TerritoryModel.fromApi)
              .toList();

      // Normalize ranking payload for existing UI widget expectations.
      final rankingData =
          (responseData['clubs'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
            .toList()
              .asMap()
              .entries
              .map((entry) {
                final club = entry.value;
                final conquered = (club['conquered_count'] as num?)?.toInt() ?? 0;
                final locked = (club['locked_count'] as num?)?.toInt() ?? 0;
                final conflict = (club['conflict_count'] as num?)?.toInt() ?? 0;

                return <String, dynamic>{
                  ...club,
                  'rank': entry.key + 1,
                  'conquest_points': conquered * 3 + locked * 2 + conflict,
                };
              })
              .toList();

            final clubZonesData =
              (clubZonesResponse.data?['data']?['zones'] as List<dynamic>? ??
                  clubZonesResponse.data?['zones'] as List<dynamic>? ??
                  <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .toList();

            final clubZoneCodes = clubZonesData
              .map((zone) => (zone['code_iris'] ?? '').toString())
              .where((code) => code.isNotEmpty)
              .toSet();

      final clubMarkers = _extractMapList(clubsMapResponse.data);

      // Debug: log club markers and active codes
      // ignore: avoid_print
      print('[MapController] clubMarkers count: ${clubMarkers.length}');
      for (final c in clubMarkers) {
        // ignore: avoid_print
        print('[MapController] club: id=${c['id']}, name=${c['name']}, lat=${c['latitude']}, lng=${c['longitude']}, code_iris=${c['code_iris']}');
      }

      final activeCodesData =
          (activeZonesResponse.data?['data']?['codes'] as List<dynamic>? ??
                  activeZonesResponse.data?['codes'] as List<dynamic>? ??
                  <dynamic>[])
              .map((item) => item.toString().trim().toUpperCase())
              .where((code) => code.isNotEmpty)
              .toSet();

      // ignore: avoid_print
      print('[MapController] activeIrisCodes count: ${activeCodesData.length}, codes: $activeCodesData');

      state = state.copyWith(
        isLoading: false,
        territories: territoriesData,
        clubRanking: rankingData,
            clubMarkers: clubMarkers,
            clubZoneCodes: clubZoneCodes,
            activeIrisCodes: activeCodesData,
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('[MapController] _loadTerritories ERROR: $e\n$st');
      state = state.copyWith(isLoading: false, territories: const []);
    }
  }

  void _connectTerritorySocket() {
    final namespaceUrl = _territoryNamespaceUrl();

    _socket = io.io(
      namespaceUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionAttempts(8)
          .setReconnectionDelay(1500)
          .build(),
    );

    _socket?.onConnect((_) {
      _socket?.emit('subscribe_map');
    });

    _socket?.on('territory_status_updated', _onTerritoryDelta);
    _socket?.on('territory_owner_updated', _onTerritoryDelta);
    _socket?.on('map_update', _onTerritoryDelta);
    _socket?.onConnectError((_) {});
    _socket?.connect();
  }

  String _territoryNamespaceUrl() {
    final wsUrl = Uri.parse(AppConstants.wsBaseUrl);
    final httpScheme = wsUrl.scheme == 'wss' ? 'https' : 'http';
    final host = wsUrl.host;
    final port = wsUrl.hasPort ? ':${wsUrl.port}' : '';
    return '$httpScheme://$host$port/ws/territory';
  }

  void _onTerritoryDelta(dynamic payload) {
    if (payload is! Map) {
      return;
    }

    final map = payload.map((key, value) => MapEntry(key.toString(), value));
    final codeIris = (map['code_iris'] ?? map['territory_id'] ?? '').toString();
    if (codeIris.isEmpty) {
      return;
    }

    final nextStatus = (map['status'] ?? '').toString();
    final nextOwnerClubId = map['owner_club_id']?.toString();

    final updated = state.territories.map((territory) {
      if (territory.codeIris != codeIris) {
        return territory;
      }

      final status = switch (nextStatus) {
        'locked' => TerritoryStatus.locked,
        'alert' => TerritoryStatus.alert,
        'conquered' => TerritoryStatus.conquered,
        'conflict' => TerritoryStatus.conflict,
        'available' => TerritoryStatus.available,
        _ => territory.status,
      };

      return TerritoryModel.fromJson({
        'id': territory.id,
        'code_iris': territory.codeIris,
        'name': territory.name,
        'status': status.name,
        'ownerClubId': nextOwnerClubId ?? territory.ownerClubId,
        'ownerClubName': territory.ownerClubName,
        'latitude': territory.latitude,
        'longitude': territory.longitude,
      });
    }).toList();

    state = state.copyWith(territories: updated);
  }

  void selectTerritory(String id) {
    state = state.copyWith(selectedTerritoryId: id);
  }

  void clearSelection() {
    state = state.copyWith(selectedTerritoryId: null);
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}

final mapControllerProvider = StateNotifierProvider<MapController, MapState>((
  ref,
) {
  return MapController(ref);
});
