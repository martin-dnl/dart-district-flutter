CREATE INDEX IF NOT EXISTS idx_elo_history_user_created_at
ON elo_history (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_elo_history_match
ON elo_history (match_id);
