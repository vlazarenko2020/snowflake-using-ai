-- Bronze: BRONZE_BRANCH_CATEGORY_AVAILABILITY
-- Source file: source_files/branch_category_availability.csv (FleetOps), 60 data rows + header
-- Requires: 00_SETUP.sql
-- Steps 1-3 are exactly as originally run on 2026-11-23 (from query history).
-- Step 4 is the uppercase rename done afterwards, so Silver can use the table without quotes.
USE SCHEMA AVELTO_RENTALS.BRONZE;

-- 1. Upload the file to the stage.
--    PUT runs only from a client (SnowSQL / Snowflake CLI / VS Code extension), not from a Snowsight worksheet.
--    Original path shown; when running from this repo you can use 'file://bronze/source_files/branch_category_availability.csv'.
PUT file:///home/sulp/CLAUDE_PROJECTS_VL2020_REPO/SNOWFLAKE/snowflake-using-ai/Source_Data/Bronze/FleetOps/branch_category_availability.csv @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- 2. Create the table with the file's column names, all VARCHAR (no type changes)
CREATE OR REPLACE TABLE "bronze_branch_category_availability" ("branch_id" VARCHAR, "branch_name" VARCHAR, "category_id" VARCHAR, "category_name" VARCHAR, "is_offered" VARCHAR);

-- 3. Load the file
COPY INTO "bronze_branch_category_availability" FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE FILES=('branch_category_availability.csv') FILE_FORMAT=(FORMAT_NAME='CSV_RAW_FMT') MATCH_BY_COLUMN_NAME=CASE_SENSITIVE ON_ERROR=ABORT_STATEMENT;

-- 4. Rename table and columns to uppercase (no quotes needed afterwards)
ALTER TABLE "bronze_branch_category_availability" RENAME TO BRONZE_BRANCH_CATEGORY_AVAILABILITY;
ALTER TABLE BRONZE_BRANCH_CATEGORY_AVAILABILITY RENAME COLUMN "branch_id" TO BRANCH_ID;
ALTER TABLE BRONZE_BRANCH_CATEGORY_AVAILABILITY RENAME COLUMN "branch_name" TO BRANCH_NAME;
ALTER TABLE BRONZE_BRANCH_CATEGORY_AVAILABILITY RENAME COLUMN "category_id" TO CATEGORY_ID;
ALTER TABLE BRONZE_BRANCH_CATEGORY_AVAILABILITY RENAME COLUMN "category_name" TO CATEGORY_NAME;
ALTER TABLE BRONZE_BRANCH_CATEGORY_AVAILABILITY RENAME COLUMN "is_offered" TO IS_OFFERED;
