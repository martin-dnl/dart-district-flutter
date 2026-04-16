-- Persist first-leg starter configured from game setup.
-- Idempotent migration.

ALTER TABLE matches
  ADD COLUMN IF NOT EXISTS initial_starter_index INT NOT NULL DEFAULT 0;

ALTER TABLE matches
  DROP CONSTRAINT IF EXISTS chk_matches_initial_starter_index;

ALTER TABLE matches
  ADD CONSTRAINT chk_matches_initial_starter_index
  CHECK (initial_starter_index IN (0, 1));
