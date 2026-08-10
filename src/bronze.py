"""2. Load the raw csv files into Postgres, and add two columns _source_file and _loaded_at"""

from datetime import datetime, timezone
import pandas as pd
from sqlalchemy import text

from src import config

SKIP_FILES = {"causal_data.csv"}
CHUNK_ROWS = 50_000  # read this many CSV rows at a time to keep memory low


def load_csv_to_bronze(engine, csv_path):
    """Load one CSV into bronze.<table>, all columns as text, plus lineage."""
    table = csv_path.stem.lower()               # transaction_data.csv -> transaction_data
    loaded_at = datetime.now(timezone.utc).date().isoformat()  # date
    total = 0
    for i, chunk in enumerate(
        pd.read_csv(csv_path, dtype=str, keep_default_na=False, chunksize=CHUNK_ROWS)
    ):
        chunk["_source_file"] = csv_path.name   # which file each row came from
        chunk["_loaded_at"] = loaded_at         # when we loaded it
        chunk.to_sql(
            table, engine, schema="bronze",
            if_exists="replace" if i == 0 else "append",  # first chunk resets the table
            index=False, method="multi", chunksize=1_000,
        )
        total += len(chunk)
    return table, total


def main():
    engine = config.get_engine()
    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS bronze;"))

    csvs = [p for p in sorted(config.BRONZE_DIR.glob("*.csv")) if p.name not in SKIP_FILES]
    assert csvs, f"No CSV files in {config.BRONZE_DIR} - run `python -m src.ingest` first."

    print(f"Loading {len(csvs)} CSV files into schema 'bronze'...")
    for csv_path in csvs:
        table, n = load_csv_to_bronze(engine, csv_path)
        assert n > 0, f"{table} loaded 0 rows!"
        print(f"  bronze.{table:<20s} {n:>10,} rows")
    print("Bronze load complete.")


if __name__ == "__main__":
    main()
