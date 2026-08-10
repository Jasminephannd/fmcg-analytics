CREATE SCHEMA IF NOT EXISTS gold;

DROP TABLE IF EXISTS gold.bridge_coupon_product     CASCADE;
DROP TABLE IF EXISTS gold.bridge_campaign_household CASCADE;
DROP TABLE IF EXISTS gold.fact_coupon_redemption    CASCADE;
DROP TABLE IF EXISTS gold.fact_sales                CASCADE;
DROP TABLE IF EXISTS gold.dim_coupon                CASCADE;
DROP TABLE IF EXISTS gold.dim_campaign              CASCADE;
DROP TABLE IF EXISTS gold.dim_store                 CASCADE;
DROP TABLE IF EXISTS gold.dim_household             CASCADE;
DROP TABLE IF EXISTS gold.dim_product               CASCADE;
DROP TABLE IF EXISTS gold.dim_date                  CASCADE;

-- Dimensions

CREATE TABLE gold.dim_date (
    date_key    DATE PRIMARY KEY,
    year        INT  NOT NULL,
    month       INT  NOT NULL,
    month_name  TEXT NOT NULL,
    quarter     INT  NOT NULL,
    week_no     INT
);

CREATE TABLE gold.dim_product (
    product_id           BIGINT PRIMARY KEY,
    manufacturer         BIGINT,
    department           TEXT,
    brand                TEXT,
    commodity_desc       TEXT,
    sub_commodity_desc   TEXT,
    curr_size_of_product TEXT
);

CREATE TABLE gold.dim_household (
    household_key       BIGINT PRIMARY KEY,
    age_desc            TEXT,
    marital_status_code TEXT,
    income_desc         TEXT,
    homeowner_desc      TEXT,
    hh_comp_desc        TEXT,
    household_size_desc TEXT,
    kid_category_desc   TEXT
);

CREATE TABLE gold.dim_store (
    store_id BIGINT PRIMARY KEY
);

CREATE TABLE gold.dim_campaign (
    campaign      INT PRIMARY KEY,
    campaign_type TEXT,
    start_date    DATE,
    end_date      DATE
);

CREATE TABLE gold.dim_coupon (
    coupon_upc BIGINT PRIMARY KEY
);

-- Facts and bridges

-- sales
CREATE TABLE gold.fact_sales (
    sale_id           BIGSERIAL PRIMARY KEY,
    household_key     BIGINT NOT NULL REFERENCES gold.dim_household(household_key),
    product_id        BIGINT NOT NULL REFERENCES gold.dim_product(product_id),
    store_id          BIGINT NOT NULL REFERENCES gold.dim_store(store_id),
    date_key          DATE   NOT NULL REFERENCES gold.dim_date(date_key),
    basket_id         BIGINT,
    week_no           INT,
    quantity          BIGINT,
    sales_value       NUMERIC(12,2),
    retail_disc       NUMERIC(12,2),
    coupon_disc       NUMERIC(12,2),
    coupon_match_disc NUMERIC(12,2)
);

-- one row per coupon redemption 
CREATE TABLE gold.fact_coupon_redemption (
    redemption_id BIGSERIAL PRIMARY KEY,
    household_key BIGINT NOT NULL REFERENCES gold.dim_household(household_key),
    coupon_upc    BIGINT NOT NULL REFERENCES gold.dim_coupon(coupon_upc),
    campaign      INT    NOT NULL REFERENCES gold.dim_campaign(campaign),
    date_key      DATE   NOT NULL REFERENCES gold.dim_date(date_key)
);

-- which households were enrolled in which campaign
CREATE TABLE gold.bridge_campaign_household (
    campaign_household_id BIGSERIAL PRIMARY KEY,
    campaign      INT    NOT NULL REFERENCES gold.dim_campaign(campaign),
    household_key BIGINT NOT NULL REFERENCES gold.dim_household(household_key)
);

-- which products each coupon targets within a campaign
CREATE TABLE gold.bridge_coupon_product (
    coupon_product_id BIGSERIAL PRIMARY KEY,
    coupon_upc BIGINT NOT NULL REFERENCES gold.dim_coupon(coupon_upc),
    product_id BIGINT NOT NULL REFERENCES gold.dim_product(product_id),
    campaign   INT    NOT NULL REFERENCES gold.dim_campaign(campaign)
);
