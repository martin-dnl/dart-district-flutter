-- ============================================================
-- 009_app_version_policy.sql
-- Add app version policies used by /api/v1/app/version
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS app_version_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    platform VARCHAR(16) NOT NULL CHECK (platform IN ('android', 'ios')),
    min_version VARCHAR(32) NOT NULL,
    recommended_version VARCHAR(32) NOT NULL,
    store_url_android TEXT,
    store_url_ios TEXT,
    message_force_update TEXT NOT NULL,
    message_soft_update TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_version_policies_platform_active
    ON app_version_policies(platform, is_active);

COMMIT;
