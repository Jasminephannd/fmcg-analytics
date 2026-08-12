-- gold.bridge_coupon_product  <- silver.coupon, kept to products that exist in dim_product
INSERT INTO gold.bridge_coupon_product (coupon_upc, product_id, campaign)
SELECT DISTINCT c.coupon_upc, c.product_id, c.campaign
FROM silver.coupon c
JOIN gold.dim_product p ON p.product_id = c.product_id;   -- keep only catalogued products
