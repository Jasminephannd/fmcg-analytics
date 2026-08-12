-- gold.dim_household  <- every household seen in silver, left-joined to demographics (missing demographics filled with 'Unknown')
INSERT INTO gold.dim_household
    (household_key, age_desc, marital_status_code, income_desc,
     homeowner_desc, hh_comp_desc, household_size_desc, kid_category_desc)
SELECT hh.household_key,
       COALESCE(d.age_desc,            'Unknown'),
       COALESCE(d.marital_status_code, 'Unknown'),
       COALESCE(d.income_desc,         'Unknown'),
       COALESCE(d.homeowner_desc,      'Unknown'),
       COALESCE(d.hh_comp_desc,        'Unknown'),
       COALESCE(d.household_size_desc, 'Unknown'),
       COALESCE(d.kid_category_desc,   'Unknown')
FROM (
    SELECT household_key FROM silver.transactions
    UNION SELECT household_key FROM silver.campaign_table
    UNION SELECT household_key FROM silver.coupon_redempt
) hh
LEFT JOIN silver.households d ON d.household_key = hh.household_key;
