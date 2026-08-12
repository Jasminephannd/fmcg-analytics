-- gold.fact_coupon_redemption  <- silver.coupon_redempt (one row per redemption event)
INSERT INTO gold.fact_coupon_redemption (household_key, coupon_upc, campaign, date_key)
SELECT household_key, coupon_upc, campaign, redemption_date
FROM silver.coupon_redempt;
