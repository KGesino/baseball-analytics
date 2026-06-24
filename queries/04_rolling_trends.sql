-- ============================================================
-- Query 04: Rolling 15-Game Performance Trends
-- ============================================================
-- PURPOSE: Track how a batter's performance changes over
-- time using a rolling window. Identifies hot/cold streaks
-- that single-game or season stats would hide.
--
-- TECHNIQUES: Window functions with ROWS BETWEEN frame,
-- PARTITION BY, ROW_NUMBER, multiple CTEs, date ordering
-- This query demonstrates the most advanced SQL in the project
-- ============================================================

WITH game_batting AS (
    -- Step 1: Aggregate each batter's stats per game
    -- We need one row per batter per game before applying
    -- the rolling window
    SELECT
        ab.batter_id,
        ab.game_id,
        ab.game_date,
        COUNT(*)                                    AS pa,
        SUM(ab.is_hit::int)                        AS hits,
        COUNT(*) FILTER (
            WHERE ab.result = 'home_run'
        )                                           AS home_runs,
        COUNT(*) FILTER (
            WHERE ab.result IN ('walk','hbp')
        )                                           AS walks,
        COUNT(*) FILTER (
            WHERE ab.result = 'strikeout'
        )                                           AS strikeouts,
        SUM(
            CASE
                WHEN ab.result = 'single'   THEN 1
                WHEN ab.result = 'double'   THEN 2
                WHEN ab.result = 'triple'   THEN 3
                WHEN ab.result = 'home_run' THEN 4
                ELSE 0
            END
        )                                           AS total_bases
    FROM at_bats ab
    WHERE ab.game_date IS NOT NULL
    GROUP BY ab.batter_id, ab.game_id, ab.game_date
),

with_rolling AS (
    -- Step 2: Apply rolling window functions over each
    -- batter's game-by-game history, ordered by date
    SELECT
        gb.batter_id,
        gb.game_date,
        gb.game_id,
        gb.pa,
        gb.hits,
        gb.home_runs,
        gb.walks,
        gb.strikeouts,
        gb.total_bases,

        -- Single game average
        ROUND(
            gb.hits::numeric / NULLIF(gb.pa - gb.walks, 0)
        , 3)                                        AS game_avg,

        -- Rolling 15-game hit sum
        SUM(gb.hits) OVER (
            PARTITION BY gb.batter_id
            ORDER BY gb.game_date
            ROWS BETWEEN 14 PRECEDING AND CURRENT ROW
        )                                           AS rolling_15g_hits,

        -- Rolling 15-game PA sum
        SUM(gb.pa) OVER (
            PARTITION BY gb.batter_id
            ORDER BY gb.game_date
            ROWS BETWEEN 14 PRECEDING AND CURRENT ROW
        )                                           AS rolling_15g_pa,

        -- Rolling 15-game walk sum
        SUM(gb.walks) OVER (
            PARTITION BY gb.batter_id
            ORDER BY gb.game_date
            ROWS BETWEEN 14 PRECEDING AND CURRENT ROW
        )                                           AS rolling_15g_walks,

        -- Rolling 15-game total bases
        SUM(gb.total_bases) OVER (
            PARTITION BY gb.batter_id
            ORDER BY gb.game_date
            ROWS BETWEEN 14 PRECEDING AND CURRENT ROW
        )                                           AS rolling_15g_total_bases,

        -- Rolling 15-game home runs
        SUM(gb.home_runs) OVER (
            PARTITION BY gb.batter_id
            ORDER BY gb.game_date
            ROWS BETWEEN 14 PRECEDING AND CURRENT ROW
        )                                           AS rolling_15g_hr,

        -- Rolling 15-game strikeouts
        SUM(gb.strikeouts) OVER (
            PARTITION BY gb.batter_id
            ORDER BY gb.game_date
            ROWS BETWEEN 14 PRECEDING AND CURRENT ROW
        )                                           AS rolling_15g_k,

        -- Game sequence number per batter
        -- Used to filter out early games before window is full
        ROW_NUMBER() OVER (
            PARTITION BY gb.batter_id
            ORDER BY gb.game_date
        )                                           AS game_seq

    FROM game_batting gb
),

with_rates AS (
    -- Step 3: Calculate rolling rates from rolling sums
    -- Only include rows where we have a full 15-game window
    SELECT
        batter_id,
        game_date,
        game_id,
        game_seq,
        pa,
        hits,
        game_avg,
        rolling_15g_hits,
        rolling_15g_pa,
        rolling_15g_hr,
        rolling_15g_k,

        -- Rolling batting average
        ROUND(
            rolling_15g_hits::numeric
            / NULLIF(rolling_15g_pa - rolling_15g_walks, 0)
        , 3)                                        AS rolling_avg,

        -- Rolling OBP
        ROUND(
            (rolling_15g_hits + rolling_15g_walks)::numeric
            / NULLIF(rolling_15g_pa, 0)
        , 3)                                        AS rolling_obp,

        -- Rolling SLG
        ROUND(
            rolling_15g_total_bases::numeric
            / NULLIF(rolling_15g_pa - rolling_15g_walks, 0)
        , 3)                                        AS rolling_slg,

        -- Rolling OPS
        ROUND(
            (rolling_15g_hits + rolling_15g_walks)::numeric
                / NULLIF(rolling_15g_pa, 0)
            +
            rolling_15g_total_bases::numeric
                / NULLIF(rolling_15g_pa - rolling_15g_walks, 0)
        , 3)                                        AS rolling_ops,

        -- Rolling strikeout rate
        ROUND(
            rolling_15g_k::numeric
            / NULLIF(rolling_15g_pa, 0)
        , 3)                                        AS rolling_k_rate

    FROM with_rolling
    WHERE game_seq >= 15  -- only show once full window is available
)

SELECT
    batter_id,
    game_date,
    game_seq,
    pa,
    hits,
    game_avg,
    rolling_avg,
    rolling_obp,
    rolling_slg,
    rolling_ops,
    rolling_k_rate,
    rolling_15g_hr
FROM with_rates
ORDER BY batter_id, game_date;