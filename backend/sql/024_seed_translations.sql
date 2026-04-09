INSERT INTO languages (code, country_name, language_name, flag_emoji, is_available)
VALUES
  ('fr-FR', 'France', 'Francais', '🇫🇷', true),
  ('en-US', 'United States', 'English', '🇺🇸', true)
ON CONFLICT (code) DO UPDATE SET
  country_name = EXCLUDED.country_name,
  language_name = EXCLUDED.language_name,
  flag_emoji = EXCLUDED.flag_emoji,
  is_available = EXCLUDED.is_available;

INSERT INTO translations (key, language_code, value)
VALUES
  ('COMMON.YES', 'fr-FR', 'Oui'),
  ('COMMON.NO', 'fr-FR', 'Non'),
  ('COMMON.CANCEL', 'fr-FR', 'Annuler'),
  ('COMMON.CONFIRM', 'fr-FR', 'Confirmer'),
  ('NAV.HOME', 'fr-FR', 'Accueil'),
  ('NAV.MAP', 'fr-FR', 'Carte'),
  ('NAV.PLAY', 'fr-FR', 'Jouer'),
  ('NAV.CLUB', 'fr-FR', 'Club'),
  ('NAV.PROFILE', 'fr-FR', 'Profil'),
  ('SCREEN.HOME.LAST_MATCHES', 'fr-FR', 'Dernieres parties'),
  ('SCREEN.HOME.QUICK_ACTIONS', 'fr-FR', 'Actions rapides'),
  ('SCREEN.HOME.UPCOMING_TOURNAMENTS', 'fr-FR', 'Prochains tournois'),
  ('SCREEN.MAP.LEGEND_AVAILABLE', 'fr-FR', 'Disponible'),
  ('SCREEN.MAP.LEGEND_MY_CLUB', 'fr-FR', 'Mon club'),
  ('SCREEN.MAP.LEGEND_BLOCKED', 'fr-FR', 'Bloque'),
  ('SCREEN.MAP.LEGEND_CONFLICT', 'fr-FR', 'En conflit'),
  ('SCREEN.PROFILE.ELO_PROGRESSION', 'fr-FR', 'Progression ELO'),
  ('SCREEN.PROFILE.WEEK', 'fr-FR', 'Semaine'),
  ('SCREEN.PROFILE.MONTH', 'fr-FR', 'Mois'),
  ('SCREEN.PROFILE.YEAR', 'fr-FR', 'Annee'),
  ('SCREEN.SETTINGS.LANGUAGE', 'fr-FR', 'Langue'),
  ('SCREEN.SETTINGS.DART_SENSE', 'fr-FR', 'Dart Sense'),
  ('COMMON.YES', 'en-US', 'Yes'),
  ('COMMON.NO', 'en-US', 'No'),
  ('COMMON.CANCEL', 'en-US', 'Cancel'),
  ('COMMON.CONFIRM', 'en-US', 'Confirm'),
  ('NAV.HOME', 'en-US', 'Home'),
  ('NAV.MAP', 'en-US', 'Map'),
  ('NAV.PLAY', 'en-US', 'Play'),
  ('NAV.CLUB', 'en-US', 'Club'),
  ('NAV.PROFILE', 'en-US', 'Profile'),
  ('SCREEN.HOME.LAST_MATCHES', 'en-US', 'Latest matches'),
  ('SCREEN.HOME.QUICK_ACTIONS', 'en-US', 'Quick actions'),
  ('SCREEN.HOME.UPCOMING_TOURNAMENTS', 'en-US', 'Upcoming tournaments'),
  ('SCREEN.MAP.LEGEND_AVAILABLE', 'en-US', 'Available'),
  ('SCREEN.MAP.LEGEND_MY_CLUB', 'en-US', 'My club'),
  ('SCREEN.MAP.LEGEND_BLOCKED', 'en-US', 'Blocked'),
  ('SCREEN.MAP.LEGEND_CONFLICT', 'en-US', 'Conflict'),
  ('SCREEN.PROFILE.ELO_PROGRESSION', 'en-US', 'ELO progression'),
  ('SCREEN.PROFILE.WEEK', 'en-US', 'Week'),
  ('SCREEN.PROFILE.MONTH', 'en-US', 'Month'),
  ('SCREEN.PROFILE.YEAR', 'en-US', 'Year'),
  ('SCREEN.SETTINGS.LANGUAGE', 'en-US', 'Language'),
  ('SCREEN.SETTINGS.DART_SENSE', 'en-US', 'Dart Sense')
ON CONFLICT (key, language_code) DO UPDATE SET
  value = EXCLUDED.value,
  updated_at = NOW();
