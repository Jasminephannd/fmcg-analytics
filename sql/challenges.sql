-- 1. MODELLING 
--    The DDL is in sql/schema.sql. Below is the map of tables and key columns.
--
--    DIMENSIONS        description                PK
--      dim_date        calendar dates             date_key
--      dim_product     product catalogue          product_id
--      dim_household   customer / demographics    household_key
--      dim_store       store identifier           store_id
--      dim_campaign    marketing campaigns        campaign
--      dim_coupon      coupon identifier          coupon_upc
--
--    FACTS                     description            PK              FK columns
--      fact_sales              one transaction line   sale_id         product_id, household_key, store_id, date_key
--      fact_coupon_redemption  one redemption         redemption_id   household_key, coupon_upc, campaign, date_key
--                                                                   
--    BRIDGES                      (resolve many-to-many)   PK                      FK columns
--      bridge_campaign_household  household<->campaign     campaign_household_id   campaign, household_key
--      bridge_coupon_product      coupon<->product         coupon_product_id       coupon_upc, product_id, campaign



-- 2. AGGREGATION & GROUPING - revenue by category and time period, high -> low
SELECT p.department,
       d.year,
       d.month_name,
       ROUND(SUM(f.sales_value), 2) AS revenue
FROM   gold.fact_sales   f
JOIN   gold.dim_product  p ON p.product_id = f.product_id
JOIN   gold.dim_date     d ON d.date_key   = f.date_key
GROUP  BY p.department, d.year, d.month, d.month_name
ORDER  BY revenue DESC;



-- 3a. WINDOW FUNCTION - rank the top 5 commodities within each department, order by each department's total revenue
WITH ranked AS (
    SELECT p.department,
           p.commodity_desc,
           SUM(f.sales_value) AS revenue,
           RANK() OVER (PARTITION BY p.department ORDER BY SUM(f.sales_value) DESC) AS rank,
           SUM(SUM(f.sales_value)) OVER (PARTITION BY p.department)             AS dept_revenue
    FROM   gold.fact_sales  f
    JOIN   gold.dim_product p ON p.product_id = f.product_id
    GROUP  BY p.department, p.commodity_desc
)
SELECT department, commodity_desc, ROUND(revenue, 2) AS revenue, rank
FROM   ranked
WHERE  rank <= 5
ORDER  BY dept_revenue DESC, rank;



-- 3b. WINDOW FUNCTION - month-over-month revenue change (LAG)
WITH monthly AS (
    SELECT d.year, d.month, MIN(d.month_name) AS month_name,
           SUM(f.sales_value) AS revenue
    FROM   gold.fact_sales f
    JOIN   gold.dim_date   d ON d.date_key = f.date_key
    GROUP  BY d.year, d.month
)
SELECT year, month, month_name,
       ROUND(revenue, 2) AS revenue,
       ROUND(revenue - LAG(revenue) OVER (ORDER BY year, month), 2) AS mom_change,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY year, month))
             / NULLIF(LAG(revenue) OVER (ORDER BY year, month), 0), 1) AS mom_pct
FROM   monthly
ORDER  BY year, month;



-- 4. JOINS - the sales fact joined to all four of its dimensions
SELECT d.date_key,
       p.department,
       p.commodity_desc,
       s.store_id,
       h.income_desc,
       f.quantity,
       f.sales_value
FROM   gold.fact_sales    f
JOIN   gold.dim_product   p ON p.product_id    = f.product_id
JOIN   gold.dim_store     s ON s.store_id      = f.store_id
JOIN   gold.dim_date      d ON d.date_key      = f.date_key
JOIN   gold.dim_household h ON h.household_key = f.household_key
ORDER  BY f.sales_value DESC
LIMIT  100;



-- 4. JOINS - the marketing side 
SELECT r.household_key,
       d.date_key            AS redeemed_on,
       c.campaign_type,
       c.start_date          AS campaign_start,   -- the campaign's run window,
       c.end_date            AS campaign_end,      
       cp.coupon_upc,
       h.age_desc,
       h.income_desc,
       h.household_size_desc
FROM   gold.fact_coupon_redemption r
JOIN   gold.dim_date      d  ON d.date_key      = r.date_key
JOIN   gold.dim_campaign  c  ON c.campaign      = r.campaign
JOIN   gold.dim_coupon    cp ON cp.coupon_upc   = r.coupon_upc
JOIN   gold.dim_household h  ON h.household_key  = r.household_key
ORDER  BY d.date_key
LIMIT  100;



-- 5. PERFORMANCE - Query = revenue for a single day
EXPLAIN (ANALYZE, BUFFERS)
SELECT SUM(sales_value)
FROM   gold.fact_sales
WHERE  date_key = DATE '2012-10-15';

CREATE INDEX IF NOT EXISTS idx_fact_sales_date ON gold.fact_sales (date_key);
ANALYZE gold.fact_sales;   -- refresh stats so the planner sees the new index

