-- 1. Ajout du booleen ranked sur les matchs
ALTER TABLE matches ADD COLUMN IF NOT EXISTS is_ranked BOOLEAN DEFAULT false;

-- 2. Ajout du champ surrendered_by sur les matchs
ALTER TABLE matches ADD COLUMN IF NOT EXISTS surrendered_by UUID REFERENCES users(id) ON DELETE SET NULL;

-- 3. Ajout du nombre de cibles sur les clubs
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS dart_boards_count INT DEFAULT 0;

-- 4. Ajout des compteurs 140+ et 100+ dans player_stats
ALTER TABLE player_stats ADD COLUMN IF NOT EXISTS count_140_plus INT DEFAULT 0;
ALTER TABLE player_stats ADD COLUMN IF NOT EXISTS count_100_plus INT DEFAULT 0;

-- 5. Tag abandon tournoi sur les users
ALTER TABLE users ADD COLUMN IF NOT EXISTS has_tournament_abandon BOOLEAN DEFAULT false;

-- 6. Table badges
CREATE TABLE IF NOT EXISTS badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  image_asset VARCHAR(200) NOT NULL,
  category VARCHAR(50) DEFAULT 'general',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. Table user_badges
CREATE TABLE IF NOT EXISTS user_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
  earned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, badge_id)
);

-- 8. Index pour les requetes frequentes
CREATE INDEX IF NOT EXISTS idx_matches_is_ranked ON matches(is_ranked) WHERE is_ranked = true;
CREATE INDEX IF NOT EXISTS idx_matches_status_ranked ON matches(status, is_ranked);
CREATE INDEX IF NOT EXISTS idx_user_badges_user ON user_badges(user_id);
