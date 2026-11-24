-- Silver: one row per branch x car category, typed, with reference-check flags.
-- Source: AVELTO_RENTALS.BRONZE.BRONZE_BRANCH_CATEGORY_AVAILABILITY, BRONZE_BRANCHES, BRONZE_CAR_CATEGORIES
CREATE SCHEMA IF NOT EXISTS AVELTO_RENTALS.SILVER;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_BRANCH_CATEGORY_AVAILABILITY
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    TRY_TO_NUMBER(TRIM(a.branch_id))    AS branch_id,
    TRIM(a.branch_name)                 AS branch_name,
    TRY_TO_NUMBER(TRIM(a.category_id))  AS category_id,
    TRIM(a.category_name)               AS category_name,
    TRY_TO_BOOLEAN(TRIM(a.is_offered))  AS is_offered,
    b.id   IS NOT NULL                  AS is_known_branch,
    cat.id IS NOT NULL                  AS is_known_category,
    TRIM(a.branch_name) = TRIM(b.name)  AS branch_name_matches
FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCH_CATEGORY_AVAILABILITY a
LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES b
  ON TRY_TO_NUMBER(TRIM(b.id)) = TRY_TO_NUMBER(TRIM(a.branch_id))
LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_CAR_CATEGORIES cat
  ON TRY_TO_NUMBER(TRIM(cat.id)) = TRY_TO_NUMBER(TRIM(a.category_id));
