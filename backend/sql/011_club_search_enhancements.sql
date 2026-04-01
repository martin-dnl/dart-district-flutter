ALTER TABLE clubs
  ADD COLUMN IF NOT EXISTS dart_boards_count SMALLINT NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_clubs_city ON clubs (LOWER(city));
CREATE INDEX IF NOT EXISTS idx_clubs_name_lower ON clubs (LOWER(name));
