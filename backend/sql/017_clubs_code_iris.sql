ALTER TABLE clubs
ADD COLUMN IF NOT EXISTS code_iris VARCHAR(9) NULL;

CREATE INDEX IF NOT EXISTS idx_clubs_code_iris
ON clubs(code_iris);
