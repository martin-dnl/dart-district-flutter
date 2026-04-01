-- ====================================================================
-- Migration 012 : Refonte complete du systeme de tournois
-- ====================================================================

DO $$
DECLARE
  registrations_count BIGINT;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'tournament_registrations'
  ) THEN
    EXECUTE 'SELECT COUNT(*) FROM tournament_registrations' INTO registrations_count;
    IF registrations_count = 0 THEN
      EXECUTE 'DROP TABLE tournament_registrations CASCADE';
    END IF;
  END IF;
END
$$;

ALTER TABLE tournaments
  DROP COLUMN IF EXISTS max_clubs,
  DROP COLUMN IF EXISTS enrolled_clubs,
  ADD COLUMN IF NOT EXISTS max_players INT NOT NULL DEFAULT 16,
  ADD COLUMN IF NOT EXISTS enrolled_players INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS format VARCHAR(20) NOT NULL DEFAULT 'single_elimination',
  ADD COLUMN IF NOT EXISTS pool_count INT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS players_per_pool INT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS qualified_per_pool INT NOT NULL DEFAULT 2,
  ADD COLUMN IF NOT EXISTS legs_per_set_pool INT NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS sets_to_win_pool INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS legs_per_set_bracket INT NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS sets_to_win_bracket INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS current_phase VARCHAR(20) NOT NULL DEFAULT 'registration';

CREATE TABLE IF NOT EXISTS tournament_pools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  pool_name VARCHAR(10) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tournament_players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  seed INT,
  pool_id UUID,
  is_qualified BOOLEAN NOT NULL DEFAULT FALSE,
  is_disqualified BOOLEAN NOT NULL DEFAULT FALSE,
  disqualification_reason TEXT,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(tournament_id, user_id)
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name = 'tournament_players'
      AND constraint_name = 'fk_tp_pool'
  ) THEN
    ALTER TABLE tournament_players
      ADD CONSTRAINT fk_tp_pool
      FOREIGN KEY (pool_id)
      REFERENCES tournament_pools(id)
      ON DELETE SET NULL;
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS tournament_pool_standings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pool_id UUID NOT NULL REFERENCES tournament_pools(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  matches_played INT NOT NULL DEFAULT 0,
  matches_won INT NOT NULL DEFAULT 0,
  legs_won INT NOT NULL DEFAULT 0,
  legs_lost INT NOT NULL DEFAULT 0,
  leg_difference INT GENERATED ALWAYS AS (legs_won - legs_lost) STORED,
  points INT NOT NULL DEFAULT 0,
  rank INT,
  UNIQUE(pool_id, user_id)
);

CREATE TABLE IF NOT EXISTS tournament_bracket_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  round_number INT NOT NULL,
  position INT NOT NULL,
  player1_id UUID REFERENCES users(id),
  player2_id UUID REFERENCES users(id),
  winner_id UUID REFERENCES users(id),
  match_id UUID REFERENCES matches(id),
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  scheduled_at TIMESTAMPTZ,
  UNIQUE(tournament_id, round_number, position)
);

CREATE INDEX IF NOT EXISTS idx_tp_tournament ON tournament_players(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tp_pool ON tournament_players(pool_id);
CREATE INDEX IF NOT EXISTS idx_tps_pool ON tournament_pool_standings(pool_id);
CREATE INDEX IF NOT EXISTS idx_tbm_tournament ON tournament_bracket_matches(tournament_id);
