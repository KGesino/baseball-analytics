-- ============================================================
-- Query 02: Clutch / Situational Hitting
-- ============================================================
-- PURPOSE: Measure how batters perform in high-leverage
-- situations vs. overall. The clutch_delta column is the
-- key metric — positive means the batter elevates under
-- pressure, negative means they decline.
--
-- TECHNIQUES: CTE, FILTER clause for conditional aggregation,
-- NULLIF for safe division, window function RANK(),
-- derived clutch delta metric
-- ============================================================

WITH situational AS (
    SELECT
        ab.batter_id,

        -- Overall counting stats
        COUNT(*)                                        AS total_pa,
        SUM(ab.is_hit::int)                            AS total_hits,
        COUNT(*) FILTER (
            WHERE ab.result IN ('walk','hbp')
        )                                               AS total_walks,

        -- RISP: runner on 2nd or 3rd (Runners In Scoring Position)
        COUNT(*) FILTER (
            WHERE ab.runner_on_2b = TRUE OR ab.runner_on_3b = TRUE
        )                                               AS risp_pa,
        SUM(ab.is_hit::int) FILTER (
            WHERE ab.runner_on_2b = TRUE OR ab.runner_on_3b = TRUE
        )                                               AS risp_hits,

        -- Late & close: inning 7 or later, score within 2 runs
        COUNT(*) FILTER (
            WHERE ab.inning >= 7
            AND ABS(ab.home_score - ab.away_score) <= 2
        )                                               AS late_close_pa,
        SUM(ab.is_hit::int) FILTER (
            WHERE ab.inning >= 7
            AND ABS(ab.home_score - ab.away_score) <= 2
        )                                               AS late_close_hits,

        -- Bases loaded situations
        COUNT(*) FILTER (
            WHERE ab.runner_on_1b = TRUE
            AND ab.runner_on_2b = TRUE
            AND ab.runner_on_3b = TRUE
        )                                               AS bases_loaded_pa,
        SUM(ab.is_hit::int) FILTER (
            WHERE ab.runner_on_1b = TRUE
            AND ab.runner_on_2b = TRUE
            AND ab.runner_on_3b = TRUE
        )                                               AS bases_loaded_hits,

        -- Two out situations
        COUNT(*) FILTER (
            WHERE ab.outs_before = 2
        )                                               AS two_out_pa,
        SUM(ab.is_hit::int) FILTER (
            WHERE ab.outs_before = 2
        )                                               AS two_out_hits

    FROM at_bats ab
    GROUP BY ab.batter_id
    HAVING COUNT(*) >= 50   -- minimum PA threshold for meaningful sample
),

with_rates AS (
    SELECT
        batter_id,
        total_pa,
        total_hits,

        -- Overall batting average
        ROUND(
            total_hits::numeric / NULLIF(total_pa - total_walks, 0)
        , 3)                                            AS overall_avg,

        -- RISP average
        risp_pa,
        risp_hits,
        ROUND(
            risp_hits::numeric / NULLIF(risp_pa, 0)
        , 3)                                            AS risp_avg,

        -- Late and close average
        late_close_pa,
        late_close_hits,
        ROUND(
            late_close_hits::numeric / NULLIF(late_close_pa, 0)
        , 3)                                            AS late_close_avg,

        -- Bases loaded average
        bases_loaded_pa,
        bases_loaded_hits,
        ROUND(
            bases_loaded_hits::numeric / NULLIF(bases_loaded_pa, 0)
        , 3)                                            AS bases_loaded_avg,

        -- Two out average
        two_out_pa,
        two_out_hits,
        ROUND(
            two_out_hits::numeric / NULLIF(two_out_pa, 0)
        , 3)                                            AS two_out_avg,

        total_walks
    FROM situational
),

ranked AS (
    SELECT *,
        -- Clutch delta: how much better/worse with RISP vs overall
        -- Positive = elevates under pressure, Negative = declines
        ROUND(
            risp_avg - overall_avg
        , 3)                                            AS clutch_delta,

        -- Rank batters by RISP average
        RANK() OVER (
            ORDER BY risp_hits::numeric / NULLIF(risp_pa, 0) DESC
        )                                               AS risp_rank
    FROM with_rates
    WHERE risp_pa >= 10   -- need meaningful RISP sample
)

SELECT
    risp_rank,
    batter_id,
    total_pa,
    overall_avg,
    risp_pa,
    risp_avg,
    late_close_pa,
    late_close_avg,
    two_out_pa,
    two_out_avg,
    bases_loaded_pa,
    bases_loaded_avg,
    clutch_delta
FROM ranked
ORDER BY risp_rank
LIMIT 30;