
```text
Prompt 7 (verification, optional but recommended)
-------------------------------------------------
Run row counts on all eight Bronze tables and confirm they match the source
files exactly (seven CSVs plus 2,000 BookWave reservation records). Then run
row counts on all seven Gold tables and spot-check that every
pickup_branch_id and return_branch_id in fact_reservations exists in
dim_branches, and every currency_code in fact_reservations exists in
dim_currencies. Also show me the current refresh state of the Silver and
Gold Dynamic Tables and confirm they're meeting their target lag. Summarize
the results.
```

## Output

Everything checks out: Bronze matches the source files exactly, the Gold tables are consistent, and all 15 dynamic tables are refreshing successfully.

**Bronze vs source files**

| Source file | Rows in file | Bronze table | Bronze rows | Match |
|---|---|---|---|---|
| `branch_category_availability.csv` | 60 | `BRONZE_BRANCH_CATEGORY_AVAILABILITY` | 60 | yes |
| `branches.csv` | 10 | `BRONZE_BRANCHES` | 10 | yes |
| `car_categories.csv` | 6 | `BRONZE_CAR_CATEGORIES` | 6 | yes |
| `cars.csv` | 210 | `BRONZE_CARS` | 210 | yes |
| `countries.csv` | 7 | `BRONZE_COUNTRIES` | 7 | yes |
| `currencies.csv` | 6 | `BRONZE_CURRENCIES` | 6 | yes |
| `customers.csv` | 500 | `BRONZE_CUSTOMERS` | 500 | yes |
| `reservations_export.json` | 2,000 records | `BRONZE_BOOKWAVE_RESERVATIONS_RAW` | 2,000 | yes |

- The CSV counts leave out each file's header row.
- The JSON file is a single object, and the reservations sit in its `records` array of 2,000 entries, which matches Bronze. The file also contains `export_date`, `export_type`, `source` and `field_mapping_note`.

**Gold row counts and key checks**
- **Row counts:** `FACT_RESERVATIONS` 2,000; `DIM_BRANCHES` 10; `DIM_CARS` 210; `DIM_CUSTOMERS` 500; `DIM_COUNTRIES` 7; `DIM_CURRENCIES` 6; `BRIDGE_BRANCH_CATEGORY_AVAILABILITY` 60. All 7 match their Bronze sources.
- **Branches:** 0 `pickup_branch_id` and 0 `return_branch_id` values are missing from `DIM_BRANCHES`. All 10 branches are used both as a pickup and as a return branch.
- **Currencies:** 0 `currency_code` values are missing from `DIM_CURRENCIES`, and all 6 currencies are used.

**Refresh state and target lag**

| Layer | Tables | State | Last refresh | Target lag | Average lag | Highest lag | Share of time within target |
|---|---|---|---|---|---|---|---|
| Silver | 8 | ACTIVE | SUCCEEDED | 60 s | 25 s | 61–86 s | 1.000 |
| Gold | 7 | ACTIVE | SUCCEEDED | 180 s | 50 s | 105–111 s | 1.000 |

Both layers are meeting their target lag, with one caveat for Silver. Snowflake reports 1.000 as the share of time within target. But the highest lag for every Silver table was briefly above 60 seconds, up to 86 s for `STG_BRANCH_CATEGORY_AVAILABILITY`. So 1.000 means very nearly all the time, not literally always; these were short overshoots. Gold never came close to its 180-second limit.

## SQL used

### Bronze vs source files