EXPLAIN (ANALYZE, BUFFERS)
SELECT SUM(sales_value)
FROM   gold.fact_sales
WHERE  date_key = DATE '2012-10-15';


-- 6. DATA QUALITY - detect the issues in bronze, confirm they are resolved in silver, then create a single view of data quality check in gold.

-- 6a. BRONZE

-- column names in bronze have inconsistent naming formats
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'bronze'
ORDER BY table_name, ordinal_position;

-- coupon: duplicate rows in the raw file 
SELECT COUNT(*)                                                          AS total_rows,
       COUNT(DISTINCT ("COUPON_UPC","PRODUCT_ID","CAMPAIGN"))            AS distinct_rows,
       COUNT(*) - COUNT(DISTINCT ("COUPON_UPC","PRODUCT_ID","CAMPAIGN")) AS duplicate_rows
FROM   bronze.coupon;

-- transactions: positive retail_disc (a discount should be <= 0; max is +3.99)
SELECT COUNT(*) AS positive_rows, MAX("RETAIL_DISC"::numeric) AS max_retail_disc
FROM   bronze.transaction_data
WHERE  "RETAIL_DISC"::numeric > 0;

-- product: blank category and blank size fields (expect 15 / 15 / 15 / 30,607)
SELECT COUNT(*) FILTER (WHERE TRIM("DEPARTMENT")           = '') AS blank_department,
       COUNT(*) FILTER (WHERE TRIM("COMMODITY_DESC")       = '') AS blank_commodity,
       COUNT(*) FILTER (WHERE TRIM("SUB_COMMODITY_DESC")   = '') AS blank_sub_commodity,
       COUNT(*) FILTER (WHERE TRIM("CURR_SIZE_OF_PRODUCT") = '') AS blank_size
FROM   bronze.product;

-- 6b. SILVER

-- consistent column names
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'silver'
ORDER BY table_name, ordinal_position;

-- coupon duplicates removed -> 0
SELECT COUNT(*) - COUNT(DISTINCT (coupon_upc, product_id, campaign)) AS duplicate_rows
FROM   silver.coupon;

-- blanks filled with UNKNOWN (15 categories, 30,607 sizes)
SELECT COUNT(*) FILTER (WHERE department          = 'UNKNOWN') AS unknown_department,
       COUNT(*) FILTER (WHERE curr_size_of_product = 'UNKNOWN') AS unknown_size
FROM   silver.products;

-- no positive retail_disc
SELECT COUNT(*) AS positive_rows
FROM   silver.transactions
WHERE  "retail_disc"::numeric > 0;

-- 6c. GOLD
--     Orphan checks should all be 0 (FK integrity holds by construction);
--     the other rows report known, documented issues.
SELECT 'orphan_product_fk'   AS check_name, COUNT(*) AS issues
FROM gold.fact_sales f LEFT JOIN gold.dim_product   p ON p.product_id=f.product_id     WHERE p.product_id     IS NULL
UNION ALL
SELECT 'orphan_household_fk', COUNT(*)
FROM gold.fact_sales f LEFT JOIN gold.dim_household h ON h.household_key=f.household_key WHERE h.household_key IS NULL
UNION ALL
SELECT 'orphan_store_fk',     COUNT(*)
FROM gold.fact_sales f LEFT JOIN gold.dim_store     s ON s.store_id=f.store_id           WHERE s.store_id      IS NULL
UNION ALL
SELECT 'orphan_date_fk',      COUNT(*)
FROM gold.fact_sales f LEFT JOIN gold.dim_date      d ON d.date_key=f.date_key           WHERE d.date_key      IS NULL
UNION ALL
SELECT 'orphan_redemption_coupon_fk',   COUNT(*)
FROM gold.fact_coupon_redemption r LEFT JOIN gold.dim_coupon   dc ON dc.coupon_upc=r.coupon_upc WHERE dc.coupon_upc IS NULL
UNION ALL
SELECT 'orphan_redemption_campaign_fk', COUNT(*)
FROM gold.fact_coupon_redemption r LEFT JOIN gold.dim_campaign dk ON dk.campaign=r.campaign     WHERE dk.campaign   IS NULL
UNION ALL
SELECT 'orphan_couponproduct_product_fk', COUNT(*)
FROM gold.bridge_coupon_product bp LEFT JOIN gold.dim_product dp ON dp.product_id=bp.product_id WHERE dp.product_id IS NULL
UNION ALL
SELECT 'negative_sales',        COUNT(*) FROM gold.fact_sales WHERE sales_value < 0
UNION ALL
SELECT 'negative_quantity',     COUNT(*) FROM gold.fact_sales WHERE quantity < 0
UNION ALL
SELECT 'positive_retail_disc',  COUNT(*) FROM gold.fact_sales WHERE retail_disc > 0
UNION ALL
SELECT 'unknown_dept_products', COUNT(*) FROM gold.dim_product WHERE department = 'UNKNOWN'
ORDER BY issues DESC;
