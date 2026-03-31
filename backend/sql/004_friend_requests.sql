-- ============================================================
-- 004_friend_requests.sql
-- Adds pending friend requests workflow
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'friend_request_status') THEN
    CREATE TYPE friend_request_status AS ENUM ('pending', 'accepted', 'rejected', 'canceled');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS friend_requests (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status        friend_request_status NOT NULL DEFAULT 'pending',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_friend_requests_sender_receiver
    ON friend_requests(sender_id, receiver_id);

CREATE INDEX IF NOT EXISTS idx_friend_requests_receiver_status_created
    ON friend_requests(receiver_id, status, created_at);
