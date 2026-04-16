-- Social feed reports + score snapshot columns for richer feed cards.
-- Idempotent migration, safe to run multiple times.

ALTER TABLE social_posts
  ADD COLUMN IF NOT EXISTS player_1_name VARCHAR(64),
  ADD COLUMN IF NOT EXISTS player_1_score INT,
  ADD COLUMN IF NOT EXISTS player_2_name VARCHAR(64),
  ADD COLUMN IF NOT EXISTS player_2_score INT,
  ADD COLUMN IF NOT EXISTS winner_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS match_average NUMERIC(6,2),
  ADD COLUMN IF NOT EXISTS match_checkout_rate NUMERIC(6,2);

CREATE TABLE IF NOT EXISTS social_post_reports (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id     UUID NOT NULL REFERENCES social_posts(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    author_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason      TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_social_post_reports_post_reporter UNIQUE (post_id, reporter_id),
    CONSTRAINT chk_social_post_reports_reason_non_empty
      CHECK (char_length(btrim(reason)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_social_post_reports_post_created
ON social_post_reports (post_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_social_post_reports_reporter_created
ON social_post_reports (reporter_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_social_post_reports_author_created
ON social_post_reports (author_id, created_at DESC);
