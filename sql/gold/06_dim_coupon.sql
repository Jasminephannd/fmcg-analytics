-- gold.dim_coupon  <- distinct coupon_upc from both coupon tables
INSERT INTO gold.dim_coupon (coupon_upc)
SELECT coupon_upc FROM silver.coupon
UNION
SELECT coupon_upc FROM silver.coupon_redempt;
