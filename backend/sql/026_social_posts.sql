CREATE TABLE IF NOT EXISTS social_posts (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    match_id     UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    mode         VARCHAR(16) NOT NULL,
    sets_score   VARCHAR(32) NOT NULL,
    result_label VARCHAR(32) NOT NULL,
    description  TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_social_posts_author_created
ON social_posts (author_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_social_posts_created_at
ON social_posts (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_social_posts_match_id
ON social_posts (match_id);
