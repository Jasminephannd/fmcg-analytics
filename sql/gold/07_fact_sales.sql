-- gold.fact_sales  <- silver.transactions 
INSERT INTO gold.fact_sales
    (household_key, product_id, store_id, date_key, basket_id, week_no,
     quantity, sales_value, retail_disc, coupon_disc, coupon_match_disc)
SELECT household_key, product_id, store_id, transaction_date, basket_id, week_no,
       quantity, sales_value, retail_disc, coupon_disc, coupon_match_disc
FROM silver.transactions;
