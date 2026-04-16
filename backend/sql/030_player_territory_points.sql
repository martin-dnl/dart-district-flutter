CREATE TABLE IF NOT EXISTS player_territory_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_iris VARCHAR(9) NOT NULL,
  points INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, code_iris)
);

CREATE INDEX IF NOT EXISTS idx_ptp_user_id ON player_territory_points(user_id);
CREATE INDEX IF NOT EXISTS idx_ptp_code_iris ON player_territory_points(code_iris);
CREATE INDEX IF NOT EXISTS idx_ptp_code_iris_points ON player_territory_points(code_iris, points DESC);
