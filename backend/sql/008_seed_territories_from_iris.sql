-- ============================================================
-- 008_seed_territories_from_iris.sql
-- Create IRIS territory records from geometry data
-- ============================================================

BEGIN;

-- Create IRIS territories for Paris (code prefix 75)
-- We'll use a simple INSERT pattern based on IRIS codes
INSERT INTO territories (
  code_iris,
  code,
  name,
  city,
  district,
  latitude,
  longitude,
  centroid_lat,
  centroid_lng,
  status,
  created_at,
  updated_at
)
VALUES
  ('750000000', '750000000', 'Île Saint-Louis', 'Paris', 'Île-de-France', 48.8511, 2.3555, 48.8511, 2.3555, 'available', NOW(), NOW()),
  ('750010101', '750010101', 'Marais - Archives', 'Paris', 'Île-de-France', 48.8625, 2.3673, 48.8625, 2.3673, 'available', NOW(), NOW()),
  ('750010102', '750010102', 'Marais - Temple', 'Paris', 'Île-de-France', 48.8645, 2.3633, 48.8645, 2.3633, 'available', NOW(), NOW()),
  ('750010201', '750010201', '1er - Palais Royal', 'Paris', 'Île-de-France', 48.8631, 2.3358, 48.8631, 2.3358, 'conquered', NOW(), NOW()),
  ('750010202', '750010202', '1er  - Saint-Germain', 'Paris', 'Île-de-France', 48.8630, 2.3416, 48.8630, 2.3416, 'available', NOW(), NOW()),
  ('750010203', '750010203', '1er - Châtelet', 'Paris', 'Île-de-France', 48.8579, 2.3500, 48.8579, 2.3500, 'locked', NOW(), NOW()),
  ('750010204', '750010204', '1er - Montorgueil', 'Paris', 'Île-de-France', 48.8626, 2.3482, 48.8626, 2.3482, 'available', NOW(), NOW()),
  ('750020101', '750020101', 'Belleville - Est', 'Paris', 'Île-de-France', 48.8718, 2.3858, 48.8718, 2.3858, 'conflict', NOW(), NOW()),
  ('750020102', '750020102', 'Belleville - Ouest', 'Paris', 'Île-de-France', 48.8700, 2.3778, 48.8700, 2.3778, 'alert', NOW(), NOW()),
  ('750020103', '750020103', 'Saint-Martin', 'Paris', 'Île-de-France', 48.8651, 2.3676, 48.8651, 2.3676, 'available', NOW(), NOW()),
  ('750030101', '750030101', 'Marais Nord', 'Paris', 'Île-de-France', 48.8684, 2.3627, 48.8684, 2.3627, 'available', NOW(), NOW()),
  ('750030102', '750030102', 'Popincourt', 'Paris', 'Île-de-France', 48.8603, 2.3741, 48.8603, 2.3741, 'available', NOW(), NOW()),
  ('750030103', '750030103', 'République', 'Paris', 'Île-de-France', 48.8660, 2.3657, 48.8660, 2.3657, 'conquered', NOW(), NOW()),
  ('750040101', '750040101', 'Châtelet / Halles', 'Paris', 'Île-de-France', 48.8620, 2.3486, 48.8620, 2.3486, 'available', NOW(), NOW()),
  ('750040102', '750040102', 'Île de la Cité', 'Paris', 'Île-de-France', 48.8500, 2.3481, 48.8500, 2.3481, 'available', NOW(), NOW()),
  ('750040103', '750040103', 'Latin Quarter', 'Paris', 'Île-de-France', 48.8427, 2.3515, 48.8427, 2.3515, 'locked', NOW(), NOW()),
  ('750040104', '750040104', 'Mouffetard', 'Paris', 'Île-de-France', 48.8350, 2.3580, 48.8350, 2.3580, 'available', NOW(), NOW()),
  ('750050101', '750050101', 'Panthéon', 'Paris', 'Île-de-France', 48.8456, 2.3527, 48.8456, 2.3527, 'conflict', NOW(), NOW()),
  ('750050102', '750050102', 'Contrescarpe', 'Paris', 'Île-de-France', 48.8511, 2.3548, 48.8511, 2.3548, 'available', NOW(), NOW()),
  ('750050103', '750050103', 'Botanical Garden', 'Paris', 'Île-de-France', 48.8432, 2.3627, 48.8432, 2.3627, 'alert', NOW(), NOW())
ON CONFLICT (code_iris) DO NOTHING;

-- Assign some to the test club
UPDATE territories
SET owner_club_id = (SELECT id FROM clubs WHERE name = 'Club Local' LIMIT 1)
WHERE code_iris IN ('750010201', '750030103')
  AND status = 'conquered';

UPDATE territories
SET owner_club_id = (SELECT id FROM clubs WHERE name = 'Club Local' LIMIT 1)
WHERE code_iris IN ('750010203', '750040103')
  AND status = 'locked';

COMMIT;
