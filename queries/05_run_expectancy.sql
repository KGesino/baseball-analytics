-- ============================================================
-- Query 05: Run Expectancy Matrix
-- ============================================================
-- PURPOSE: Calculate the average runs scored from each of
-- the 24 possible base/out states. The classic sabermetric
-- RE24 table. Used to evaluate in-game decisions like
-- sacrifice bunts, stolen base attempts, and intentional walks.
--
-- Example: Bases empty, 0 outs = ~0.48 expected runs
--          Bases loaded, 0 outs = ~2.28 expected runs
--
-- TECHNIQUES: CASE for categorical derivation, GROUP BY,
-- aggregation, ORDER BY multiple columns
-- ============================================================

WITH base_out_states AS (
    -- Step 1: Label each at-bat with its base/out state
    -- There are 8 possible base states x 3 out counts = 24 states
    SELECT
        ab.game_id,
        ab.inning,
        ab.outs_before,
        ab.runs_scored,

        -- Encode the base state as a readable string
        -- 1 = runner present, _ = base empty
        CASE
            WHEN ab.runner_on_1b AND ab.runner_on_2b AND ab.runner_on_3b
                THEN '123'
            WHEN ab.runner_on_1b AND ab.runner_on_2b AND NOT ab.runner_on_3b
                THEN '12_'
            WHEN ab.runner_on_1b AND NOT ab.runner_on_2b AND ab.runner_on_3b
                THEN '1_3'
            WHEN NOT ab.runner_on_1b AND ab.runner_on_2b AND ab.runner_on_3b
                THEN '_23'
            WHEN ab.runner_on_1b AND NOT ab.runner_on_2b AND NOT ab.runner_on_3b
                THEN '1__'
            WHEN NOT ab.runner_on_1b AND ab.runner_on_2b AND NOT ab.runner_on_3b
                THEN '_2_'
            WHEN NOT ab.runner_on_1b AND NOT ab.runner_on_2b AND ab.runner_on_3b
                THEN '__3'
            ELSE '___'
        END                                         AS base_state,

        -- Flag whether runners are in scoring position
        CASE
            WHEN ab.runner_on_2b OR ab.runner_on_3b
            THEN TRUE ELSE FALSE
        END                                         AS risp

    FROM at_bats ab
    WHERE ab.outs_before IS NOT NULL
      AND ab.outs_before BETWEEN 0 AND 2
),

run_expectancy AS (
    -- Step 2: Aggregate runs scored by base/out state
    SELECT
        base_state,
        outs_before                                 AS outs,
        COUNT(*)                                    AS situations,
        SUM(runs_scored)                            AS total_runs,
        ROUND(AVG(runs_scored)::numeric, 3)        AS avg_runs_expected,
        ROUND(MAX(runs_scored)::numeric, 1)        AS max_runs_scored,

        -- What percentage of these situations scored at least 1 run
        ROUND(
            COUNT(*) FILTER (WHERE runs_scored > 0)::numeric
            / NULLIF(COUNT(*), 0)
        , 3)                                        AS pct_scored

    FROM base_out_states
    GROUP BY base_state, outs_before
)

SELECT
    base_state,
    outs,
    situations,
    avg_runs_expected,
    pct_scored,
    max_runs_scored,
    total_runs,

    -- Rank each state by run expectancy within its out count
    RANK() OVER (
        PARTITION BY outs
        ORDER BY avg_runs_expected DESC
    )                                               AS rank_within_outs

FROM run_expectancy
ORDER BY outs, avg_runs_expected DESC;