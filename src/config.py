"""file paths + the database connection, read from .env"""
import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine

# Project root is the folder above src/ ; load .env
PROJECT_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(PROJECT_ROOT / ".env")
DATA_DIR = PROJECT_ROOT / "data"
BRONZE_DIR = DATA_DIR / "bronze"


def get_engine() -> Engine:
    """Build a SQLAlchemy engine pointed at our Postgres, using the .env values."""
    user = os.environ["POSTGRES_USER"]
    password = os.environ["POSTGRES_PASSWORD"]
    host = os.environ["POSTGRES_HOST"]
    port = os.environ["POSTGRES_PORT"]
    db = os.environ["POSTGRES_DB"]
    url = f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{db}"
    return create_engine(url)


if __name__ == "__main__":
    # Quick connectivity test:  python -m src.config
    from sqlalchemy import text

    with get_engine().connect() as conn:
        version = conn.execute(text("SELECT version();")).scalar_one()
    print("Connected OK ->", version)
