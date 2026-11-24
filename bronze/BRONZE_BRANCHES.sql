-- Bronze: BRONZE_BRANCHES
-- Source file: source_files/branches.csv (FleetOps), 10 data rows + header
-- Requires: 00_SETUP.sql
-- Steps 1-3 are exactly as originally run on 2026-11-23 (from query history).
-- Step 4 is the uppercase rename done afterwards, so Silver can use the table without quotes.
USE SCHEMA AVELTO_RENTALS.BRONZE;

-- 1. Upload the file to the stage.
--    PUT runs only from a client (SnowSQL / Snowflake CLI / VS Code extension), not from a Snowsight worksheet.
--    Original path shown; when running from this repo you can use 'file://bronze/source_files/branches.csv'.
PUT file:///home/sulp/CLAUDE_PROJECTS_VL2020_REPO/SNOWFLAKE/snowflake-using-ai/Source_Data/Bronze/FleetOps/branches.csv @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- 2. Create the table with the file's column names, all VARCHAR (no type changes)
CREATE OR REPLACE TABLE "bronze_branches" ("id" VARCHAR, "name" VARCHAR, "city" VARCHAR, "capacity" VARCHAR, "country_id" VARCHAR);

-- 3. Load the file
COPY INTO "bronze_branches" FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE FILES=('branches.csv') FILE_FORMAT=(FORMAT_NAME='CSV_RAW_FMT') MATCH_BY_COLUMN_NAME=CASE_SENSITIVE ON_ERROR=ABORT_STATEMENT;

-- 4. Rename table and columns to uppercase (no quotes needed afterwards)
ALTER TABLE "bronze_branches" RENAME TO BRONZE_BRANCHES;
ALTER TABLE BRONZE_BRANCHES RENAME COLUMN "id" TO ID;
ALTER TABLE BRONZE_BRANCHES RENAME COLUMN "name" TO NAME;
ALTER TABLE BRONZE_BRANCHES RENAME COLUMN "city" TO CITY;
ALTER TABLE BRONZE_BRANCHES RENAME COLUMN "capacity" TO CAPACITY;
ALTER TABLE BRONZE_BRANCHES RENAME COLUMN "country_id" TO COUNTRY_ID;
