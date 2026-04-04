import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/network/nominatim_service.dart';
import '../../club/widgets/club_map_marker.dart';
import '../../club/widgets/club_map_modal.dart';
import '../controller/map_controller.dart';
import '../models/territory_model.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const double _targetVisibleWidthKm = 20;
  static const double _markerMinZoom = 8;
  static const double _cityDefaultZoom = 12;
  static const double _searchResultZoom = 13.5;

  late Future<_TilesetConfig?> _tilesetFuture;
  Future<PmTilesVectorTileProvider>? _vectorProviderFuture;
  LatLng? _currentCenter;
  double? _currentZoom;
  bool _hasInitializedCamera = false;

  // Map controller for programmatic camera movement
  final fm.MapController _fmController = fm.MapController();

  // Geolocation
  LatLng? _userLocation;

  // City search
  final NominatimService _nominatim = NominatimService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  List<NominatimResult> _searchResults = const [];
  bool _showSearchResults = false;
  bool _isSearching = false;

  // Theme caching – avoid rebuilding on every frame
  vtr.Theme? _cachedTheme;
  List<TerritoryModel>? _cachedThemeTerritories;
  String? _cachedThemeLayerName;
  Set<String>? _cachedActiveIrisCodes;

  // Debounced camera tracking – avoids setState storm while panning
  Timer? _cameraDebounce;
  bool _showZones = true;

  @override
  void initState() {
    super.initState();
    _resetTilesetFuture();
    _initUserLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cameraDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _fmController.dispose();
    super.dispose();
  }

  Future<void> _initUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;

      final userLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = userLatLng;
        _currentCenter = userLatLng;
        _currentZoom = _computeZoomForVisibleWidthKm(
          latitude: userLatLng.latitude,
          viewportWidthPx: MediaQuery.sizeOf(context).width,
          widthKm: _targetVisibleWidthKm,
        );
        _hasInitializedCamera = true;
      });

      _fmController.move(userLatLng, _currentZoom ?? _cityDefaultZoom);
    } catch (_) {
      // Geolocation unavailable — keep tileset center as fallback
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = const [];
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await _nominatim.searchCity(query);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _showSearchResults = results.isNotEmpty;
          _isSearching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _isSearching = false);
      }
    });
  }

  void _onSearchResultSelected(NominatimResult result) {
    _searchFocus.unfocus();
    _searchController.text = result.displayName.split(',').first;
    setState(() {
      _showSearchResults = false;
      _searchResults = const [];
    });

    final target = LatLng(result.lat, result.lng);
    _fmController.move(target, _searchResultZoom);
  }

  void _resetTilesetFuture() {
    _tilesetFuture = _loadTilesetConfig();
    _vectorProviderFuture = null;
  }

  void _retryTilesetLoad() {
    setState(() {
      _hasInitializedCamera = false;
      _currentCenter = null;
      _currentZoom = null;
      _resetTilesetFuture();
    });
  }

  double _computeZoomForVisibleWidthKm({
    required double latitude,
    required double viewportWidthPx,
    required double widthKm,
  }) {
    if (viewportWidthPx <= 0 || widthKm <= 0) {
      return _cityDefaultZoom;
    }

    final latRadians = latitude * math.pi / 180;
    final metersPerPixelAtZoom0 =
        156543.03392804097 * math.cos(latRadians).abs();
    final targetMeters = widthKm * 1000;
    final rawZoom =
        math.log((metersPerPixelAtZoom0 * viewportWidthPx) / targetMeters) /
        math.ln2;

    if (rawZoom.isNaN || rawZoom.isInfinite) {
      return _cityDefaultZoom;
    }

    return rawZoom.clamp(4.0, 14.0);
  }

  double _computeVisibleWidthKm({
    required double latitude,
    required double zoom,
    required double viewportWidthPx,
  }) {
    final latRadians = latitude * math.pi / 180;
    final metersPerPixel =
        (156543.03392804097 * math.cos(latRadians).abs()) / math.pow(2, zoom);
    final widthMeters = metersPerPixel * viewportWidthPx;
    return widthMeters / 1000;
  }

  bool _shouldRenderZones(double viewportWidthPx) {
    if (_currentCenter == null || _currentZoom == null) {
      return true;
    }

    final visibleWidthKm = _computeVisibleWidthKm(
      latitude: _currentCenter!.latitude,
      zoom: _currentZoom!,
      viewportWidthPx: viewportWidthPx,
    );

    return visibleWidthKm <= _targetVisibleWidthKm;
  }

  Future<_TilesetConfig?> _loadTilesetConfig() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get<Map<String, dynamic>>(
        '/territories/tileset',
      );
      final payload = _asJsonMap(response.data);
      final data = _asJsonMap(payload?['data']);
      if (data == null) {
        return null;
      }

      final sourceUrl = (data['source_url'] ?? '').toString();
      if (sourceUrl.isEmpty) {
        return null;
      }

      final incomingZoom = _asDouble(data['center_zoom']) ?? _cityDefaultZoom;
      final cityZoom = incomingZoom < 10 ? _cityDefaultZoom : incomingZoom;

      return _TilesetConfig(
        sourceUrl: sourceUrl,
        layerName: (data['layer_name'] ?? 'iris').toString(),
        center: LatLng(
          _asDouble(data['center_lat']) ?? 46.2276,
          _asDouble(data['center_lng']) ?? 2.2137,
        ),
        centerZoom: cityZoom,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolveCodeIrisFromTap(
    LatLng latLng,
    double viewportWidthPx,
  ) async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get<Map<String, dynamic>>(
        '/territories/map/hit',
        queryParameters: {
          'lat': latLng.latitude,
          'lng': latLng.longitude,
          if (_currentZoom != null) 'zoom': _currentZoom,
          'viewport_width_px': viewportWidthPx,
          'active_only': 'true',
        },
      );

      final payload = _asJsonMap(response.data);
      final data = _asJsonMap(payload?['data']);
      final code = (data?['code_iris'] ?? '').toString().trim();
      if (code.isEmpty) {
        return null;
      }

      return code;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleMapTap(
    LatLng latLng,
    List<TerritoryModel> territories,
    double viewportWidthPx,
  ) async {
    final codeIris = await _resolveCodeIrisFromTap(latLng, viewportWidthPx);
    if (codeIris == null || codeIris.isEmpty || !mounted) {
      return;
    }

    ref.read(mapControllerProvider.notifier).selectTerritory(codeIris);
    await _openPanelForTerritoryCode(codeIris);
  }

  List<dynamic> _statusFilter(List<String> codes) {
    return [
      'any',
      ['in', 'code_iris', ...codes],
      ['in', 'CODE_IRIS', ...codes],
      ['in', 'Code_iris', ...codes],
      ['in', 'code', ...codes],
    ];
  }

  /// Only matches features whose code_iris is in the given set of club codes.
  List<dynamic> _clubZonesFilter(Set<String> clubCodes) {
    final codes = clubCodes.toList(growable: false);
    return [
      'any',
      ['in', 'code_iris', ...codes],
      ['in', 'CODE_IRIS', ...codes],
      ['in', 'Code_iris', ...codes],
      ['in', 'code', ...codes],
    ];
  }

  List<String> _sourceLayerCandidates(String preferredLayerName) {
    final candidates = <String>[
      preferredLayerName.trim(),
      'iris',
      'IRIS',
      'contours_iris',
      'iris_france',
    ];

    return candidates
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  vtr.Theme _getOrBuildTheme(
    List<TerritoryModel> territories,
    String layerName,
    Set<String> activeCodes,
  ) {
    // Return cached theme if inputs haven't changed
    if (_cachedTheme != null &&
        _cachedThemeLayerName == layerName &&
        identical(_cachedThemeTerritories, territories) &&
        identical(_cachedActiveIrisCodes, activeCodes)) {
      return _cachedTheme!;
    }
    _cachedTheme = _buildIrisStatusTheme(territories, layerName, activeCodes);
    _cachedThemeTerritories = territories;
    _cachedThemeLayerName = layerName;
    _cachedActiveIrisCodes = activeCodes;
    return _cachedTheme!;
  }

  vtr.Theme _buildIrisStatusTheme(
    List<TerritoryModel> territories,
    String layerName,
    Set<String> activeCodes,
  ) {
    final conquered = territories
        .where((t) => t.status == TerritoryStatus.conquered)
        .map((t) => t.codeIris)
        .toList(growable: false);
    final locked = territories
        .where((t) => t.status == TerritoryStatus.locked)
        .map((t) => t.codeIris)
        .toList(growable: false);
    final conflict = territories
        .where((t) => t.status == TerritoryStatus.conflict)
        .map((t) => t.codeIris)
        .toList(growable: false);
    final alert = territories
        .where((t) => t.status == TerritoryStatus.alert)
        .map((t) => t.codeIris)
        .toList(growable: false);

    final layers = <Map<String, dynamic>>[];
    final sourceLayers = _sourceLayerCandidates(layerName);

    for (final sourceLayer in sourceLayers) {
      // Only render zones that have at least one club associated
      if (activeCodes.isEmpty) continue;
      final baseFilter = _clubZonesFilter(activeCodes);

      // Base: available zones — green, low opacity (maps.jsx "free")
      layers.addAll([
        {
          'id': 'iris-available-fill-$sourceLayer',
          'type': 'fill',
          'source': 'pmtiles',
          'source-layer': sourceLayer,
          'filter': baseFilter,
          'paint': {'fill-color': '#22c55e', 'fill-opacity': 0.28},
        },
        {
          'id': 'iris-border-$sourceLayer',
          'type': 'line',
          'source': 'pmtiles',
          'source-layer': sourceLayer,
          'filter': baseFilter,
          'paint': {
            'line-color': '#22c55e',
            'line-width': 2.0,
            'line-opacity': 0.9,
          },
        },
      ]);

      // Conquered = "mine" — yellow-green #c8ff00
      if (conquered.isNotEmpty) {
        layers.addAll([
          {
            'id': 'iris-conquered-fill-$sourceLayer',
            'type': 'fill',
            'source': 'pmtiles',
            'source-layer': sourceLayer,
            'filter': _statusFilter(conquered),
            'paint': {'fill-color': '#c8ff00', 'fill-opacity': 0.34},
          },
          {
            'id': 'iris-conquered-border-$sourceLayer',
            'type': 'line',
            'source': 'pmtiles',
            'source-layer': sourceLayer,
            'filter': _statusFilter(conquered),
            'paint': {
              'line-color': '#c8ff00',
              'line-width': 2.4,
              'line-opacity': 0.95,
            },
          },
        ]);
      }

      // Locked = "owned" — blue #3b82f6
      if (locked.isNotEmpty) {
        layers.addAll([
          {
            'id': 'iris-locked-fill-$sourceLayer',
            'type': 'fill',
            'source': 'pmtiles',
            'source-layer': sourceLayer,
            'filter': _statusFilter(locked),
            'paint': {'fill-color': '#3b82f6', 'fill-opacity': 0.36},
          },
          {
            'id': 'iris-locked-border-$sourceLayer',
            'type': 'line',
            'source': 'pmtiles',
            'source-layer': sourceLayer,
            'filter': _statusFilter(locked),
            'paint': {
              'line-color': '#3b82f6',
              'line-width': 2.4,
              'line-opacity': 0.95,
            },
          },
        ]);
      }

      // Conflict = "contested" — red #ef4444
      if (conflict.isNotEmpty) {
        layers.addAll([
          {
            'id': 'iris-conflict-fill-$sourceLayer',
            'type': 'fill',
            'source': 'pmtiles',
            'source-layer': sourceLayer,
            'filter': _statusFilter(conflict),
            'paint': {'fill-color': '#ef4444', 'fill-opacity': 0.42},
          },
          {
            'id': 'iris-conflict-border-$sourceLayer',
            'type': 'line',
            'source': 'pmtiles',
            'source-layer': sourceLayer,
            'filter': _statusFilter(conflict),
            'paint': {
              'line-color': '#ef4444',
              'line-width': 2.8,
              'line-opacity': 1.0,
            },
          },
        ]);
      }

      // Alert — bright red #ff6b6b
      if (alert.isNotEmpty) {
        layers.addAll([
          {
            'id': 'iris-alert-fill-$sourceLayer',
            'type': 'fill',
            'source': 'pmtiles',
            'source-layer': sourceLayer,
            'filter': _statusFilter(alert),
            'paint': {'fill-color': '#ff6b6b', 'fill-opacity': 0.46},
          },
          {
            'id': 'iris-alert-border-$sourceLayer',
            'type': 'line',
            'source': 'pmtiles',
            'source-layer': sourceLayer,
            'filter': _statusFilter(alert),
            'paint': {
              'line-color': '#ff6b6b',
              'line-width': 2.8,
              'line-opacity': 1.0,
            },
          },
        ]);
      }
    }

    final style = <String, dynamic>{
      'id': 'iris-status-theme',
      'metadata': {'version': '1'},
      'layers': layers,
    };

    return vtr.ThemeReader().read(style);
  }

  Color _statusColor(String status) {
    return switch (status) {
      'conquered' => const Color(0xFFC8FF00),
      'locked' => const Color(0xFF3B82F6),
      'conflict' => const Color(0xFFEF4444),
      'alert' => const Color(0xFFFF6B6B),
      _ => const Color(0xFF22C55E),
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'conquered' => Icons.shield,
      'locked' => Icons.lock,
      'conflict' => Icons.flash_on,
      'alert' => Icons.warning_amber,
      _ => Icons.lock_open,
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'conquered' => 'Notre zone',
      'locked' => 'Conquise',
      'conflict' => 'En guerre',
      'alert' => 'Alerte',
      _ => 'Zone libre',
    };
  }

  Future<void> _openPanelForTerritoryCode(String codeIris) async {
    Map<String, dynamic>? territory;
    Map<String, dynamic>? activeDuel;
    List<Map<String, dynamic>> latestEvents = const [];

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get<Map<String, dynamic>>(
        '/territories/$codeIris/panel',
      );
      final panelData = response.data?['data'] as Map<String, dynamic>?;
      if (panelData != null) {
        territory = panelData['territory'] as Map<String, dynamic>?;
        activeDuel = panelData['active_duel'] as Map<String, dynamic>?;
        latestEvents =
            (panelData['latest_events'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .toList();
      }
    } catch (_) {
      territory = null;
    }

    if (!mounted) {
      return;
    }

    final territoryData = territory ?? <String, dynamic>{
      'code_iris': codeIris,
      'name': 'Territoire $codeIris',
      'status': 'available',
      'points_value': '–',
    };

    final status = (territoryData['status'] ?? 'available').toString();
    final ownerClub = territoryData['owner_club'] as Map<String, dynamic>?;
    final statusClr = _statusColor(status);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    // Header row: icon + name/status + points
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: statusClr.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _statusIcon(status),
                            color: statusClr,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (territoryData['name'] ??
                                  territoryData['code_iris'] ??
                                        codeIris)
                                    .toString(),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Code IRIS: $codeIris',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusClr.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _statusIcon(status),
                                      size: 12,
                                      color: statusClr,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _statusLabel(status),
                                      style: TextStyle(
                                        color: statusClr,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              (territoryData['points_value'] ?? '–').toString(),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'points',
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Owner club info
                    if (ownerClub != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                (ownerClub['name'] ?? '?')
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (ownerClub['name'] ?? '').toString(),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Text(
                                    'Club propriétaire',
                                    style: TextStyle(
                                      color: AppColors.textHint,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (status == 'conflict' || status == 'alert')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'DÉFI EN COURS',
                                  style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      activeDuel == null
                          ? 'Aucun duel actif'
                          : 'Duel actif: ${(activeDuel['status'] ?? 'pending')}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    if (latestEvents.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${latestEvents.length} événement(s) récent(s)',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapControllerProvider);
    final territoriesToRender = mapState.activeIrisCodes.isEmpty
        ? mapState.territories
        : mapState.territories
              .where((t) => mapState.activeIrisCodes.contains(t.codeIris))
              .toList();
    final viewportWidthPx = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<_TilesetConfig?>(
        future: _tilesetFuture,
        builder: (context, configSnapshot) {
          final config = configSnapshot.data;
          if (config == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tileset PMTiles indisponible',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _retryTilesetLoad,
                    child: const Text('Reessayer'),
                  ),
                ],
              ),
            );
          }

          if (!_hasInitializedCamera) {
            _currentCenter = config.center;
            _currentZoom = _computeZoomForVisibleWidthKm(
              latitude: config.center.latitude,
              viewportWidthPx: viewportWidthPx,
              widthKm: _targetVisibleWidthKm,
            );
            _hasInitializedCamera = true;
          }

          final initialCenter = _currentCenter ?? config.center;
          final initialZoom = _currentZoom ?? config.centerZoom;
          _showZones = _shouldRenderZones(viewportWidthPx);

          _vectorProviderFuture ??= PmTilesVectorTileProvider.fromSource(
            config.sourceUrl,
          );

          return FutureBuilder<PmTilesVectorTileProvider>(
            future: _vectorProviderFuture,
            builder: (context, providerSnapshot) {
              if (providerSnapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              final provider = providerSnapshot.data;
              if (provider == null) {
                return const Center(
                  child: Text(
                    'Impossible de charger le provider PMTiles',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return Stack(
                children: [
                  fm.FlutterMap(
                    mapController: _fmController,
                    options: fm.MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: initialZoom,
                      minZoom: 4,
                      maxZoom: 18,
                      onPositionChanged: (position, hasGesture) {
                        // Track center/zoom without rebuilding widget tree.
                        _currentCenter = position.center;
                        _currentZoom = position.zoom;

                        // Debounce the setState to 150ms so we don't
                        // rebuild on every single pan frame.
                        _cameraDebounce?.cancel();
                        _cameraDebounce = Timer(
                          const Duration(milliseconds: 150),
                          () {
                            if (!mounted) return;
                            final shouldShow = _shouldRenderZones(
                              viewportWidthPx,
                            );
                            if (shouldShow != _showZones) {
                              setState(() => _showZones = shouldShow);
                            }
                          },
                        );
                      },
                      onTap: (_, latLng) {
                        // Dismiss search dropdown on map tap
                        if (_showSearchResults) {
                          setState(() => _showSearchResults = false);
                          _searchFocus.unfocus();
                          return;
                        }
                        if (!_showZones) {
                          return;
                        }
                        _handleMapTap(
                          latLng,
                          territoriesToRender,
                          viewportWidthPx,
                        );
                      },
                    ),
                    children: [
                      fm.TileLayer(
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'fr.dartdistrict.app',
                        tileDisplay: const fm.TileDisplay.fadeIn(),
                      ),
                      if (_showZones && mapState.activeIrisCodes.isNotEmpty)
                        VectorTileLayer(
                          theme: _getOrBuildTheme(
                            territoriesToRender,
                            config.layerName,
                            mapState.activeIrisCodes,
                          ),
                          tileProviders: TileProviders({'pmtiles': provider}),
                          layerMode: VectorTileLayerMode.vector,
                        ),
                      if ((_currentZoom ?? initialZoom) >= _markerMinZoom)
                        fm.MarkerLayer(
                          markers: mapState.clubMarkers.map((club) {
                          final lat = _asDouble(club['latitude']);
                          final lng = _asDouble(club['longitude']);
                          if (lat == null || lng == null) {
                            return null;
                          }

                          return fm.Marker(
                            point: LatLng(lat, lng),
                            width: 36,
                            height: 36,
                            child: Center(
                              child: GestureDetector(
                                onTap: () => ClubMapModal.show(
                                  context,
                                  clubId: (club['id'] ?? '').toString(),
                                  name: (club['name'] ?? 'Club').toString(),
                                  address: (club['address'] ??
                                          [
                                            club['city']?.toString(),
                                            club['code_iris']?.toString(),
                                          ].whereType<String>().where((e) => e.isNotEmpty).join(' - '))
                                      .toString(),
                                  city: club['city']?.toString(),
                                ),
                                child: const ClubMapMarker(),
                              ),
                            ),
                          );
                        }).whereType<fm.Marker>().toList(),
                        ),
                    ],
                  ),
                  // City search bar (top)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.card.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.surfaceLight),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                const Icon(
                                  Icons.search,
                                  color: AppColors.textHint,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocus,
                                    onChanged: _onSearchChanged,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Rechercher une ville...',
                                      hintStyle: TextStyle(
                                        color: AppColors.textHint,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_isSearching)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                else if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: AppColors.textHint,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                  ),
                                // My-location button
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.my_location,
                                      color: _userLocation != null
                                          ? AppColors.primary
                                          : AppColors.textHint,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      if (_userLocation != null) {
                                        _fmController.move(
                                          _userLocation!,
                                          _searchResultZoom,
                                        );
                                      } else {
                                        _initUserLocation();
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Search results dropdown
                          if (_showSearchResults && _searchResults.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              constraints: const BoxConstraints(maxHeight: 240),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.surfaceLight,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _searchResults.length,
                                  separatorBuilder: (context2, index2) =>
                                      Divider(
                                        height: 1,
                                        color: AppColors.surfaceLight
                                            .withValues(alpha: 0.5),
                                      ),
                                  itemBuilder: (context, index) {
                                    final result = _searchResults[index];
                                    final parts = result.displayName.split(',');
                                    final city = parts.first.trim();
                                    final region = parts.length > 1
                                        ? parts.sublist(1).join(',').trim()
                                        : '';
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.location_on_outlined,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                      title: Text(
                                        city,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: region.isNotEmpty
                                          ? Text(
                                              region,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textHint,
                                                fontSize: 11,
                                              ),
                                            )
                                          : null,
                                      onTap: () =>
                                          _onSearchResultSelected(result),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Stats bar (top-left, shifted down to make room for search)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.only(left: 12, top: 68),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.card.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MES TERRITOIRES',
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _StatChip(
                                  count: territoriesToRender
                                      .where(
                                        (t) =>
                                            t.status ==
                                            TerritoryStatus.conquered,
                                      )
                                      .length,
                                  label: 'conquis',
                                  color: const Color(0xFFC8FF00),
                                ),
                                const SizedBox(width: 10),
                                _StatChip(
                                  count: territoriesToRender
                                      .where(
                                        (t) =>
                                            t.status ==
                                                TerritoryStatus.conflict ||
                                            t.status == TerritoryStatus.alert,
                                      )
                                      .length,
                                  label: 'en guerre',
                                  color: const Color(0xFFEF4444),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Legend bar (bottom)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.only(
                          bottom: 12,
                          left: 12,
                          right: 12,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.card.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: const [
                            _LegendItem(
                              color: Color(0xFF22C55E),
                              label: 'Disponible',
                              dashed: true,
                            ),
                            _LegendItem(
                              color: Color(0xFFC8FF00),
                              label: 'Notre zone',
                            ),
                            _LegendItem(
                              color: Color(0xFF3B82F6),
                              label: 'Conquise',
                            ),
                            _LegendItem(
                              color: Color(0xFFEF4444),
                              label: 'En guerre',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!_showZones)
                    SafeArea(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.card.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.surfaceLight),
                          ),
                          child: const Text(
                            'Zoomez pour afficher les zones (largeur <= 5 km)',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (mapState.isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

Map<String, dynamic>? _asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }

  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    return _asJsonMap(decoded);
  }

  return null;
}

double? _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}

class _TilesetConfig {
  const _TilesetConfig({
    required this.sourceUrl,
    required this.layerName,
    required this.center,
    required this.centerZoom,
  });

  final String sourceUrl;
  final String layerName;
  final LatLng center;
  final double centerZoom;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: color,
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.count,
    required this.label,
    required this.color,
  });

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$count ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          TextSpan(
            text: label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
