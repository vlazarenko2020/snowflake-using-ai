-- Silver: one row per customer, typed and trimmed, with an is_valid_email flag.
-- Contains unmasked PII (name, email, phone, driver licence number, date of birth).
-- Source: AVELTO_RENTALS.BRONZE.BRONZE_CUSTOMERS
CREATE SCHEMA IF NOT EXISTS AVELTO_RENTALS.SILVER;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_CUSTOMERS
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    TRY_TO_NUMBER(TRIM(id))                        AS customer_id,
    TRIM(name)                                     AS customer_name,
    LOWER(TRIM(email))                             AS email,
    TRIM(phone)                                    AS phone,
    UPPER(TRIM(driver_license_number))             AS driver_license_number,
    TRY_TO_DATE(TRIM(date_of_birth), 'YYYY-MM-DD') AS date_of_birth,
    REGEXP_LIKE(TRIM(email), '^[^@ ]+@[^@ ]+\\.[^@ ]+$') AS is_valid_email
FROM AVELTO_RENTALS.BRONZE.BRONZE_CUSTOMERS;
