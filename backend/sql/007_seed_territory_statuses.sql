-- ============================================================
-- 007_seed_territory_statuses.sql
-- Initialize territory statuses and assign some clubs
-- ============================================================

BEGIN;

-- Create a test club if it doesn't exist
INSERT INTO clubs (id, name, city, region, description)
SELECT
  'a1234567-1234-1234-1234-123456789012'::uuid,
  'Club Local',
  'Paris',
  'Île-de-France',
  'Test club for territories'
WHERE NOT EXISTS (SELECT 1 FROM clubs WHERE name = 'Club Local');

-- Sample: Assign some territories to the test club with different statuses
WITH ranked_paris AS (
  SELECT code_iris, ROW_NUMBER() OVER (ORDER BY code_iris) as rn
  FROM territories
  WHERE code_iris LIKE '750%'
    AND owner_club_id IS NULL
)
UPDATE territories t
SET 
  status = 'conquered',
  owner_club_id = (SELECT id FROM clubs WHERE name = 'Club Local' LIMIT 1),
  conquered_at = NOW() - interval '30 days'
FROM ranked_paris rp
WHERE t.code_iris = rp.code_iris AND rp.rn <= 10;

-- Mark some as "locked" (contested but owned) - next 5
WITH ranked_paris AS (
  SELECT code_iris, ROW_NUMBER() OVER (ORDER BY code_iris) as rn
  FROM territories
  WHERE code_iris LIKE '75%'
    AND status = 'available'
)
UPDATE territories t
SET status = 'locked'
FROM ranked_paris rp
WHERE t.code_iris = rp.code_iris AND rp.rn <= 5;

-- Mark some as "alert" (about to be contested) - next 5
WITH ranked_paris_2 AS (
  SELECT code_iris, ROW_NUMBER() OVER (ORDER BY code_iris) as rn
  FROM territories
  WHERE code_iris LIKE '75%'
    AND status = 'available'
    AND code_iris NOT IN (SELECT code_iris FROM territories WHERE status = 'locked')
)
UPDATE territories t
SET status = 'alert'
FROM ranked_paris_2 rp
WHERE t.code_iris = rp.code_iris AND rp.rn <= 5;

-- Mark some as "conflict" (actively disputed) - next 3
WITH ranked_paris_3 AS (
  SELECT code_iris, ROW_NUMBER() OVER (ORDER BY code_iris) as rn
  FROM territories
  WHERE code_iris LIKE '75%'
    AND status = 'available'
    AND code_iris NOT IN (
      SELECT code_iris FROM territories WHERE status IN ('locked', 'alert')
    )
)
UPDATE territories t
SET status = 'conflict'
FROM ranked_paris_3 rp
WHERE t.code_iris = rp.code_iris AND rp.rn <= 3;

-- Rest remain "available"

COMMIT;
