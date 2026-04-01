-- ============================================================
-- Dart District – App version policy seeds
-- ============================================================

BEGIN;

INSERT INTO app_version_policies (
    platform,
    min_version,
    recommended_version,
    store_url_android,
    store_url_ios,
    message_force_update,
    message_soft_update,
    is_active
)
SELECT
    'android',
    '1.0.0',
    '1.0.0',
    'https://play.google.com/store/apps/details?id=com.dartdistrict.app',
    'https://apps.apple.com/fr/app/dart-district/id0000000000',
    'Une nouvelle version est obligatoire pour continuer.',
    'Une mise a jour est disponible pour ameliorer votre experience.',
    TRUE
WHERE NOT EXISTS (
    SELECT 1
    FROM app_version_policies
    WHERE platform = 'android' AND is_active = TRUE
);

INSERT INTO app_version_policies (
    platform,
    min_version,
    recommended_version,
    store_url_android,
    store_url_ios,
    message_force_update,
    message_soft_update,
    is_active
)
SELECT
    'ios',
    '1.0.0',
    '1.0.0',
    'https://play.google.com/store/apps/details?id=com.dartdistrict.app',
    'https://apps.apple.com/fr/app/dart-district/id0000000000',
    'Une nouvelle version est obligatoire pour continuer.',
    'Une mise a jour est disponible pour ameliorer votre experience.',
    TRUE
WHERE NOT EXISTS (
    SELECT 1
    FROM app_version_policies
    WHERE platform = 'ios' AND is_active = TRUE
);

COMMIT;
