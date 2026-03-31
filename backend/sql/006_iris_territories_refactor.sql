-- ============================================================
-- 006_iris_territories_refactor.sql
-- Refactor territories to IRIS primary key + PMTiles metadata table
-- ============================================================

BEGIN;

-- 1) Extend enums safely
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'territory_status') THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_enum
      WHERE enumlabel = 'locked'
        AND enumtypid = 'territory_status'::regtype
    ) THEN
      ALTER TYPE territory_status ADD VALUE 'locked';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_enum
      WHERE enumlabel = 'alert'
        AND enumtypid = 'territory_status'::regtype
    ) THEN
      ALTER TYPE territory_status ADD VALUE 'alert';
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'duel_status') THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_enum
      WHERE enumlabel = 'completed'
        AND enumtypid = 'duel_status'::regtype
    ) THEN
      ALTER TYPE duel_status ADD VALUE 'completed';
    END IF;
  END IF;
END $$;

-- 2) Add new IRIS columns to territories if absent
ALTER TABLE territories
  ADD COLUMN IF NOT EXISTS code_iris VARCHAR(9),
  ADD COLUMN IF NOT EXISTS insee_com VARCHAR(5),
  ADD COLUMN IF NOT EXISTS nom_com VARCHAR(150),
  ADD COLUMN IF NOT EXISTS nom_iris VARCHAR(100),
  ADD COLUMN IF NOT EXISTS iris_type VARCHAR(30),
  ADD COLUMN IF NOT EXISTS dep_code VARCHAR(3),
  ADD COLUMN IF NOT EXISTS dep_name VARCHAR(2),
  ADD COLUMN IF NOT EXISTS region_code VARCHAR(3),
  ADD COLUMN IF NOT EXISTS region_name VARCHAR(120),
  ADD COLUMN IF NOT EXISTS population INTEGER,
  ADD COLUMN IF NOT EXISTS centroid_lat NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS centroid_lng NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS area_m2 NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Optional backfill from legacy columns when available
UPDATE territories
SET
  centroid_lat = COALESCE(centroid_lat, latitude),
  centroid_lng = COALESCE(centroid_lng, longitude),
  nom_com = COALESCE(nom_com, city),
  nom_iris = COALESCE(nom_iris, district),
  code_iris = COALESCE(code_iris, LEFT(code, 9))
WHERE code_iris IS NULL;

-- Mark rows still missing code_iris to avoid invalid PK swap
DO $$
DECLARE missing_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO missing_count FROM territories WHERE code_iris IS NULL;
  IF missing_count > 0 THEN
    RAISE EXCEPTION 'Cannot switch territories PK: % rows have NULL code_iris', missing_count;
  END IF;
END $$;

-- 3) Drop legacy FKs that still point to territories.id
ALTER TABLE territory_history DROP CONSTRAINT IF EXISTS territory_history_territory_id_fkey;
ALTER TABLE matches DROP CONSTRAINT IF EXISTS matches_territory_id_fkey;
ALTER TABLE tournaments DROP CONSTRAINT IF EXISTS tournaments_territory_id_fkey;
ALTER TABLE duels DROP CONSTRAINT IF EXISTS duels_territory_id_fkey;
ALTER TABLE qr_codes DROP CONSTRAINT IF EXISTS qr_codes_territory_id_fkey;

-- 4) Convert FK columns to VARCHAR(9)
ALTER TABLE territory_history
  ALTER COLUMN territory_id TYPE VARCHAR(9) USING territory_id::text;

ALTER TABLE matches
  ALTER COLUMN territory_id TYPE VARCHAR(9) USING territory_id::text;

ALTER TABLE tournaments
  ALTER COLUMN territory_id TYPE VARCHAR(9) USING territory_id::text;

ALTER TABLE duels
  ALTER COLUMN territory_id TYPE VARCHAR(9) USING territory_id::text;

ALTER TABLE qr_codes
  ALTER COLUMN territory_id TYPE VARCHAR(9) USING territory_id::text;

