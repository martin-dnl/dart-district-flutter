-- Social feed interactions: likes and comments for social posts.
-- Idempotent migration, safe to run multiple times.

CREATE TABLE IF NOT EXISTS social_post_likes (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id    UUID NOT NULL REFERENCES social_posts(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_social_post_likes_post_user UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_social_post_likes_post_created
ON social_post_likes (post_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_social_post_likes_user_created
ON social_post_likes (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS social_post_comments (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id    UUID NOT NULL REFERENCES social_posts(id) ON DELETE CASCADE,
    author_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message    TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_social_post_comments_message_non_empty
      CHECK (char_length(btrim(message)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_social_post_comments_post_created
ON social_post_comments (post_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_social_post_comments_author_created
ON social_post_comments (author_id, created_at DESC);
