-- Bronze: BRONZE_CAR_CATEGORIES
-- Source file: source_files/car_categories.csv (FleetOps), 6 data rows + header
-- Requires: 00_SETUP.sql
-- Steps 1-3 are exactly as originally run on 2026-11-23 (from query history).
-- Step 4 is the uppercase rename done afterwards, so Silver can use the table without quotes.
USE SCHEMA AVELTO_RENTALS.BRONZE;

-- 1. Upload the file to the stage.
--    PUT runs only from a client (SnowSQL / Snowflake CLI / VS Code extension), not from a Snowsight worksheet.
--    Original path shown; when running from this repo you can use 'file://bronze/source_files/car_categories.csv'.
PUT file:///home/sulp/CLAUDE_PROJECTS_VL2020_REPO/SNOWFLAKE/snowflake-using-ai/Source_Data/Bronze/FleetOps/car_categories.csv @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- 2. Create the table with the file's column names, all VARCHAR (no type changes)
CREATE OR REPLACE TABLE "bronze_car_categories" ("id" VARCHAR, "name" VARCHAR, "daily_rate" VARCHAR);

-- 3. Load the file
COPY INTO "bronze_car_categories" FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE FILES=('car_categories.csv') FILE_FORMAT=(FORMAT_NAME='CSV_RAW_FMT') MATCH_BY_COLUMN_NAME=CASE_SENSITIVE ON_ERROR=ABORT_STATEMENT;

-- 4. Rename table and columns to uppercase (no quotes needed afterwards)
ALTER TABLE "bronze_car_categories" RENAME TO BRONZE_CAR_CATEGORIES;
ALTER TABLE BRONZE_CAR_CATEGORIES RENAME COLUMN "id" TO ID;
ALTER TABLE BRONZE_CAR_CATEGORIES RENAME COLUMN "name" TO NAME;
ALTER TABLE BRONZE_CAR_CATEGORIES RENAME COLUMN "daily_rate" TO DAILY_RATE;
