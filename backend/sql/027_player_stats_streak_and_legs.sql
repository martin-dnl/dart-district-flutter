ALTER TABLE player_stats
  ADD COLUMN IF NOT EXISTS consecutive_days_played INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_played_date DATE;
