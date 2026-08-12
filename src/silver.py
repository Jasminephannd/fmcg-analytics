"""3. Bronze -> silver"""
from datetime import datetime, timezone

import pandas as pd
from sqlalchemy import text

from src import config
from src.logging_config import get_logger

logger = get_logger("silver")

# DAY is a relative index (1, 2,...), not a real date. Assume day 1 is 2012-01-01
DAY_ONE = pd.Timestamp("2012-01-01")

# When this silver run processed the data (date only, for easy grouping later).
SILVER_PROCESSED_AT = datetime.now(timezone.utc).date().isoformat()


def write_silver(engine, df, table):
    """Write a cleaned dataframe to the silver schema (replace = replayable)."""
    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS silver;"))
    df.to_sql(table, engine, schema="silver", if_exists="replace",
              index=False, method="multi", chunksize=1_000)


def add_lineage(df):
    """Keep _source_file from bronze; replace bronze's _loaded_at with _processed_at."""
    df = df.drop(columns=["_loaded_at"])
    df["_processed_at"] = SILVER_PROCESSED_AT
    return df


def clean_transactions(engine):
    """bronze.transaction_data -> silver.transactions (drops zero-qty/zero-sales lines)"""
    df = pd.read_sql("SELECT * FROM bronze.transaction_data", engine)
    df.columns = df.columns.str.lower()
    df = add_lineage(df)
    for col in ["household_key", "basket_id", "day", "product_id",
                "quantity", "store_id", "trans_time", "week_no"]:
        df[col] = df[col].astype("int64")                     # integer columns
    for col in ["sales_value", "retail_disc", "coupon_disc", "coupon_match_disc"]:
        df[col] = df[col].astype(float).round(2)              # money to 2 dp (convert float like 2.2e-16 to 0.00)
    df.loc[df["retail_disc"] > 0, "retail_disc"] *= -1        # flip the few positive discounts (sign errors) to negative
    df["transaction_date"] = (DAY_ONE + pd.to_timedelta(df["day"] - 1, unit="D")).dt.date  # business date
    df = df.drop(columns=["day"])                             # day index replaced by transaction_date
    before = len(df)
    df = df[~((df["quantity"] == 0) & (df["sales_value"] == 0))]  # drop lines where quantity=0 and sales_value=$0)
    logger.info(f"dropped {before - len(df):,} zero-qty / zero-sales lines")
    return df


def clean_products(engine):
    """bronze.product -> silver.products (all rows kept; blank text -> UNKNOWN)"""
    df = pd.read_sql("SELECT * FROM bronze.product", engine)
    df.columns = df.columns.str.lower()
    df = add_lineage(df)
    df["product_id"] = df["product_id"].astype("int64")
    df["manufacturer"] = df["manufacturer"].astype("int64")
    for col in ["department", "brand", "commodity_desc", "sub_commodity_desc",
                "curr_size_of_product"]:
        df[col] = df[col].str.strip().replace("", "UNKNOWN")  # blanks -> UNKNOWN
    return df


def clean_households(engine):
    """bronze.hh_demographic -> silver.households"""
    df = pd.read_sql("SELECT * FROM bronze.hh_demographic", engine)
    df.columns = df.columns.str.lower()
    df = add_lineage(df)
    df["household_key"] = df["household_key"].astype("int64")
    for col in ["age_desc", "marital_status_code", "income_desc", "homeowner_desc",
                "hh_comp_desc", "household_size_desc", "kid_category_desc"]:
        df[col] = df[col].str.strip()                         # categories stay text
    return df


def clean_campaign_desc(engine):
    """bronze.campaign_desc -> silver.campaign_desc"""
    df = pd.read_sql("SELECT * FROM bronze.campaign_desc", engine)
    df.columns = df.columns.str.lower()
    df = add_lineage(df)
    df["description"] = df["description"].str.strip()
    df["campaign"] = df["campaign"].astype("int64")
    df["start_date"] = (DAY_ONE + pd.to_timedelta(df["start_day"].astype("int64") - 1, unit="D")).dt.date
    df["end_date"] = (DAY_ONE + pd.to_timedelta(df["end_day"].astype("int64") - 1, unit="D")).dt.date
    df = df.drop(columns=["start_day", "end_day"])           # replaced by start_date / end_date
    return df


def clean_campaign_table(engine):
    """bronze.campaign_table -> silver.campaign_table"""
    df = pd.read_sql("SELECT * FROM bronze.campaign_table", engine)
    df.columns = df.columns.str.lower()
    df = add_lineage(df)
    df["description"] = df["description"].str.strip()
    df["household_key"] = df["household_key"].astype("int64")
    df["campaign"] = df["campaign"].astype("int64")
    return df


def clean_coupon(engine):
    """bronze.coupon -> silver.coupon (raw coupon.csv has exact duplicate rows)"""
    df = pd.read_sql("SELECT * FROM bronze.coupon", engine)
    df.columns = df.columns.str.lower()
    df = add_lineage(df)
    for col in ["coupon_upc", "product_id", "campaign"]:
        df[col] = df[col].astype("int64")                     # coupon_upc is big -> int64
    before = len(df)
    df = df.drop_duplicates()                                 # drop exact duplicate rows
    logger.info(f"dropped {before - len(df):,} duplicate coupon rows")
    return df


def clean_coupon_redempt(engine):
    """bronze.coupon_redempt -> silver.coupon_redempt"""
    df = pd.read_sql("SELECT * FROM bronze.coupon_redempt", engine)
    df.columns = df.columns.str.lower()
    df = add_lineage(df)
    for col in ["household_key", "coupon_upc", "campaign"]:
        df[col] = df[col].astype("int64")
    df["redemption_date"] = (DAY_ONE + pd.to_timedelta(df["day"].astype("int64") - 1, unit="D")).dt.date
    df = df.drop(columns=["day"])                            # replaced by redemption_date
    return df


def main():
    try:
        engine = config.get_engine()
        tables = {
            "transactions": clean_transactions,
            "products": clean_products,
            "households": clean_households,
            "campaign_desc": clean_campaign_desc,
            "campaign_table": clean_campaign_table,
            "coupon": clean_coupon,
            "coupon_redempt": clean_coupon_redempt,
        }
        for name, clean_fn in tables.items():
            df = clean_fn(engine)
            write_silver(engine, df, name)
            logger.info(f"silver.{name}: {len(df):,} rows")
        logger.info("silver load complete")
    except Exception:
        logger.error("silver load failed", exc_info=True)
        raise


if __name__ == "__main__":
    main()
