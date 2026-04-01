-- ============================================================
-- Dart District – Reference data seeds
-- ============================================================

-- ── PMTiles tileset metadata ─────────────────────────────────
INSERT INTO territory_tilesets (
    key,
    format,
    source_url,
    attribution,
    minzoom,
    maxzoom,
    bounds_west,
    bounds_south,
    bounds_east,
    bounds_north,
    center_lng,
    center_lat,
    center_zoom,
    layer_name,
    is_active
)
VALUES (
    'iris_france_pmtiles',
    'pmtiles',
    'https://dart-district.fr/tiles/converted.pmtiles',
    'INSEE + IGN Contours IRIS',
    0,
    14,
    -5.225,
    41.333,
    9.85,
    51.2,
    2.2137,
    46.2276,
    6,
    'iris',
    TRUE
)
ON CONFLICT (key) DO UPDATE SET
    source_url  = EXCLUDED.source_url,
    is_active   = EXCLUDED.is_active,
    updated_at  = NOW();
