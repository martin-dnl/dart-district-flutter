-- ============================================================
-- 005_match_invitation_flow.sql
-- Adds invitation lifecycle columns for match flow
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'match_invitation_status'
  ) THEN
    CREATE TYPE match_invitation_status AS ENUM ('pending', 'accepted', 'refused');
  END IF;
END $$;

ALTER TABLE matches
  ADD COLUMN IF NOT EXISTS inviter_id UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS invitee_id UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS invitation_status match_invitation_status,
  ADD COLUMN IF NOT EXISTS invitation_created_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_matches_inviter_id
  ON matches(inviter_id);

CREATE INDEX IF NOT EXISTS idx_matches_invitee_id
  ON matches(invitee_id);

CREATE INDEX IF NOT EXISTS idx_matches_invitation_status
  ON matches(invitation_status);

CREATE INDEX IF NOT EXISTS idx_matches_invitation_created_at
  ON matches(invitation_created_at DESC);
