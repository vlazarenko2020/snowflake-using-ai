-- Bronze: BRONZE_CARS
-- Source file: source_files/cars.csv (FleetOps), 210 data rows + header
-- Requires: 00_SETUP.sql
-- Steps 1-3 are exactly as originally run on 2026-11-23 (from query history).
-- Step 4 is the uppercase rename done afterwards, so Silver can use the table without quotes.
USE SCHEMA AVELTO_RENTALS.BRONZE;

-- 1. Upload the file to the stage.
--    PUT runs only from a client (SnowSQL / Snowflake CLI / VS Code extension), not from a Snowsight worksheet.
--    Original path shown; when running from this repo you can use 'file://bronze/source_files/cars.csv'.
PUT file:///home/sulp/CLAUDE_PROJECTS_VL2020_REPO/SNOWFLAKE/snowflake-using-ai/Source_Data/Bronze/FleetOps/cars.csv @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- 2. Create the table with the file's column names, all VARCHAR (no type changes)
CREATE OR REPLACE TABLE "bronze_cars" ("id" VARCHAR, "license_plate" VARCHAR, "model" VARCHAR, "year" VARCHAR, "category_id" VARCHAR, "current_branch_id" VARCHAR);

-- 3. Load the file
COPY INTO "bronze_cars" FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE FILES=('cars.csv') FILE_FORMAT=(FORMAT_NAME='CSV_RAW_FMT') MATCH_BY_COLUMN_NAME=CASE_SENSITIVE ON_ERROR=ABORT_STATEMENT;

-- 4. Rename table and columns to uppercase (no quotes needed afterwards)
ALTER TABLE "bronze_cars" RENAME TO BRONZE_CARS;
ALTER TABLE BRONZE_CARS RENAME COLUMN "id" TO ID;
ALTER TABLE BRONZE_CARS RENAME COLUMN "license_plate" TO LICENSE_PLATE;
ALTER TABLE BRONZE_CARS RENAME COLUMN "model" TO MODEL;
ALTER TABLE BRONZE_CARS RENAME COLUMN "year" TO YEAR;
ALTER TABLE BRONZE_CARS RENAME COLUMN "category_id" TO CATEGORY_ID;
ALTER TABLE BRONZE_CARS RENAME COLUMN "current_branch_id" TO CURRENT_BRANCH_ID;
