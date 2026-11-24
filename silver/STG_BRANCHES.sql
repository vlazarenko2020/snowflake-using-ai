-- Silver: one row per branch, typed and trimmed, with an is_known_country flag.
-- Source: AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES, BRONZE_COUNTRIES
CREATE SCHEMA IF NOT EXISTS AVELTO_RENTALS.SILVER;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_BRANCHES
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    TRY_TO_NUMBER(TRIM(b.id))          AS branch_id,
    TRIM(b.name)                       AS branch_name,
    TRIM(b.city)                       AS city,
    TRY_TO_NUMBER(TRIM(b.capacity))    AS capacity,
    TRY_TO_NUMBER(TRIM(b.country_id))  AS country_id,
    c.country_id IS NOT NULL           AS is_known_country
FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES b
LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_COUNTRIES c
  ON TRY_TO_NUMBER(TRIM(c.country_id)) = TRY_TO_NUMBER(TRIM(b.country_id));
