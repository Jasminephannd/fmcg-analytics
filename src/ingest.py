"""1. Download the dunnhumby dataset from Kaggle into data/bronze/."""

from src import config
from kaggle.api.kaggle_api_extended import KaggleApi

DATASET = "frtgnn/dunnhumby-the-complete-journey"

def download_dataset():
    api = KaggleApi()
    api.authenticate()  # reads KAGGLE_API_TOKEN from .env

    config.BRONZE_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {DATASET} -> {config.BRONZE_DIR}")
    api.dataset_download_files(DATASET, path=str(config.BRONZE_DIR), unzip=True)

    csvs = sorted(config.BRONZE_DIR.glob("*.csv"))
    print(f"Done. {len(csvs)} CSV files landed:")
    for f in csvs:
        print(f"  {f.name:30s} {f.stat().st_size / 1_048_576:6.1f} MB")


if __name__ == "__main__":
    download_dataset()
