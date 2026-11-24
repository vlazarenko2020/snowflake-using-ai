
```text
Can you create a new folder bronze and create a separate file for each bronze table with SQLs and original source files
that were used to create each table.
```

## Output

The new `bronze/` folder holds one SQL file per Bronze table, a shared setup file, and copies of the 8 original source files.

```
bronze/
├── 00_SETUP.sql                              database, schema, stage, CSV_RAW_FMT, JSON_RAW_FMT
├── BRONZE_BRANCHES.sql                       ← branches.csv
├── BRONZE_CARS.sql                           ← cars.csv
├── BRONZE_CAR_CATEGORIES.sql                 ← car_categories.csv
├── BRONZE_COUNTRIES.sql                      ← countries.csv
├── BRONZE_CURRENCIES.sql                     ← currencies.csv
├── BRONZE_CUSTOMERS.sql                      ← customers.csv
├── BRONZE_BRANCH_CATEGORY_AVAILABILITY.sql   ← branch_category_availability.csv
├── BRONZE_BOOKWAVE_RESERVATIONS_RAW.sql      ← reservations_export.json
└── source_files/                             the 8 files above
```

**Where the SQL comes from:** it's the statements that actually built Bronze on 2026-11-23, taken from Snowflake's query history, rather than SQL written afresh.
- **`00_SETUP.sql`:** creates the database, schema, stage and the two file formats.
- **Table files:** each runs these steps in order:
  1. `PUT` the source file to the stage.
  2. `CREATE TABLE` with all-text columns.
  3. Load the data: `COPY INTO` for the CSVs, or `INSERT … LATERAL FLATTEN` over the `records` array for the JSON.
  4. Rename the table and its columns to uppercase. This step was added so the result matches what the Silver tables read from.

**Checks:** every source file copy is identical to its original in `Source_Data/`, and each table file's columns match its CSV's header row.

**Things to know:**
- **`PUT` needs a client:** it only works from a client such as SnowSQL, the Snowflake CLI or the VS Code extension, not from a Snowsight worksheet. The files keep the original absolute path, and a comment in each shows the shorter path to use from this repo (`bronze/source_files/...`).
- **Run order:** run `00_SETUP.sql` first; the table files can then run in any order.
- **Running a table file replaces the live table:** the Silver and Gold dynamic tables built on it will reinitialise.
- **Files not loaded:** `Source_Data/` also has `cars_fleet_expansion.csv` and an `Unstructured/` folder (reviews, support tickets, policy documents). None of these were loaded into Bronze, so they were not copied.

## SQL used

### Finding the original load statements

```sql
-- The last-7-day INFORMATION_SCHEMA history did not show the load, so the account-wide history was used
SELECT start_time, user_name, role_name, query_type, query_text
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= '2026-11-20'
  AND execution_status = 'SUCCESS'
  AND query_type IN ('CREATE','CREATE_TABLE','CREATE_TABLE_AS_SELECT','COPY','PUT_FILES','CREATE_STAGE','CREATE_FILE_FORMAT','CREATE_SCHEMA','CREATE_DATABASE','INSERT')
  AND (query_text ILIKE '%BRONZE%' OR query_text ILIKE '%AVELTO%' OR query_type = 'PUT_FILES')
ORDER BY start_time
LIMIT 200;

-- The setup statements (stage and file formats) from the first minute of the load
SELECT start_time, query_type, query_text
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time BETWEEN '2026-11-23 11:51:00' AND '2026-11-23 11:52:30'
  AND execution_status = 'SUCCESS'
ORDER BY start_time;
```

### Original statements recovered (2026-11-23, role SYSADMIN)

```sql
CREATE DATABASE IF NOT EXISTS AVELTO_RENTALS;
CREATE SCHEMA IF NOT EXISTS AVELTO_RENTALS.BRONZE;
USE SCHEMA AVELTO_RENTALS.BRONZE;
CREATE STAGE IF NOT EXISTS BRONZE_LANDING_STAGE;
CREATE OR REPLACE FILE FORMAT CSV_RAW_FMT TYPE=CSV PARSE_HEADER=TRUE TRIM_SPACE=FALSE EMPTY_FIELD_AS_NULL=FALSE NULL_IF=() ENCODING='UTF8' FIELD_OPTIONALLY_ENCLOSED_BY=NONE;
CREATE OR REPLACE FILE FORMAT JSON_RAW_FMT TYPE=JSON STRIP_OUTER_ARRAY=FALSE;

-- One PUT per file (shown for branches.csv; the same for the other 7)
PUT file:///home/sulp/CLAUDE_PROJECTS_VL2020_REPO/SNOWFLAKE/snowflake-using-ai/Source_Data/Bronze/FleetOps/branches.csv @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- One CREATE + COPY per CSV (shown for branches; the other 6 follow the same pattern)
CREATE OR REPLACE TABLE "bronze_branches" ("id" VARCHAR, "name" VARCHAR, "city" VARCHAR, "capacity" VARCHAR, "country_id" VARCHAR);
COPY INTO "bronze_branches" FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE FILES=('branches.csv') FILE_FORMAT=(FORMAT_NAME='CSV_RAW_FMT') MATCH_BY_COLUMN_NAME=CASE_SENSITIVE ON_ERROR=ABORT_STATEMENT;

-- JSON reservations: one row per element of the "records" array
CREATE OR REPLACE TABLE "bronze_bookwave_reservations_raw" (raw VARIANT);
INSERT INTO "bronze_bookwave_reservations_raw"
SELECT f.value
FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE/reservations_export.json (FILE_FORMAT => 'AVELTO_RENTALS.BRONZE.JSON_RAW_FMT') s,
     LATERAL FLATTEN(input => s.$1:records) f;
```

The full statements for every table, including the uppercase renames, are in the 9 files in `bronze/`. They were written to files only, not run again.


