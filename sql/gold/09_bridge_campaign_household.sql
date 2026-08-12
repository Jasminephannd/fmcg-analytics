-- gold.bridge_campaign_household  <- silver.campaign_table (which households were in each campaign)
INSERT INTO gold.bridge_campaign_household (campaign, household_key)
SELECT DISTINCT campaign, household_key
FROM silver.campaign_table;
