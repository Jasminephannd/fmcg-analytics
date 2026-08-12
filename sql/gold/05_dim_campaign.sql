-- gold.dim_campaign  <- silver.campaign_desc (description is the campaign type)
INSERT INTO gold.dim_campaign (campaign, campaign_type, start_date, end_date)
SELECT campaign, description, start_date, end_date
FROM silver.campaign_desc;
