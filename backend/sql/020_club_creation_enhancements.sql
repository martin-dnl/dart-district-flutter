ALTER TABLE clubs
  ADD COLUMN IF NOT EXISTS postal_code VARCHAR(10) NULL,
  ADD COLUMN IF NOT EXISTS country VARCHAR(100) NULL DEFAULT 'France',
  ADD COLUMN IF NOT EXISTS opening_hours JSONB NULL;

COMMENT ON COLUMN clubs.postal_code IS 'Postal code for club address (user-entered or resolved from place APIs)';
COMMENT ON COLUMN clubs.country IS 'Country for club address. Defaults to France when not provided';
COMMENT ON COLUMN clubs.opening_hours IS 'Weekly schedule as JSON object, e.g. {"monday":{"open":"10:00","close":"22:00"}}';
