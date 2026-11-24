-- Silver: one row per car, typed and trimmed, with reference-check flags.
-- Source: AVELTO_RENTALS.BRONZE.BRONZE_CARS, BRONZE_CAR_CATEGORIES, BRONZE_BRANCHES
CREATE SCHEMA IF NOT EXISTS AVELTO_RENTALS.SILVER;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_CARS
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    TRY_TO_NUMBER(TRIM(c.id))                 AS car_id,
    UPPER(TRIM(c.license_plate))              AS license_plate,
    TRIM(c.model)                             AS model,
    TRY_TO_NUMBER(TRIM(c.year))               AS model_year,
    TRY_TO_NUMBER(TRIM(c.category_id))        AS category_id,
    TRY_TO_NUMBER(TRIM(c.current_branch_id))  AS current_branch_id,
    k.id IS NOT NULL                          AS is_known_category,
    b.id IS NOT NULL                          AS is_known_branch
FROM AVELTO_RENTALS.BRONZE.BRONZE_CARS c
LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_CAR_CATEGORIES k
  ON TRY_TO_NUMBER(TRIM(k.id)) = TRY_TO_NUMBER(TRIM(c.category_id))
LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES b
  ON TRY_TO_NUMBER(TRIM(b.id)) = TRY_TO_NUMBER(TRIM(c.current_branch_id));
