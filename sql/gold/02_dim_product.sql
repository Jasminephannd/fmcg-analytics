-- gold.dim_product  <- silver.products
INSERT INTO gold.dim_product
    (product_id, manufacturer, department, brand,
     commodity_desc, sub_commodity_desc, curr_size_of_product)
SELECT product_id, manufacturer, department, brand,
       commodity_desc, sub_commodity_desc, curr_size_of_product
FROM silver.products;
