da  INSERT INTO app_version_policies (
  platform,
  min_version,
  recommended_version,
  min_build,
  recommended_build,
  store_url_android,
  store_url_ios,
  message_force_update,
  message_soft_update,
  is_active
)
VALUES (
  'android',
  '1.0.3',
  '1.0.3',
  4,
  5,
  'https://play.google.com/store/apps/details?id=fr.dartdistrict.mobile',
  '',
  'Mise a jour obligatoire. Version/build minimum: 1.0.0+4',
  'Nouvelle version disponible: 1.0.1+5',
  TRUE
);