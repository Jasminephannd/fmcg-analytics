"""4. Silver -> Gold: build schema from the silver tables."""

from pathlib import Path
from src import config

SCHEMA_SQL = Path(__file__).resolve().parents[1] / "sql" / "schema.sql"


LOADS = {
    # dimensions
    "dim_date": """
        INSERT INTO gold.dim_date (date_key, year, month, month_name, quarter, week_no)
        SELECT DISTINCT ON (date_key)
            date_key,
            EXTRACT(YEAR    FROM date_key)::int,
            EXTRACT(MONTH   FROM date_key)::int,
            TO_CHAR(date_key, 'Mon'),
            EXTRACT(QUARTER FROM date_key)::int,
            week_no
        FROM (
            SELECT transaction_date AS date_key, week_no          FROM silver.transactions
            UNION ALL
            SELECT redemption_date  AS date_key, NULL::bigint     FROM silver.coupon_redempt
        ) d
        ORDER BY date_key, week_no NULLS LAST
    """,
    "dim_product": """
        INSERT INTO gold.dim_product
            (product_id, manufacturer, department, brand,
             commodity_desc, sub_commodity_desc, curr_size_of_product)
        SELECT product_id, manufacturer, department, brand,
               commodity_desc, sub_commodity_desc, curr_size_of_product
        FROM silver.products
    """,
    "dim_household": """
        INSERT INTO gold.dim_household
            (household_key, age_desc, marital_status_code, income_desc,
             homeowner_desc, hh_comp_desc, household_size_desc, kid_category_desc)
        SELECT hh.household_key,
               COALESCE(d.age_desc,            'Unknown'),
               COALESCE(d.marital_status_code, 'Unknown'),
               COALESCE(d.income_desc,         'Unknown'),
               COALESCE(d.homeowner_desc,      'Unknown'),
               COALESCE(d.hh_comp_desc,        'Unknown'),
               COALESCE(d.household_size_desc, 'Unknown'),
               COALESCE(d.kid_category_desc,   'Unknown')
        FROM (
            SELECT household_key FROM silver.transactions
            UNION SELECT household_key FROM silver.campaign_table
            UNION SELECT household_key FROM silver.coupon_redempt
        ) hh
        LEFT JOIN silver.households d ON d.household_key = hh.household_key
    """,
    "dim_store": """
        INSERT INTO gold.dim_store (store_id)
        SELECT DISTINCT store_id FROM silver.transactions
    """,
    "dim_campaign": """
        INSERT INTO gold.dim_campaign (campaign, campaign_type, start_date, end_date)
        SELECT campaign, description, start_date, end_date
        FROM silver.campaign_desc
    """,
    "dim_coupon": """
        INSERT INTO gold.dim_coupon (coupon_upc)
        SELECT coupon_upc FROM silver.coupon
        UNION
        SELECT coupon_upc FROM silver.coupon_redempt
    """,
    # facts and bridges
    "fact_sales": """
        INSERT INTO gold.fact_sales
            (household_key, product_id, store_id, date_key, basket_id, week_no,
             quantity, sales_value, retail_disc, coupon_disc, coupon_match_disc)
        SELECT household_key, product_id, store_id, transaction_date, basket_id, week_no,
               quantity, sales_value, retail_disc, coupon_disc, coupon_match_disc
        FROM silver.transactions
    """,
    "fact_coupon_redemption": """
        INSERT INTO gold.fact_coupon_redemption (household_key, coupon_upc, campaign, date_key)
        SELECT household_key, coupon_upc, campaign, redemption_date
        FROM silver.coupon_redempt
    """,
    "bridge_campaign_household": """
        INSERT INTO gold.bridge_campaign_household (campaign, household_key)
        SELECT DISTINCT campaign, household_key
        FROM silver.campaign_table
    """,
    "bridge_coupon_product": """
        INSERT INTO gold.bridge_coupon_product (coupon_upc, product_id, campaign)
        SELECT DISTINCT c.coupon_upc, c.product_id, c.campaign
        FROM silver.coupon c
        JOIN gold.dim_product p ON p.product_id = c.product_id   -- keep only catalogued products
    """,
}


def main():
    engine = config.get_engine()
    with engine.begin() as conn:
        conn.exec_driver_sql(SCHEMA_SQL.read_text())          # create schema + tables (DDL)
        for table, sql in LOADS.items():
            conn.exec_driver_sql(sql)
            n = conn.exec_driver_sql(f"SELECT COUNT(*) FROM gold.{table}").scalar()
            print(f"gold.{table:26s} {n:>10,} rows")


if __name__ == "__main__":
    main()
