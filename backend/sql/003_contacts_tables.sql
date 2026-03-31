-- ============================================================
-- 003_contacts_tables.sql
-- Adds persisted friends and direct messages for Contacts feature
-- ============================================================

CREATE TABLE IF NOT EXISTS friendships (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    friend_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_friendships_user_friend UNIQUE (user_id, friend_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_user
    ON friendships(user_id);

CREATE TABLE IF NOT EXISTS direct_messages (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content       TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at       TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_direct_messages_to_read
    ON direct_messages(to_user_id, read_at);

CREATE INDEX IF NOT EXISTS idx_direct_messages_pair_created
    ON direct_messages(from_user_id, to_user_id, created_at);
