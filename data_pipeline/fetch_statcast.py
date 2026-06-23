import pandas as pd
from pybaseball import statcast
from sqlalchemy import create_engine, text
from dotenv import load_dotenv
import os
import time

load_dotenv()

# ── Database connection ───────────────────────────────────────────────────────

def get_engine():
    url = (
        f"postgresql://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}"
        f"@{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"
    )
    return create_engine(url)


# ── Column mapping ────────────────────────────────────────────────────────────
# Statcast returns ~90 columns. We select and rename only what we need.

PITCH_COLUMN_MAP = {
    "game_pk":            "game_id",
    "batter":             "batter_id",
    "pitcher":            "pitcher_id",
    "pitch_number":       "pitch_number",
    "pitch_type":         "pitch_type",
    "release_speed":      "velocity_mph",
    "plate_x":            "plate_x",
    "plate_z":            "plate_z",
    "zone":               "zone",
    "description":        "pitch_result",
    "events":             "hit_type",
    "launch_angle":       "launch_angle",
    "launch_speed":       "exit_velocity",
    "at_bat_number":      "at_bat_number",
    "inning":             "inning",
    "inning_topbot":      "half_inning",
    "outs_when_up":       "outs_before",
    "on_1b":              "runner_on_1b",
    "on_2b":              "runner_on_2b",
    "on_3b":              "runner_on_3b",
    "home_score":         "home_score",
    "away_score":         "away_score",
    "home_team":          "home_team",
    "away_team":          "away_team",
    "game_date":          "game_date",
}

AT_BAT_RESULT_MAP = {
    "single":             "single",
    "double":             "double",
    "triple":             "triple",
    "home_run":           "home_run",
    "strikeout":          "strikeout",
    "walk":               "walk",
    "hit_by_pitch":       "hbp",
    "field_out":          "field_out",
    "grounded_into_double_play": "gdp",
    "force_out":          "field_out",
    "sac_fly":            "sac_fly",
    "sac_bunt":           "sac_bunt",
}


# ── Fetch and clean ───────────────────────────────────────────────────────────

def fetch_statcast_data(start_date: str, end_date: str) -> pd.DataFrame:
    """
    Pull raw Statcast pitch-level data for a date range.
    Start small — one month is ~30,000 rows and fetches in ~60 seconds.
    """
    print(f"Fetching Statcast data from {start_date} to {end_date}...")
    
    # pybaseball rate-limits gracefully but can timeout on long ranges.
    # For ranges > 1 month, chunk by week (see fetch_range_chunked below).
    df = statcast(start_dt=start_date, end_dt=end_date)
    
    print(f"  Raw rows fetched: {len(df):,}")
    print(f"  Columns available: {len(df.columns)}")
    return df


def clean_pitches(df: pd.DataFrame) -> pd.DataFrame:
    """
    Select, rename, and type-cast columns to match our pitches schema.
    Also derive at_bat-level fields we'll need for the at_bats table.
    """
    # Keep only mapped columns (drop the ~65 we don't need)
    available = [c for c in PITCH_COLUMN_MAP if c in df.columns]
    df = df[available].rename(columns=PITCH_COLUMN_MAP)
    
    # Boolean runner columns — Statcast stores as player IDs or NaN
    for col in ["runner_on_1b", "runner_on_2b", "runner_on_3b"]:
        if col in df.columns:
            df[col] = df[col].notna()  # True if a runner ID is present
    
    # Normalize half_inning to 'top'/'bot'
    if "half_inning" in df.columns:
        df["half_inning"] = df["half_inning"].str.lower().str.strip()
    
    # Cast numeric columns — Statcast sometimes returns them as objects
    numeric_cols = ["velocity_mph", "plate_x", "plate_z", "launch_angle",
                    "exit_velocity", "inning", "outs_before", "pitch_number"]
    for col in numeric_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    
    # game_date to proper date type
    if "game_date" in df.columns:
        df["game_date"] = pd.to_datetime(df["game_date"])
    
    # Drop rows with no pitcher or batter (rare but happens)
    df = df.dropna(subset=["pitcher_id", "batter_id", "game_id"])
    
    print(f"  Rows after cleaning: {len(df):,}")
    return df


