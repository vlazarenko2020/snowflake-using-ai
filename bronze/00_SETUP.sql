-- Bronze setup: database, schema, landing stage and file formats.
-- Run this once, before any of the per-table files.
-- Statements are exactly as originally run on 2026-11-23 (role SYSADMIN), from query history.

CREATE DATABASE IF NOT EXISTS AVELTO_RENTALS;
CREATE SCHEMA IF NOT EXISTS AVELTO_RENTALS.BRONZE;
USE SCHEMA AVELTO_RENTALS.BRONZE;

-- Internal stage that holds the uploaded source files
CREATE STAGE IF NOT EXISTS BRONZE_LANDING_STAGE;

-- CSV: read the header row for column names, keep every value exactly as written
CREATE OR REPLACE FILE FORMAT CSV_RAW_FMT
  TYPE = CSV
  PARSE_HEADER = TRUE
  TRIM_SPACE = FALSE
  EMPTY_FIELD_AS_NULL = FALSE
  NULL_IF = ()
  ENCODING = 'UTF8'
  FIELD_OPTIONALLY_ENCLOSED_BY = NONE;

-- JSON: the export is one object; records are pulled out with FLATTEN on load
CREATE OR REPLACE FILE FORMAT JSON_RAW_FMT
  TYPE = JSON
  STRIP_OUTER_ARRAY = FALSE;
