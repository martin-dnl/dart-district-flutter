-- ============================================================
-- Dart District – Seed data for development
-- ============================================================

-- ── Sample clubs ────────────────────────────────────────────
INSERT INTO clubs (id, name, city, region, address, conquest_points, rank)
VALUES
  ('c0000001-0000-0000-0000-000000000001', 'Les Flèches de Fer', 'Paris', 'Île-de-France', 'Paris 11ème', 14250, 2),
  ('c0000001-0000-0000-0000-000000000002', 'Darts Club Paris',   'Paris', 'Île-de-France', 'Paris 3ème',  18500, 1),
  ('c0000001-0000-0000-0000-000000000003', 'Bullseye Kings',     'Paris', 'Île-de-France', 'Paris 9ème',  12100, 3);

-- ── Sample territories ─────────────────────────────────────
INSERT INTO territories (
  code_iris,
  name,
  insee_com,
  nom_com,
  nom_iris,
  iris_type,
  dep_code,
  dep_name,
  region_code,
  region_name,
  centroid_lat,
  centroid_lng,
  status,
  owner_club_id
)
VALUES
  ('751030101', 'Bastille',      '75103', 'Paris', 'Bastille',     'HABITAT', '75', '75', '11', 'Ile-de-France', 48.8531, 2.3698, 'conquered', 'c0000001-0000-0000-0000-000000000001'),
  ('751030102', 'Le Marais',     '75103', 'Paris', 'Le Marais',    'HABITAT', '75', '75', '11', 'Ile-de-France', 48.8566, 2.3622, 'conflict',  'c0000001-0000-0000-0000-000000000002'),
  ('751100101', 'Republique',    '75110', 'Paris', 'Republique',   'HABITAT', '75', '75', '11', 'Ile-de-France', 48.8674, 2.3637, 'available', NULL),
  ('751110101', 'Oberkampf',     '75111', 'Paris', 'Oberkampf',    'HABITAT', '75', '75', '11', 'Ile-de-France', 48.8650, 2.3780, 'conquered', 'c0000001-0000-0000-0000-000000000001'),
  ('751090101', 'Pigalle',       '75109', 'Paris', 'Pigalle',      'HABITAT', '75', '75', '11', 'Ile-de-France', 48.8822, 2.3375, 'conquered', 'c0000001-0000-0000-0000-000000000003'),
  ('751060101', 'Saint-Germain', '75106', 'Paris', 'Saint-Germain','HABITAT', '75', '75', '11', 'Ile-de-France', 48.8530, 2.3340, 'available', NULL);

-- ── Sample users ────────────────────────────────────────────
INSERT INTO users (id, username, email, elo, city, region)
VALUES
  ('u0000001-0000-0000-0000-000000000001', 'AlexandreD', 'alex@example.com', 1250, 'Paris', 'Île-de-France'),
  ('u0000001-0000-0000-0000-000000000002', 'SophieM',    'sophie@example.com', 1180, 'Paris', 'Île-de-France'),
  ('u0000001-0000-0000-0000-000000000003', 'LucasB',     'lucas@example.com',  1050, 'Paris', 'Île-de-France');

-- ── Club memberships ────────────────────────────────────────
INSERT INTO club_members (club_id, user_id, role)
VALUES
  ('c0000001-0000-0000-0000-000000000001', 'u0000001-0000-0000-0000-000000000001', 'president'),
  ('c0000001-0000-0000-0000-000000000001', 'u0000001-0000-0000-0000-000000000002', 'captain'),
  ('c0000001-0000-0000-0000-000000000001', 'u0000001-0000-0000-0000-000000000003', 'player');

-- ── Sample tournament ───────────────────────────────────────
INSERT INTO tournaments (id, name, territory_id, is_territorial, city, venue_name, venue_address, mode, finish, max_clubs, enrolled_clubs, scheduled_at, created_by)
VALUES
  ('a0000001-0000-0000-0000-000000000001', 'Conquete du Marais #4', '751030102', true, 'Paris', 'Le Bar des Flechettes', 'Paris 11eme', '501', 'double_out', 16, 11, NOW() + INTERVAL '2 days', 'u0000001-0000-0000-0000-000000000001');
