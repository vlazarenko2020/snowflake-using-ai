-- Bronze: BRONZE_COUNTRIES
-- Source file: source_files/countries.csv (FleetOps), 7 data rows + header
-- Requires: 00_SETUP.sql
-- Steps 1-3 are exactly as originally run on 2026-11-23 (from query history).
-- Step 4 is the uppercase rename done afterwards, so Silver can use the table without quotes.
USE SCHEMA AVELTO_RENTALS.BRONZE;

-- 1. Upload the file to the stage.
--    PUT runs only from a client (SnowSQL / Snowflake CLI / VS Code extension), not from a Snowsight worksheet.
--    Original path shown; when running from this repo you can use 'file://bronze/source_files/countries.csv'.
PUT file:///home/sulp/CLAUDE_PROJECTS_VL2020_REPO/SNOWFLAKE/snowflake-using-ai/Source_Data/Bronze/FleetOps/countries.csv @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- 2. Create the table with the file's column names, all VARCHAR (no type changes)
CREATE OR REPLACE TABLE "bronze_countries" ("country_id" VARCHAR, "country_code" VARCHAR, "country_name" VARCHAR, "region" VARCHAR, "currency_code" VARCHAR);

-- 3. Load the file
COPY INTO "bronze_countries" FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE FILES=('countries.csv') FILE_FORMAT=(FORMAT_NAME='CSV_RAW_FMT') MATCH_BY_COLUMN_NAME=CASE_SENSITIVE ON_ERROR=ABORT_STATEMENT;

-- 4. Rename table and columns to uppercase (no quotes needed afterwards)
ALTER TABLE "bronze_countries" RENAME TO BRONZE_COUNTRIES;
ALTER TABLE BRONZE_COUNTRIES RENAME COLUMN "country_id" TO COUNTRY_ID;
ALTER TABLE BRONZE_COUNTRIES RENAME COLUMN "country_code" TO COUNTRY_CODE;
ALTER TABLE BRONZE_COUNTRIES RENAME COLUMN "country_name" TO COUNTRY_NAME;
ALTER TABLE BRONZE_COUNTRIES RENAME COLUMN "region" TO REGION;
ALTER TABLE BRONZE_COUNTRIES RENAME COLUMN "currency_code" TO CURRENCY_CODE;
