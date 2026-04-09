ALTER TABLE users
ADD COLUMN IF NOT EXISTS conquest_score INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_users_conquest_score
ON users (conquest_score DESC);
