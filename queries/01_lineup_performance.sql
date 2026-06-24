-- ============================================================
-- Query 01: Batting Performance by Lineup Position
-- ============================================================
-- PURPOSE: Identify which batting order slots are producing
-- the most offensive value. Useful for lineup optimization
-- and identifying underperforming positions.
--
-- TECHNIQUES: CTE, aggregation, NULLIF for safe division,
-- ROUND for readable decimals, CASE for derived metrics
-- ============================================================

WITH lineup_stats AS (
    SELECT
        ab.batter_id,
        ab.inning,
        ab.result,
        ab.is_hit,
        ab.runner_on_2b,
        ab.runner_on_3b,
        ab.home_score,
        ab.away_score,
        ab.game_id,

        -- Derive total bases from result for SLG calculation
        CASE
            WHEN ab.result = 'single'   THEN 1
            WHEN ab.result = 'double'   THEN 2
            WHEN ab.result = 'triple'   THEN 3
            WHEN ab.result = 'home_run' THEN 4
            ELSE 0
        END AS total_bases,

        -- On base events
        CASE
            WHEN ab.result IN ('single','double','triple','home_run','walk','hbp')
            THEN 1 ELSE 0
        END AS on_base

    FROM at_bats ab
),

aggregated AS (
    SELECT
        batter_id,
        COUNT(*)                                AS plate_appearances,
        SUM(is_hit::int)                        AS hits,
        SUM(total_bases)                        AS total_bases,
        SUM(on_base)                            AS times_on_base,
        COUNT(*) FILTER (WHERE result = 'home_run')  AS home_runs,
        COUNT(*) FILTER (WHERE result = 'walk')      AS walks,
        COUNT(*) FILTER (WHERE result = 'strikeout') AS strikeouts
    FROM lineup_stats
    GROUP BY batter_id
    HAVING COUNT(*) >= 20   -- minimum 20 PA to filter small samples
)

SELECT
    batter_id,
    plate_appearances,
    hits,
    home_runs,
    walks,
    strikeouts,

    -- Batting Average: hits / at bats (exclude walks and HBP)
    ROUND(
        hits::numeric / NULLIF(plate_appearances - walks, 0)
    , 3) AS batting_avg,

    -- On Base Percentage: times on base / plate appearances
    ROUND(
        times_on_base::numeric / NULLIF(plate_appearances, 0)
    , 3) AS obp,

    -- Slugging: total bases / at bats
    ROUND(
        total_bases::numeric / NULLIF(plate_appearances - walks, 0)
    , 3) AS slg,

    -- OPS: OBP + SLG (most common quick power/contact combo metric)
    ROUND(
        (times_on_base::numeric / NULLIF(plate_appearances, 0))
        +
        (total_bases::numeric / NULLIF(plate_appearances - walks, 0))
    , 3) AS ops,

    -- Strikeout rate: useful for contact quality assessment
    ROUND(
        strikeouts::numeric / NULLIF(plate_appearances, 0)
    , 3) AS strikeout_rate,

    -- Walk rate: measures plate discipline
    ROUND(
        walks::numeric / NULLIF(plate_appearances, 0)
    , 3) AS walk_rate

FROM aggregated
ORDER BY ops DESC;