def derive_at_bats(df: pd.DataFrame) -> pd.DataFrame:
    """
    Statcast is pitch-level. We aggregate to at_bat-level for our at_bats table.
    The last pitch of each at-bat carries the 'events' column (single, strikeout, etc.)
    """
    # Last pitch per at-bat has the result
    at_bat_cols = [
        "game_id", "at_bat_number", "batter_id", "pitcher_id",
        "inning", "half_inning", "outs_before",
        "runner_on_1b", "runner_on_2b", "runner_on_3b",
        "hit_type", "home_score", "away_score", "game_date",
    ]
    available = [c for c in at_bat_cols if c in df.columns]
    
    # Each unique (game_id, at_bat_number) is one plate appearance
    # Take the last pitch row — it holds the final 'events' outcome
    at_bats = (
        df.sort_values("pitch_number")
          .groupby(["game_id", "at_bat_number"], as_index=False)
          .last()
    )[available]
    
    # Map raw Statcast event strings to our cleaner result vocabulary
    if "hit_type" in at_bats.columns:
        at_bats["result"] = at_bats["hit_type"].map(AT_BAT_RESULT_MAP).fillna("other")
        at_bats["is_hit"] = at_bats["result"].isin(
            ["single", "double", "triple", "home_run"]
        )
    
    # Runs scored is tricky from Statcast — approximate from score delta
    # (A proper implementation would use game-by-game score tracking)
    at_bats["runs_scored"] = 0  # placeholder — refine with Retrosheet if needed
    at_bats["is_rbi"] = False   # placeholder
    
    print(f"  At-bats derived: {len(at_bats):,}")
    return at_bats


# ── Load to PostgreSQL ────────────────────────────────────────────────────────

def load_to_postgres(df: pd.DataFrame, table_name: str, engine, if_exists="append"):
    print(f"  Loading {len(df):,} rows into '{table_name}'...")
    df.to_sql(
        table_name,
        engine,
        if_exists=if_exists,
        index=False,
        chunksize=500,
        method=None,      # changed from "multi" to None
    )
    print(f"  Done.")


def verify_load(table_name: str, engine):
    with engine.connect() as conn:
        result = conn.execute(text(f"SELECT COUNT(*) FROM {table_name}"))
        count = result.scalar()
        print(f"  Verified: {table_name} has {count:,} rows")


# ── Chunked fetch for larger date ranges ─────────────────────────────────────

def fetch_range_chunked(start_date: str, end_date: str, chunk_days: int = 7):
    """
    For date ranges > 1 month, pybaseball can hit rate limits or timeouts.
    This fetches week-by-week and concatenates. Safe for full-season pulls.
    """
    from datetime import datetime, timedelta
    
    start = datetime.strptime(start_date, "%Y-%m-%d")
    end   = datetime.strptime(end_date,   "%Y-%m-%d")
    chunks = []
    current = start
    
    while current < end:
        chunk_end = min(current + timedelta(days=chunk_days), end)
        print(f"\nChunk: {current.date()} → {chunk_end.date()}")
        try:
            chunk = statcast(
                start_dt=current.strftime("%Y-%m-%d"),
                end_dt=chunk_end.strftime("%Y-%m-%d")
            )
            if not chunk.empty:
                chunks.append(chunk)
        except Exception as e:
            print(f"  WARNING: chunk failed ({e}), skipping")
        current = chunk_end + timedelta(days=1)
        time.sleep(2)  # be polite to the Baseball Savant servers
    
    return pd.concat(chunks, ignore_index=True) if chunks else pd.DataFrame()


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    engine = get_engine()
    
    # Start with ONE month for development — expand once everything works
    START = "2023-08-01"
    END   = "2023-08-31"
    
    # 1. Fetch
    raw_df = fetch_statcast_data(START, END)
    
    # 2. Save raw backup (useful for debugging without re-fetching)
    raw_df.to_csv("data_pipeline/raw_statcast_aug2023.csv", index=False)
    print("Raw CSV saved.")
    
    # 3. Clean pitches
    pitches_df = clean_pitches(raw_df.copy())
    
    # 4. Derive at-bats
    at_bats_df = derive_at_bats(pitches_df.copy())
    
    # 5. Load to Postgres
    print("\nLoading pitches...")
    load_to_postgres(pitches_df, "pitches", engine)
    verify_load("pitches", engine)
    
    print("\nLoading at_bats...")
    load_to_postgres(at_bats_df, "at_bats", engine)
    verify_load("at_bats", engine)
    
    print("\nPipeline complete.")