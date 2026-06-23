-- ============================================================
-- Baseball Analytics Platform — Database Schema
-- ============================================================

-- Drop tables in reverse dependency order (safe to re-run)
DROP TABLE IF EXISTS pitches CASCADE;
DROP TABLE IF EXISTS at_bats CASCADE;
DROP TABLE IF EXISTS lineups CASCADE;
DROP TABLE IF EXISTS games CASCADE;
DROP TABLE IF EXISTS players CASCADE;
DROP TABLE IF EXISTS teams CASCADE;


-- ── Teams ────────────────────────────────────────────────────
CREATE TABLE teams (
    team_id       SERIAL PRIMARY KEY,
    team_name     VARCHAR(100) NOT NULL,
    abbreviation  VARCHAR(5)   NOT NULL,
    league        VARCHAR(2)   CHECK (league IN ('AL', 'NL')),
    division      VARCHAR(5)   CHECK (division IN ('East', 'West', 'Central')),
    season_year   INT          NOT NULL
);


-- ── Players ──────────────────────────────────────────────────
CREATE TABLE players (
    player_id      INT PRIMARY KEY,   -- use MLB player ID (MLBAM ID from Statcast)
    team_id        INT REFERENCES teams(team_id),
    first_name     VARCHAR(100),
    last_name      VARCHAR(100),
    position       VARCHAR(5),
    bats           CHAR(1) CHECK (bats IN ('L', 'R', 'S')),
    throws         CHAR(1) CHECK (throws IN ('L', 'R')),
    birth_date     DATE,
    jersey_number  INT
);


-- ── Games ────────────────────────────────────────────────────
CREATE TABLE games (
    game_id        INT PRIMARY KEY,   -- use Statcast game_pk
    home_team_id   INT REFERENCES teams(team_id),
    away_team_id   INT REFERENCES teams(team_id),
    game_date      DATE NOT NULL,
    season_year    INT  NOT NULL,
    inning_final   INT,
    home_score     INT,
    away_score     INT,
    venue          VARCHAR(100),
    game_type      VARCHAR(20) CHECK (game_type IN ('regular', 'playoff', 'wildcard'))
);


-- ── Lineups ──────────────────────────────────────────────────
CREATE TABLE lineups (
    lineup_id         SERIAL PRIMARY KEY,
    game_id           INT  REFERENCES games(game_id),
    player_id         INT  REFERENCES players(player_id),
    team_id           INT  REFERENCES teams(team_id),
    batting_order     INT  CHECK (batting_order BETWEEN 1 AND 9),
    fielding_position VARCHAR(5),
    is_starter        BOOLEAN DEFAULT TRUE
);


-- ── At Bats ──────────────────────────────────────────────────
CREATE TABLE at_bats (
    at_bat_id       SERIAL PRIMARY KEY,
    game_id         BIGINT,
    at_bat_number   BIGINT,
    batter_id       BIGINT,
    pitcher_id      BIGINT,
    inning          BIGINT,
    half_inning     TEXT,
    outs_before     BIGINT,
    runner_on_1b    BOOLEAN DEFAULT FALSE,
    runner_on_2b    BOOLEAN DEFAULT FALSE,
    runner_on_3b    BOOLEAN DEFAULT FALSE,
    hit_type        TEXT,
    home_score      BIGINT,
    away_score      BIGINT,
    game_date       TIMESTAMP,
    result          TEXT,
    is_hit          BOOLEAN DEFAULT FALSE,
    runs_scored     BIGINT DEFAULT 0,
    is_rbi          BOOLEAN DEFAULT FALSE
);


-- ── Pitches ──────────────────────────────────────────────────
CREATE TABLE pitches (
    pitch_id        SERIAL PRIMARY KEY,
    at_bat_id       INT,
    game_id         INT,
    pitcher_id      INT,
    batter_id       INT,
    at_bat_number   INT,
    pitch_number    INT,
    pitch_type      VARCHAR(10),
    velocity_mph    NUMERIC(5,2),
    plate_x         NUMERIC(6,3),
    plate_z         NUMERIC(6,3),
    zone            INT,
    pitch_result    VARCHAR(50),
    hit_type        VARCHAR(50),
    launch_angle    NUMERIC(6,2),
    exit_velocity   NUMERIC(6,2),
    inning          INT,
    half_inning     VARCHAR(3),
    outs_before     INT,
    runner_on_1b    BOOLEAN DEFAULT FALSE,
    runner_on_2b    BOOLEAN DEFAULT FALSE,
    runner_on_3b    BOOLEAN DEFAULT FALSE,
    home_score      INT,
    away_score      INT,
    home_team       VARCHAR(5),
    away_team       VARCHAR(5),
    game_date       DATE
);


-- ── Indexes (speeds up your most common query patterns) ──────
CREATE INDEX idx_pitches_game       ON pitches(game_id);
CREATE INDEX idx_pitches_pitcher    ON pitches(pitcher_id);
CREATE INDEX idx_pitches_batter     ON pitches(batter_id);
CREATE INDEX idx_pitches_pitch_type ON pitches(pitch_type);
CREATE INDEX idx_at_bats_game       ON at_bats(game_id);
CREATE INDEX idx_at_bats_batter     ON at_bats(batter_id);
CREATE INDEX idx_at_bats_pitcher    ON at_bats(pitcher_id);
CREATE INDEX idx_at_bats_result     ON at_bats(result);