```sql
-- Find the named file formats (inline FILE_FORMAT options are not allowed when querying a stage)
SHOW FILE FORMATS IN DATABASE AVELTO_RENTALS;

-- Structure of the JSON export: one object with a 2,000-entry "records" array
SELECT k.key, TYPEOF(k.value) AS value_type, IFF(IS_ARRAY(k.value), ARRAY_SIZE(k.value), NULL) AS array_size
FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE/reservations_export.json (FILE_FORMAT => 'AVELTO_RENTALS.BRONZE.JSON_RAW_FMT') s,
     LATERAL FLATTEN(INPUT => s.$1) k;

-- Bronze row counts vs staged files (CSV counts exclude the header row)
WITH src AS (
  SELECT LOWER(REGEXP_SUBSTR(METADATA$FILENAME, '[^/]+$')) AS f, COUNT(*) - 1 AS file_rows
  FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE (PATTERN => '.*[.]csv')
  GROUP BY 1
  UNION ALL
  SELECT 'reservations_export.json', SUM(ARRAY_SIZE($1:records))
  FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE/reservations_export.json (FILE_FORMAT => 'AVELTO_RENTALS.BRONZE.JSON_RAW_FMT')
),
bronze AS (
  SELECT 'branch_category_availability.csv' f, COUNT(*) n FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCH_CATEGORY_AVAILABILITY
  UNION ALL SELECT 'branches.csv', COUNT(*) FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES
  UNION ALL SELECT 'car_categories.csv', COUNT(*) FROM AVELTO_RENTALS.BRONZE.BRONZE_CAR_CATEGORIES
  UNION ALL SELECT 'cars.csv', COUNT(*) FROM AVELTO_RENTALS.BRONZE.BRONZE_CARS
  UNION ALL SELECT 'countries.csv', COUNT(*) FROM AVELTO_RENTALS.BRONZE.BRONZE_COUNTRIES
  UNION ALL SELECT 'currencies.csv', COUNT(*) FROM AVELTO_RENTALS.BRONZE.BRONZE_CURRENCIES
  UNION ALL SELECT 'customers.csv', COUNT(*) FROM AVELTO_RENTALS.BRONZE.BRONZE_CUSTOMERS
  UNION ALL SELECT 'reservations_export.json', COUNT(*) FROM AVELTO_RENTALS.BRONZE.BRONZE_BOOKWAVE_RESERVATIONS_RAW
)
SELECT b.f AS source_file, s.file_rows, b.n AS bronze_rows, s.file_rows = b.n AS matches
FROM bronze b LEFT JOIN src s ON s.f = b.f ORDER BY 1;
```

The JSON count uses `ARRAY_SIZE($1:records)` because the file is one object holding a `records` array. Counting rows directly returns 1. This version was run and returns 2,000.

### Gold row counts and key checks

```sql
SELECT 'FACT_RESERVATIONS' chk, COUNT(*) n FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'DIM_BRANCHES', COUNT(*) FROM AVELTO_RENTALS.GOLD.DIM_BRANCHES
UNION ALL SELECT 'DIM_CARS', COUNT(*) FROM AVELTO_RENTALS.GOLD.DIM_CARS
UNION ALL SELECT 'DIM_CUSTOMERS', COUNT(*) FROM AVELTO_RENTALS.GOLD.DIM_CUSTOMERS
UNION ALL SELECT 'DIM_COUNTRIES', COUNT(*) FROM AVELTO_RENTALS.GOLD.DIM_COUNTRIES
UNION ALL SELECT 'DIM_CURRENCIES', COUNT(*) FROM AVELTO_RENTALS.GOLD.DIM_CURRENCIES
UNION ALL SELECT 'BRIDGE_BRANCH_CATEGORY_AVAILABILITY', COUNT(*) FROM AVELTO_RENTALS.GOLD.BRIDGE_BRANCH_CATEGORY_AVAILABILITY
UNION ALL SELECT 'orphan pickup_branch_id', COUNT(*) FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS f LEFT JOIN AVELTO_RENTALS.GOLD.DIM_BRANCHES d ON d.branch_id = f.pickup_branch_id WHERE d.branch_id IS NULL
UNION ALL SELECT 'orphan return_branch_id', COUNT(*) FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS f LEFT JOIN AVELTO_RENTALS.GOLD.DIM_BRANCHES d ON d.branch_id = f.return_branch_id WHERE d.branch_id IS NULL
UNION ALL SELECT 'orphan currency_code', COUNT(*) FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS f LEFT JOIN AVELTO_RENTALS.GOLD.DIM_CURRENCIES d ON d.currency_code = f.currency_code WHERE d.currency_code IS NULL
UNION ALL SELECT 'distinct pickup branches used', COUNT(DISTINCT pickup_branch_id) FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'distinct return branches used', COUNT(DISTINCT return_branch_id) FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'distinct currencies used', COUNT(DISTINCT currency_code) FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS;
```

### Refresh state and target lag

```sql
SELECT schema_name, name, scheduling_state:state::STRING AS state, target_lag_sec,
       time_within_target_lag_ratio, maximum_lag_sec, mean_lag_sec,
       latest_data_timestamp, last_completed_refresh_state
FROM TABLE(AVELTO_RENTALS.INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE schema_name IN ('SILVER','GOLD') ORDER BY 1 DESC, 2;
```


