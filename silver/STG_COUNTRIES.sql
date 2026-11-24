-- Silver: one row per country, typed and trimmed, with a has_valid_currency flag.
-- Source: AVELTO_RENTALS.BRONZE.BRONZE_COUNTRIES, BRONZE_CURRENCIES
CREATE SCHEMA IF NOT EXISTS AVELTO_RENTALS.SILVER;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_COUNTRIES
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    TRY_TO_NUMBER(TRIM(c.country_id))  AS country_id,
    UPPER(TRIM(c.country_code))        AS country_code,
    TRIM(c.country_name)               AS country_name,
    TRIM(c.region)                     AS region,
    UPPER(TRIM(c.currency_code))       AS currency_code,
    cur.currency_code IS NOT NULL      AS has_valid_currency
FROM AVELTO_RENTALS.BRONZE.BRONZE_COUNTRIES c
LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_CURRENCIES cur
  ON UPPER(TRIM(cur.currency_code)) = UPPER(TRIM(c.currency_code));