-- Remap legacy UUID references to the new code_iris key before re-adding FKs
UPDATE territory_history th
SET territory_id = t.code_iris
FROM territories t
WHERE th.territory_id = t.id::text;

UPDATE matches m
SET territory_id = t.code_iris
FROM territories t
WHERE m.territory_id = t.id::text;

UPDATE tournaments tr
SET territory_id = t.code_iris
FROM territories t
WHERE tr.territory_id = t.id::text;

UPDATE duels d
SET territory_id = t.code_iris
FROM territories t
WHERE d.territory_id = t.id::text;

UPDATE qr_codes q
SET territory_id = t.code_iris
FROM territories t
WHERE q.territory_id = t.id::text;

-- Clean up legacy orphan references that no longer map to an existing territory
DELETE FROM territory_history th
WHERE NOT EXISTS (
  SELECT 1 FROM territories t WHERE th.territory_id = t.code_iris
);

UPDATE matches m
SET territory_id = NULL
WHERE territory_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM territories t WHERE m.territory_id = t.code_iris
  );

UPDATE tournaments tr
SET territory_id = NULL
WHERE territory_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM territories t WHERE tr.territory_id = t.code_iris
  );

DELETE FROM duels d
WHERE NOT EXISTS (
  SELECT 1 FROM territories t WHERE d.territory_id = t.code_iris
);

DELETE FROM qr_codes q
WHERE NOT EXISTS (
  SELECT 1 FROM territories t WHERE q.territory_id = t.code_iris
);

-- 5) Swap territory PK from id UUID to code_iris
ALTER TABLE territories DROP CONSTRAINT IF EXISTS territories_pkey;
ALTER TABLE territories ADD CONSTRAINT territories_pkey PRIMARY KEY (code_iris);

-- 6) Re-wire FKs
ALTER TABLE territory_history
  ADD CONSTRAINT territory_history_territory_id_fkey
  FOREIGN KEY (territory_id) REFERENCES territories(code_iris) ON DELETE CASCADE;

ALTER TABLE matches
  ADD CONSTRAINT matches_territory_id_fkey
  FOREIGN KEY (territory_id) REFERENCES territories(code_iris) ON DELETE SET NULL;

ALTER TABLE tournaments
  ADD CONSTRAINT tournaments_territory_id_fkey
  FOREIGN KEY (territory_id) REFERENCES territories(code_iris) ON DELETE SET NULL;

ALTER TABLE duels
  ADD CONSTRAINT duels_territory_id_fkey
  FOREIGN KEY (territory_id) REFERENCES territories(code_iris) ON DELETE CASCADE;

ALTER TABLE qr_codes
  ADD CONSTRAINT qr_codes_territory_id_fkey
  FOREIGN KEY (territory_id) REFERENCES territories(code_iris) ON DELETE CASCADE;

-- 7) Useful indexes
CREATE INDEX IF NOT EXISTS idx_territories_dep_code ON territories(dep_code);
CREATE INDEX IF NOT EXISTS idx_territories_updated_at ON territories(updated_at DESC);

-- 8) PMTiles source metadata table
CREATE TABLE IF NOT EXISTS territory_tilesets (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key             VARCHAR(100) NOT NULL UNIQUE,
  format          VARCHAR(50) NOT NULL,
  source_url      VARCHAR(255) NOT NULL,
  attribution     VARCHAR(120) NOT NULL,
  minzoom         INTEGER NOT NULL DEFAULT 0,
  maxzoom         INTEGER NOT NULL DEFAULT 14,
  bounds_west     NUMERIC(10,6),
  bounds_south    NUMERIC(10,6),
  bounds_east     NUMERIC(10,6),
  bounds_north    NUMERIC(10,6),
  center_lng      NUMERIC(10,6),
  center_lat      NUMERIC(10,6),
  center_zoom     INTEGER,
  layer_name      VARCHAR(100),
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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
SELECT
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
WHERE NOT EXISTS (
  SELECT 1 FROM territory_tilesets WHERE key = 'iris_france_pmtiles'
);

COMMIT;
