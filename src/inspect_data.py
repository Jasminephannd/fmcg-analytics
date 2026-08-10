"""Check dtypes, missing values, ranges, distinct counts, and values of text columns."""

import pandas as pd
from src import config

pd.set_option("display.max_columns", None)
MAX_VALUES_TO_LIST = 50

# Columns that must be unique per table. Tables not listed have no single key,so we check for full-row duplicates.
KEYS = {
    "product.csv":        ["PRODUCT_ID"],
    "hh_demographic.csv": ["household_key"],
    "campaign_desc.csv":  ["CAMPAIGN"],
    "campaign_table.csv": ["household_key", "CAMPAIGN"],
}

for path in sorted(config.BRONZE_DIR.glob("*.csv")):
    if path.name == "causal_data.csv":
        continue
    df = pd.read_csv(path)

    print(f"\n\n{path.name}  ({len(df):,} rows, {df.shape[1]} cols)")
    df.info()

    print("\nmissing per column:")
    blanks = df.apply(lambda s: s.isna() | (s.astype(str).str.strip() == ""))
    print(blanks.sum())

    print("\ndistinct per column:")
    print(df.nunique())

    print("\nnumeric summary:")
    print(df.describe())

    key = KEYS.get(path.name)
    if key:
        n = int(df.duplicated(subset=key).sum())
        print("\nduplicate " + "+".join(key) + f": {n}   (should be 0)")
    else:
        n = int(df.duplicated().sum())
        print(f"\nfull-row duplicates: {n}   (no unique key)")

    print("\ntext column values:")
    for col in df.select_dtypes(exclude="number").columns:
        n = df[col].nunique()
        if n <= MAX_VALUES_TO_LIST:
            print(f"  {col} ({n}): {sorted(df[col].dropna().unique().tolist())}")
        else:
            print(f"  {col} ({n} distinct, top 5):")
            print(df[col].value_counts().head(5).to_string())
