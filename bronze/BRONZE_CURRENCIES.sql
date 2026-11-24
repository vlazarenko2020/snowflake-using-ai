-- Bronze: BRONZE_CURRENCIES
-- Source file: source_files/currencies.csv (FleetOps), 6 data rows + header
-- Requires: 00_SETUP.sql
-- Steps 1-3 are exactly as originally run on 2026-11-23 (from query history).
-- Step 4 is the uppercase rename done afterwards, so Silver can use the table without quotes.
USE SCHEMA AVELTO_RENTALS.BRONZE;

-- 1. Upload the file to the stage.
--    PUT runs only from a client (SnowSQL / Snowflake CLI / VS Code extension), not from a Snowsight worksheet.
--    Original path shown; when running from this repo you can use 'file://bronze/source_files/currencies.csv'.
PUT file:///home/sulp/CLAUDE_PROJECTS_VL2020_REPO/SNOWFLAKE/snowflake-using-ai/Source_Data/Bronze/FleetOps/currencies.csv @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- 2. Create the table with the file's column names, all VARCHAR (no type changes)
CREATE OR REPLACE TABLE "bronze_currencies" ("currency_code" VARCHAR, "currency_name" VARCHAR, "symbol" VARCHAR, "usd_exchange_rate" VARCHAR, "decimals" VARCHAR);

-- 3. Load the file
COPY INTO "bronze_currencies" FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE FILES=('currencies.csv') FILE_FORMAT=(FORMAT_NAME='CSV_RAW_FMT') MATCH_BY_COLUMN_NAME=CASE_SENSITIVE ON_ERROR=ABORT_STATEMENT;

-- 4. Rename table and columns to uppercase (no quotes needed afterwards)
ALTER TABLE "bronze_currencies" RENAME TO BRONZE_CURRENCIES;
ALTER TABLE BRONZE_CURRENCIES RENAME COLUMN "currency_code" TO CURRENCY_CODE;
ALTER TABLE BRONZE_CURRENCIES RENAME COLUMN "currency_name" TO CURRENCY_NAME;
ALTER TABLE BRONZE_CURRENCIES RENAME COLUMN "symbol" TO SYMBOL;
ALTER TABLE BRONZE_CURRENCIES RENAME COLUMN "usd_exchange_rate" TO USD_EXCHANGE_RATE;
ALTER TABLE BRONZE_CURRENCIES RENAME COLUMN "decimals" TO DECIMALS;
