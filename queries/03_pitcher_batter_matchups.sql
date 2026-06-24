-- ============================================================
-- Query 03: Pitcher vs. Batter Matchup Stats
-- ============================================================
-- PURPOSE: Break down how each pitcher performs against
-- each batter by pitch type. Identifies which pitches
-- are most effective against specific hitters.
-- This powers the matchup heat map dashboard in Tableau.
--
-- TECHNIQUES: Multi-table aggregation, FILTER clause,
-- ROUND, NULLIF, GROUP BY multiple dimensions
-- ============================================================

WITH pitch_outcomes AS (
    SELECT
        p.pitcher_id,
        p.batter_id,
        p.pitch_type,
        COUNT(*)                                         AS pitches_thrown,

        -- Swinging strikes: batter swung and missed
        COUNT(*) FILTER (
            WHERE p.pitch_result = 'swinging_strike'
            OR p.pitch_result = 'swinging_strike_blocked'
        )                                                AS swinging_strikes,

        -- Called strikes: batter took a strike
        COUNT(*) FILTER (
            WHERE p.pitch_result = 'called_strike'
        )                                                AS called_strikes,

        -- Balls
        COUNT(*) FILTER (
            WHERE p.pitch_result = 'ball'
            OR p.pitch_result = 'blocked_ball'
        )                                                AS balls,

        -- Balls put in play
        COUNT(*) FILTER (
            WHERE p.pitch_result = 'hit_into_play'
        )                                                AS balls_in_play,

        -- Hits allowed on this pitch type
        COUNT(*) FILTER (
            WHERE p.hit_type IN ('single','double','triple','home_run')
        )                                                AS hits_allowed,

        -- Home runs allowed
        COUNT(*) FILTER (
            WHERE p.hit_type = 'home_run'
        )                                                AS home_runs_allowed,

        -- Velocity and Statcast metrics
        ROUND(AVG(p.velocity_mph)::numeric, 1)          AS avg_velocity,
        ROUND(AVG(p.exit_velocity)
            FILTER (WHERE p.exit_velocity IS NOT NULL)
        ::numeric, 1)                                    AS avg_exit_velo_allowed,
        ROUND(AVG(p.launch_angle)
            FILTER (WHERE p.launch_angle IS NOT NULL)
        ::numeric, 1)                                    AS avg_launch_angle

    FROM pitches p
    WHERE p.pitch_type IS NOT NULL
    GROUP BY p.pitcher_id, p.batter_id, p.pitch_type
    HAVING COUNT(*) >= 3   -- minimum 3 pitches for meaningful sample
),

with_rates AS (
    SELECT
        pitcher_id,
        batter_id,
        pitch_type,
        pitches_thrown,
        swinging_strikes,
        called_strikes,
        balls,
        balls_in_play,
        hits_allowed,
        home_runs_allowed,
        avg_velocity,
        avg_exit_velo_allowed,
        avg_launch_angle,

        -- Whiff rate: swinging strikes / total swings
        -- Key metric for pitch effectiveness
        ROUND(
            swinging_strikes::numeric / NULLIF(pitches_thrown, 0)
        , 3)                                             AS whiff_rate,

        -- Called strike rate
        ROUND(
            called_strikes::numeric / NULLIF(pitches_thrown, 0)
        , 3)                                             AS called_strike_rate,

        -- Total strike rate (swinging + called)
        ROUND(
            (swinging_strikes + called_strikes)::numeric
            / NULLIF(pitches_thrown, 0)
        , 3)                                             AS total_strike_rate,

        -- Batting average allowed on this pitch type
        ROUND(
            hits_allowed::numeric / NULLIF(balls_in_play, 0)
        , 3)                                             AS babip_allowed

    FROM pitch_outcomes
)

SELECT
    pitcher_id,
    batter_id,
    pitch_type,
    pitches_thrown,
    avg_velocity,
    whiff_rate,
    called_strike_rate,
    total_strike_rate,
    balls_in_play,
    hits_allowed,
    babip_allowed,
    home_runs_allowed,
    avg_exit_velo_allowed,
    avg_launch_angle
FROM with_rates
ORDER BY pitcher_id, batter_id, pitches_thrown DESC;