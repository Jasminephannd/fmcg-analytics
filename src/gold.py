"""4. Silver -> Gold: build the schema, then run each load file in sql/gold/.The DDL lives in sql/schema.sql"""

import re
from pathlib import Path

from src import config
from src.logging_config import get_logger

logger = get_logger("gold")

SQL_DIR = Path(__file__).resolve().parents[1] / "sql"
SCHEMA_SQL = SQL_DIR / "schema.sql"
GOLD_DIR = SQL_DIR / "gold"


def table_name(sql_path):
    """01_dim_date.sql -> dim_date  (drop the number prefix and extension)."""
    return re.sub(r"^\d+_", "", sql_path.stem)


def main():
    try:
        engine = config.get_engine()
        with engine.begin() as conn:
            conn.exec_driver_sql(SCHEMA_SQL.read_text())      # create schema + tables (DDL)
            for sql_path in sorted(GOLD_DIR.glob("*.sql")):   # order comes from the file names
                conn.exec_driver_sql(sql_path.read_text())
                table = table_name(sql_path)
                n = conn.exec_driver_sql(f"SELECT COUNT(*) FROM gold.{table}").scalar()
                logger.info(f"gold.{table}: {n:,} rows")
        logger.info("gold load complete")
    except Exception:
        logger.error("gold load failed", exc_info=True)
        raise


if __name__ == "__main__":
    main()
