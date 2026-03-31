# Flutter Map + PMTiles + IRIS Integration

Cette page fournit une integration prete a brancher avec:
- flutter_map
- vector_map_tiles
- vector_map_tiles_pmtiles
- API backend territories
- WebSocket /ws/territory

## 1) Dependencies pubspec.yaml

Ajoute dans dependencies:

flutter_map: ^7.0.2
vector_map_tiles: ^8.0.0
vector_map_tiles_pmtiles: ^1.5.0
latlong2: ^0.9.1

Puis:

flutter pub get

## 2) Backend endpoints utilises

- GET /api/v1/territories/tileset
- GET /api/v1/territories/map/statuses
- GET /api/v1/territories/{codeIris}/panel
- WebSocket namespace /ws/territory:
  - subscribe_map
  - territory_status_updated
  - territory_owner_updated

## 3) Exemple service Dart

    import 'package:dio/dio.dart';

    class TerritoryMapApi {
      TerritoryMapApi(this._dio);
      final Dio _dio;

      Future<Map<String, dynamic>> fetchTileset() async {
        final response = await _dio.get<Map<String, dynamic>>('/territories/tileset');
        return (response.data?['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
      }

      Future<Map<String, dynamic>> fetchStatuses({String? updatedSince}) async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/territories/map/statuses',
          queryParameters: {
            if (updatedSince != null) 'updated_since': updatedSince,
          },
        );
        return (response.data?['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
      }

      Future<Map<String, dynamic>> fetchPanel(String codeIris) async {
        final response = await _dio.get<Map<String, dynamic>>('/territories/$codeIris/panel');
        return (response.data?['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
      }
    }

## 4) Exemple ecran Flutter (PMTiles + rendu dynamique)

    import 'dart:async';

    import 'package:flutter/material.dart';
    import 'package:flutter_map/flutter_map.dart';
    import 'package:latlong2/latlong.dart';
    import 'package:socket_io_client/socket_io_client.dart' as io;
    import 'package:vector_map_tiles/vector_map_tiles.dart';
    import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

    class IrisMapScreen extends StatefulWidget {
      const IrisMapScreen({super.key});

      @override
      State<IrisMapScreen> createState() => _IrisMapScreenState();
    }

    class _IrisMapScreenState extends State<IrisMapScreen> {
      final MapController _mapController = MapController();
      final Map<String, String> _statusByCodeIris = <String, String>{};
      io.Socket? _socket;

      String _pmtilesUrl = 'https://dart-district.fr/tiles/converted.pmtiles';
      String _layerName = 'iris';
      String? _selectedCodeIris;
      Map<String, dynamic>? _selectedPanel;

      @override
      void initState() {
        super.initState();
        _bootstrap();
      }

      Future<void> _bootstrap() async {
        // 1) Appeler GET /territories/tileset et /territories/map/statuses
        // 2) Alimenter _pmtilesUrl, _layerName, _statusByCodeIris
        // 3) Connecter WS /ws/territory + subscribe_map
      }

      Color _fillColorFor(String codeIris) {
        final status = _statusByCodeIris[codeIris] ?? 'available';
        switch (status) {
          case 'conquered':
            return const Color(0xFF1B8A5A);
          case 'conflict':
            return const Color(0xFFC93A3A);
          case 'alert':
            return const Color(0xFFF39C12);
          case 'locked':
            return const Color(0xFF5F6B7A);
          default:
            return const Color(0xFF2E86DE);
        }
      }

      Future<void> _openPanelFor(String codeIris) async {
        setState(() => _selectedCodeIris = codeIris);
        // GET /territories/{codeIris}/panel
      }

      @override
      Widget build(BuildContext context) {
        final tileProvider = PMTilesVectorTileProvider(
          url: _pmtilesUrl,
        );

        return Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(46.2276, 2.2137),
                  initialZoom: 6,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'fr.dartdistrict.app',
                  ),
                  VectorTileLayer(
                    theme: ThemeReader(
                      bytes: StyleTheme(
                        // Ton style final peut etre deplace dans un JSON de theme.
                        style: {
                          'version': 8,
                          'sources': {},
                          'layers': [],
                        },
                      ).read(),
                    ),
                    tileProviders: TileProviders({'openmaptiles': tileProvider}),
                    layerMode: VectorTileLayerMode.vector,
                    onFeatureTap: (features, latLng) {
                      if (features.isEmpty) return;
                      final props = features.first.properties;
                      final codeIris =
                          (props['code_iris'] ?? props['CODE_IRIS'] ?? '').toString();
                      if (codeIris.isEmpty) return;
                      _openPanelFor(codeIris);
                    },
                    // Colorisation dynamique exemple
                    layerFactory: LayerFactory(
                      layerBuilder: (layerContext, feature) {
                        final codeIris =
                            (feature.properties['code_iris'] ?? '').toString();
                        final fill = _fillColorFor(codeIris).withValues(alpha: 0.45);
                        return Paint()..color = fill;
                      },
                    ),
                  ),
                ],
              ),
              if (_selectedCodeIris != null)
                Positioned(
                  right: 12,
                  top: 56,
                  bottom: 12,
                  width: 320,
                  child: Material(
                    color: const Color(0xFF10141D),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        child: Text(
                          'IRIS: $_selectedCodeIris\n\n${_selectedPanel ?? <String, dynamic>{}}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      @override
      void dispose() {
        _socket?.dispose();
        super.dispose();
      }
    }

## 5) Patch delta WS (status updates)

Quand un event WS arrive:

    void applyStatusDelta(Map<String, dynamic> payload) {
      final codeIris = (payload['code_iris'] ?? '').toString();
      final status = (payload['status'] ?? '').toString();
      if (codeIris.isEmpty || status.isEmpty) return;

      setState(() {
        _statusByCodeIris[codeIris] = status;
      });
    }

## 6) Logique de production recommandee

- Garder une map locale code_iris -> status dans Riverpod.
- Charger les statuses au demarrage puis appliquer uniquement les deltas WS.
- Rejouer un pull GET /territories/map/statuses?updated_since=... apres reconnexion WS.
- Le tap sur feature appelle toujours le backend pour panel/historique a jour.
