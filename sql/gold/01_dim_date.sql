-- gold.dim_date  <- silver.transactions + silver.coupon_redempt (one row per date)
INSERT INTO gold.dim_date (date_key, year, month, month_name, quarter, week_no)
SELECT DISTINCT ON (date_key)
    date_key,
    EXTRACT(YEAR    FROM date_key)::int,
    EXTRACT(MONTH   FROM date_key)::int,
    TO_CHAR(date_key, 'Mon'),
    EXTRACT(QUARTER FROM date_key)::int,
    week_no
FROM (
    SELECT transaction_date AS date_key, week_no       FROM silver.transactions
    UNION ALL
    SELECT redemption_date  AS date_key, NULL::bigint  FROM silver.coupon_redempt
) d
ORDER BY date_key, week_no NULLS LAST;
