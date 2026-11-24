-- Bronze: BRONZE_CUSTOMERS
-- Source file: source_files/customers.csv (FleetOps), 500 data rows + header
-- Contains unmasked PII (name, email, phone, driver licence number, date of birth).
-- Requires: 00_SETUP.sql
-- Steps 1-3 are exactly as originally run on 2026-11-23 (from query history).
-- Step 4 is the uppercase rename done afterwards, so Silver can use the table without quotes.
USE SCHEMA AVELTO_RENTALS.BRONZE;

-- 1. Upload the file to the stage.
--    PUT runs only from a client (SnowSQL / Snowflake CLI / VS Code extension), not from a Snowsight worksheet.
--    Original path shown; when running from this repo you can use 'file://bronze/source_files/customers.csv'.
PUT file:///home/sulp/CLAUDE_PROJECTS_VL2020_REPO/SNOWFLAKE/snowflake-using-ai/Source_Data/Bronze/FleetOps/customers.csv @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- 2. Create the table with the file's column names, all VARCHAR (no type changes)
CREATE OR REPLACE TABLE "bronze_customers" ("id" VARCHAR, "name" VARCHAR, "email" VARCHAR, "phone" VARCHAR, "driver_license_number" VARCHAR, "date_of_birth" VARCHAR);

-- 3. Load the file
COPY INTO "bronze_customers" FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE FILES=('customers.csv') FILE_FORMAT=(FORMAT_NAME='CSV_RAW_FMT') MATCH_BY_COLUMN_NAME=CASE_SENSITIVE ON_ERROR=ABORT_STATEMENT;

-- 4. Rename table and columns to uppercase (no quotes needed afterwards)
ALTER TABLE "bronze_customers" RENAME TO BRONZE_CUSTOMERS;
ALTER TABLE BRONZE_CUSTOMERS RENAME COLUMN "id" TO ID;
ALTER TABLE BRONZE_CUSTOMERS RENAME COLUMN "name" TO NAME;
ALTER TABLE BRONZE_CUSTOMERS RENAME COLUMN "email" TO EMAIL;
ALTER TABLE BRONZE_CUSTOMERS RENAME COLUMN "phone" TO PHONE;
ALTER TABLE BRONZE_CUSTOMERS RENAME COLUMN "driver_license_number" TO DRIVER_LICENSE_NUMBER;
ALTER TABLE BRONZE_CUSTOMERS RENAME COLUMN "date_of_birth" TO DATE_OF_BIRTH;
