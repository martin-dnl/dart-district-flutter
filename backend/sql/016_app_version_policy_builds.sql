-- ============================================================
-- 016_app_version_policy_builds.sql
-- Add build-aware policy fields for app versioning
-- ============================================================

BEGIN;

ALTER TABLE app_version_policies
  ADD COLUMN IF NOT EXISTS min_build INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS recommended_build INT NOT NULL DEFAULT 1;

UPDATE app_version_policies
SET min_build = COALESCE(min_build, 1),
    recommended_build = COALESCE(recommended_build, 1)
WHERE min_build IS NULL
   OR recommended_build IS NULL;

COMMIT;
