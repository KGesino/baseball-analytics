# ⚾ Baseball Analytics Platform

An end-to-end sports analytics platform simulating tools used by MLB front offices for data-driven roster and game strategy decisions.

Built with **Python**, **PostgreSQL**, and **Tableau** using real MLB pitch-level data from Baseball Savant (Statcast) and the Lahman Database.

---

## Dashboards

| Dashboard | Description |
|---|---|
| Lineup Optimizer | OPS, wOBA, and run contribution by batting order position |
| Situational Hitting | Clutch performance with RISP, late innings, and pressure splits |
| Pitcher vs. Batter | Pitch type heat maps, whiff rates, and zone-level matchup breakdowns |
| Performance Trends | Rolling 15-game batting average with hot/cold streak detection |
| Run Expectancy Matrix | 24 base/out state run values for in-game strategy evaluation |

*(Screenshots in `/docs/screenshots/` — Tableau workbook in `/tableau/`)*

---

## Tech Stack

- **Python** — data pipeline (pybaseball, pandas, SQLAlchemy)
- **PostgreSQL** — relational database with 6-table schema
- **Tableau** — interactive dashboard layer
- **SQL** — CTEs, window functions, aggregations across 120K+ pitch records

---

## Database Schema

Six normalized tables:

```
players → teams
games → teams (home + away)
lineups → games, players
at_bats → games, players (batter + pitcher)
pitches → at_bats, players
```

Full schema in `/schema/create_tables.sql`.

---

## Project Structure

```
baseball-analytics-platform/
├── schema/
│   ├── create_tables.sql       # Full DDL for all 6 tables
│   └── seed_data.sql           # Sample data for reviewers
├── queries/
│   ├── 01_lineup_performance.sql
│   ├── 02_clutch_hitting.sql
│   ├── 03_pitcher_batter_matchups.sql
│   ├── 04_rolling_trends.sql
│   └── 05_run_expectancy.sql
├── data_pipeline/
│   ├── fetch_statcast.py       # Pulls pitch data from Baseball Savant
│   └── load_lahman.py          # Loads player/team/game records
├── tableau/
│   └── baseball_platform.twbx
└── docs/
    └── screenshots/
```

---

## Quickstart

### Prerequisites
- Python 3.9+
- PostgreSQL 14+

### Setup

```bash
git clone https://github.com/YOUR_USERNAME/baseball-analytics-platform.git
cd baseball-analytics-platform

pip install -r requirements.txt

cp .env.example .env
# Edit .env with your PostgreSQL credentials

psql -U postgres -c "CREATE DATABASE baseball_analytics;"
psql -U postgres -d baseball_analytics -f schema/create_tables.sql

python data_pipeline/fetch_statcast.py
```

---

## Key SQL Techniques

- **Window functions** — rolling 15-game averages using `ROWS BETWEEN 14 PRECEDING AND CURRENT ROW`
- **CTEs** — multi-step situational hitting breakdowns
- **Aggregations** — OBP, SLG, wOBA derived from pitch-level data
- **FILTER clause** — RISP and late-inning splits in a single query pass

---

## Data

**Source:** Baseball Savant via `pybaseball` (Statcast pitch-level data)

**Coverage:** August 2023 — 121,165 pitches across 31,152 at-bats

**Pitch type breakdown:**

| Pitch Type | Avg Velocity | Count |
|---|---|---|
| FF (Four-seam fastball) | 94.2 mph | 38,054 |
| SI (Sinker) | 93.6 mph | 19,174 |
| SL (Slider) | 85.6 mph | 19,120 |
| CH (Changeup) | 85.5 mph | 13,393 |
| FC (Cutter) | 89.5 mph | 9,294 |
| CU (Curveball) | 78.7 mph | 7,891 |
| ST (Sweeper) | 81.9 mph | 7,826 |

**At-bat result breakdown:**

| Result | Count |
|---|---|
| Field out | 12,891 |
| Strikeout | 7,040 |
| Single | 4,416 |
| Walk | 2,503 |
| Double | 1,377 |
| Home run | 1,071 |

---

## Data Sources

- [Baseball Savant](https://baseballsavant.mlb.com/) via `pybaseball` — Statcast pitch data
- [Lahman Database](http://seanlahman.com/) — historical player and team records

---

## Notes

Foreign key constraints between `pitches`/`at_bats` and the `players` table are intentionally deferred. Statcast and Lahman player records are loaded from separate sources using shared MLBAM player IDs. Constraints will be restored via `ALTER TABLE` once the Lahman pipeline is complete.

---

*Built as a portfolio project demonstrating end-to-end data analytics skills.*