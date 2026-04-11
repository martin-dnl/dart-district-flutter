-- Recompute ranked player_stats from completed ranked matches.
-- This migration is intentionally idempotent and can be re-run safely.

WITH ranked_matches AS (
  SELECT
    m.id,
    COALESCE(m.ended_at, m.created_at) AS played_at
  FROM matches m
  WHERE m.status = 'completed'
    AND m.is_ranked = TRUE
),
player_match_base AS (
  SELECT
    mp.user_id,
    mp.match_id,
    rm.played_at,
    COALESCE(mp.is_winner, FALSE) AS won
  FROM match_players mp
  JOIN ranked_matches rm ON rm.id = mp.match_id
),
player_match_throws AS (
  SELECT
    pmb.user_id,
    pmb.match_id,
    pmb.played_at,
    pmb.won,
    t.score,
    t.segment,
    t.is_checkout
  FROM player_match_base pmb
  LEFT JOIN sets s ON s.match_id = pmb.match_id
  LEFT JOIN legs l ON l.set_id = s.id
  LEFT JOIN throws t ON t.leg_id = l.id AND t.user_id = pmb.user_id
),
player_match_stats AS (
  SELECT
    pmt.user_id,
    pmt.match_id,
    pmt.played_at,
    pmt.won,
    ROUND(COALESCE(AVG(pmt.score), 0)::numeric, 2) AS avg_score,
    COALESCE(MAX(CASE WHEN pmt.is_checkout THEN pmt.score ELSE 0 END), 0) AS high_finish,
    COALESCE(SUM(CASE WHEN pmt.score = 180 THEN 1 ELSE 0 END), 0) AS total_180s,
    COALESCE(SUM(CASE WHEN pmt.score >= 140 THEN 1 ELSE 0 END), 0) AS count_140_plus,
    COALESCE(SUM(CASE WHEN pmt.score >= 100 THEN 1 ELSE 0 END), 0) AS count_100_plus,
    COALESCE(SUM(CASE WHEN pmt.is_checkout THEN 1 ELSE 0 END), 0) AS checkout_hits,
    COALESCE(SUM(
      CASE
        WHEN pmt.segment LIKE 'CD%' THEN COALESCE(NULLIF(SUBSTRING(pmt.segment FROM 3), '')::int, 0)
        WHEN pmt.segment LIKE 'CHECKOUT_D%' THEN COALESCE(NULLIF(SUBSTRING(pmt.segment FROM 11), '')::int, 0)
        WHEN pmt.is_checkout THEN 1
        ELSE 0
      END
    ), 0) AS checkout_attempts
  FROM player_match_throws pmt
  GROUP BY pmt.user_id, pmt.match_id, pmt.played_at, pmt.won
),
leg_wins AS (
  SELECT
    pmb.user_id,
    pmb.match_id,
    l.id AS leg_id
  FROM player_match_base pmb
  JOIN sets s ON s.match_id = pmb.match_id
  JOIN legs l ON l.set_id = s.id
  WHERE l.winner_id = pmb.user_id
),
leg_darts AS (
  SELECT
    lw.user_id,
    lw.match_id,
    lw.leg_id,
    COUNT(t.id) AS throw_count,
    (
      ARRAY_AGG(t.segment ORDER BY t.created_at DESC)
      FILTER (WHERE t.is_checkout)
    )[1] AS checkout_segment
  FROM leg_wins lw
  JOIN throws t ON t.leg_id = lw.leg_id AND t.user_id = lw.user_id
  GROUP BY lw.user_id, lw.match_id, lw.leg_id
),
best_leg_per_match AS (
  SELECT
    ld.user_id,
    ld.match_id,
    MIN(
      ((ld.throw_count - 1) * 3) +
      LEAST(
        3,
        GREATEST(
          1,
          CASE
            WHEN ld.checkout_segment LIKE 'CD%' THEN COALESCE(NULLIF(SUBSTRING(ld.checkout_segment FROM 3), '')::int, 3)
            WHEN ld.checkout_segment LIKE 'CHECKOUT_D%' THEN COALESCE(NULLIF(SUBSTRING(ld.checkout_segment FROM 11), '')::int, 3)
            ELSE 3
          END
        )
      )
    ) AS best_leg_darts
  FROM leg_darts ld
  GROUP BY ld.user_id, ld.match_id
),
player_agg AS (
  SELECT
    pms.user_id,
    COUNT(*)::int AS matches_played,
    SUM(CASE WHEN pms.won THEN 1 ELSE 0 END)::int AS matches_won,
    ROUND(AVG(pms.avg_score)::numeric, 2) AS avg_score,
    ROUND(MAX(pms.avg_score)::numeric, 2) AS best_avg,
    CASE
      WHEN SUM(pms.checkout_attempts) > 0
        THEN ROUND((SUM(pms.checkout_hits)::numeric * 100.0) / SUM(pms.checkout_attempts), 2)
      ELSE 0
    END AS checkout_rate,
    SUM(pms.total_180s)::int AS total_180s,
    MAX(pms.high_finish)::int AS high_finish,
    SUM(pms.count_140_plus)::int AS count_140_plus,
    SUM(pms.count_100_plus)::int AS count_100_plus,
    COALESCE(MIN(NULLIF(blm.best_leg_darts, 0)), 0)::int AS best_leg_darts,
    MAX(pms.played_at)::date AS last_played_date
  FROM player_match_stats pms
  LEFT JOIN best_leg_per_match blm
    ON blm.user_id = pms.user_id
   AND blm.match_id = pms.match_id
  GROUP BY pms.user_id
),
play_days AS (
  SELECT DISTINCT
    pmb.user_id,
    pmb.played_at::date AS play_day
  FROM player_match_base pmb
),
day_groups AS (
  SELECT
    pd.user_id,
    pd.play_day,
    (pd.play_day - (ROW_NUMBER() OVER (PARTITION BY pd.user_id ORDER BY pd.play_day))::int) AS grp
  FROM play_days pd
),
streaks AS (
  SELECT
    dg.user_id,
    dg.grp,
    COUNT(*)::int AS streak_len,
    MAX(dg.play_day) AS streak_end
  FROM day_groups dg
  GROUP BY dg.user_id, dg.grp
),
current_streak AS (
  SELECT DISTINCT ON (s.user_id)
    s.user_id,
    s.streak_len AS consecutive_days_played,
    s.streak_end AS last_played_date
  FROM streaks s
  ORDER BY s.user_id, s.streak_end DESC
)
UPDATE player_stats ps
SET
  matches_played = 0,
  matches_won = 0,
  avg_score = 0,
  best_avg = 0,
  checkout_rate = 0,
  total_180s = 0,
  high_finish = 0,
  best_leg_darts = 0,
  count_140_plus = 0,
  count_100_plus = 0,
  precision_t20 = 0,
  precision_t19 = 0,
  precision_double = 0,
  consecutive_days_played = 0,
  last_played_date = NULL,
  updated_at = NOW();

UPDATE player_stats ps
SET
  matches_played = pa.matches_played,
  matches_won = pa.matches_won,
  avg_score = pa.avg_score,
  best_avg = pa.best_avg,
  checkout_rate = pa.checkout_rate,
  total_180s = pa.total_180s,
  high_finish = pa.high_finish,
  best_leg_darts = pa.best_leg_darts,
  count_140_plus = pa.count_140_plus,
  count_100_plus = pa.count_100_plus,
  consecutive_days_played = COALESCE(cs.consecutive_days_played, 0),
  last_played_date = COALESCE(cs.last_played_date, pa.last_played_date),
  updated_at = NOW()
FROM player_agg pa
LEFT JOIN current_streak cs ON cs.user_id = pa.user_id
WHERE ps.user_id = pa.user_id;