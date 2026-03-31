-- ============================================================
-- 007_import_iris_from_csv.sql
-- Bulk import IRIS attributes into territories using CSV + upsert
-- ============================================================
--
-- Preconditions:
-- 1) Run schema + refactor scripts first:
--    - 001_schema.sql
--    - 006_iris_territories_refactor.sql (if existing DB)
-- 2) Prepare a CSV with at least these headers:
--    code_iris,name,insee_com,nom_com,nom_iris,iris_type,dep_code,dep_name,
--    region_code,region_name,population,centroid_lat,centroid_lng,area_m2
--
-- Example psql import command (from backend folder):
-- \copy staging_iris_import(code_iris,name,insee_com,nom_com,nom_iris,iris_type,dep_code,dep_name,region_code,region_name,population,centroid_lat,centroid_lng,area_m2) FROM 'C:/path/iris_attributes.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"')

BEGIN;

CREATE TABLE IF NOT EXISTS staging_iris_import (
  code_iris     VARCHAR(9) NOT NULL,
  name          VARCHAR(255) NOT NULL,
  insee_com     VARCHAR(5),
  nom_com       VARCHAR(150),
  nom_iris      VARCHAR(100),
  iris_type     VARCHAR(30),
  dep_code      VARCHAR(3),
  dep_name      VARCHAR(2),
  region_code   VARCHAR(3),
  region_name   VARCHAR(120),
  population    INTEGER,
  centroid_lat  NUMERIC(10,7) NOT NULL,
  centroid_lng  NUMERIC(10,7) NOT NULL,
  area_m2       NUMERIC(12,2)
);

CREATE INDEX IF NOT EXISTS idx_staging_iris_import_code_iris
  ON staging_iris_import(code_iris);

-- Validate obvious data issues before merge
DO $$
DECLARE
  invalid_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO invalid_count
  FROM staging_iris_import
  WHERE code_iris !~ '^[0-9A-Za-z]{9}$';

  IF invalid_count > 0 THEN
    RAISE EXCEPTION 'Invalid code_iris format for % rows in staging_iris_import', invalid_count;
  END IF;
END $$;

-- Upsert into production territories table
INSERT INTO territories (
  code_iris,
  name,
  insee_com,
  nom_com,
  nom_iris,
  iris_type,
  dep_code,
  dep_name,
  region_code,
  region_name,
  population,
  centroid_lat,
  centroid_lng,
  area_m2,
  status,
  owner_club_id,
  conquered_at,
  created_at,
  updated_at
)
SELECT
  UPPER(TRIM(s.code_iris)) AS code_iris,
  s.name,
  s.insee_com,
  s.nom_com,
  s.nom_iris,
  s.iris_type,
  s.dep_code,
  s.dep_name,
  s.region_code,
  s.region_name,
  s.population,
  s.centroid_lat,
  s.centroid_lng,
  s.area_m2,
  'available'::territory_status,
  NULL,
  NULL,
  NOW(),
  NOW()
FROM staging_iris_import s
ON CONFLICT (code_iris)
DO UPDATE SET
  name = EXCLUDED.name,
  insee_com = EXCLUDED.insee_com,
  nom_com = EXCLUDED.nom_com,
  nom_iris = EXCLUDED.nom_iris,
  iris_type = EXCLUDED.iris_type,
  dep_code = EXCLUDED.dep_code,
  dep_name = EXCLUDED.dep_name,
  region_code = EXCLUDED.region_code,
  region_name = EXCLUDED.region_name,
  population = EXCLUDED.population,
  centroid_lat = EXCLUDED.centroid_lat,
  centroid_lng = EXCLUDED.centroid_lng,
  area_m2 = EXCLUDED.area_m2,
  updated_at = NOW();

-- Keep active PMTiles metadata row in sync (idempotent)
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
  is_active,
  created_at,
  updated_at
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
  TRUE,
  NOW(),
  NOW()
)
ON CONFLICT (key)
DO UPDATE SET
  format = EXCLUDED.format,
  source_url = EXCLUDED.source_url,
  attribution = EXCLUDED.attribution,
  minzoom = EXCLUDED.minzoom,
  maxzoom = EXCLUDED.maxzoom,
  bounds_west = EXCLUDED.bounds_west,
  bounds_south = EXCLUDED.bounds_south,
  bounds_east = EXCLUDED.bounds_east,
  bounds_north = EXCLUDED.bounds_north,
  center_lng = EXCLUDED.center_lng,
  center_lat = EXCLUDED.center_lat,
  center_zoom = EXCLUDED.center_zoom,
  layer_name = EXCLUDED.layer_name,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

COMMIT;

-- Optional post-run checks:
-- SELECT COUNT(*) FROM territories;
-- SELECT dep_code, COUNT(*) FROM territories GROUP BY dep_code ORDER BY dep_code;
-- SELECT key, source_url, is_active FROM territory_tilesets;
