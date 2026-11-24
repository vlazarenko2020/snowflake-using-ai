-- Silver: one row per currency, typed and trimmed.
-- Source: AVELTO_RENTALS.BRONZE.BRONZE_CURRENCIES
CREATE SCHEMA IF NOT EXISTS AVELTO_RENTALS.SILVER;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_CURRENCIES
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    UPPER(TRIM(currency_code))                      AS currency_code,
    TRIM(currency_name)                             AS currency_name,
    TRIM(symbol)                                    AS symbol,
    TRY_TO_DECIMAL(TRIM(usd_exchange_rate), 18, 6)  AS usd_exchange_rate,
    TRY_TO_NUMBER(TRIM(decimals))                   AS decimals
FROM AVELTO_RENTALS.BRONZE.BRONZE_CURRENCIES;
