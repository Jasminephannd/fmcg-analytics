-- gold.dim_store  <- distinct store ids seen in silver.transactions
INSERT INTO gold.dim_store (store_id)
SELECT DISTINCT store_id FROM silver.transactions;
