CREATE TABLE IF NOT EXISTS club_territory_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
  code_iris VARCHAR(9) NOT NULL,
  points INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (club_id, code_iris)
);

CREATE INDEX IF NOT EXISTS idx_ctp_club_id ON club_territory_points(club_id);
CREATE INDEX IF NOT EXISTS idx_ctp_code_iris ON club_territory_points(code_iris);
CREATE INDEX IF NOT EXISTS idx_ctp_code_iris_points ON club_territory_points(code_iris, points DESC);

ALTER TABLE matches
ADD COLUMN IF NOT EXISTS territory_club_id UUID REFERENCES clubs(id) ON DELETE SET NULL;

ALTER TABLE matches
ADD COLUMN IF NOT EXISTS territory_code_iris VARCHAR(9);

ALTER TABLE tournaments
ADD COLUMN IF NOT EXISTS is_ranked BOOLEAN DEFAULT false;
