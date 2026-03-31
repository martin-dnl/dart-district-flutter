import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/app_constants.dart';
import '../../../core/network/api_providers.dart';
import '../models/territory_model.dart';

class MapState {
  final List<TerritoryModel> territories;
  final List<Map<String, dynamic>> clubRanking;
  final bool isLoading;
  final String? selectedTerritoryId;

  const MapState({
    this.territories = const [],
    this.clubRanking = const [],
    this.isLoading = false,
    this.selectedTerritoryId,
  });

  MapState copyWith({
    List<TerritoryModel>? territories,
    List<Map<String, dynamic>>? clubRanking,
    bool? isLoading,
    String? selectedTerritoryId,
  }) {
    return MapState(
      territories: territories ?? this.territories,
      clubRanking: clubRanking ?? this.clubRanking,
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

  Future<void> _loadTerritories() async {
    state = state.copyWith(isLoading: true);

    try {
      final api = _ref.read(apiClientProvider);
      
      // Load all map data at once: territories with statuses and club rankings
      final response = await api.get<Map<String, dynamic>>(
        '/territories/map/data',
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

      state = state.copyWith(
        isLoading: false,
        territories: territoriesData,
        clubRanking: rankingData,
      );
    } catch (_) {
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
    state = MapState(
      territories: state.territories,
      isLoading: state.isLoading,
    );
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
