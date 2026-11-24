-- Bronze: BRONZE_BOOKWAVE_RESERVATIONS_RAW
-- Source file: source_files/reservations_export.json (BookWave)
--   One JSON object: export_date, export_type, source, field_mapping_note, and a "records" array of 2,000 reservations.
--   Each record is stored unparsed in one VARIANT column, one row per reservation.
-- Requires: 00_SETUP.sql (stage and JSON_RAW_FMT)
-- Steps 1-3 are exactly as originally run on 2026-11-23 (from query history).
-- Step 4 is the uppercase rename done afterwards. The column RAW was created unquoted, so it is already uppercase.
USE SCHEMA AVELTO_RENTALS.BRONZE;

-- 1. Upload the file to the stage.
--    PUT runs only from a client (SnowSQL / Snowflake CLI / VS Code extension), not from a Snowsight worksheet.
--    Original path shown; when running from this repo you can use 'file://bronze/source_files/reservations_export.json'.
PUT file:///home/sulp/CLAUDE_PROJECTS_VL2020_REPO/SNOWFLAKE/snowflake-using-ai/Source_Data/Bronze/BookWave/reservations_export.json @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- 2. Create the table: a single VARIANT column
CREATE OR REPLACE TABLE "bronze_bookwave_reservations_raw" (raw VARIANT);

-- 3. Load one row per element of the top-level "records" array (nothing inside a record is parsed)
INSERT INTO "bronze_bookwave_reservations_raw"
SELECT f.value
FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE/reservations_export.json (FILE_FORMAT => 'AVELTO_RENTALS.BRONZE.JSON_RAW_FMT') s,
     LATERAL FLATTEN(input => s.$1:records) f;

-- 4. Rename table to uppercase (no quotes needed afterwards)
ALTER TABLE "bronze_bookwave_reservations_raw" RENAME TO BRONZE_BOOKWAVE_RESERVATIONS_RAW;
