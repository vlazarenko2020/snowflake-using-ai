
```text
Prompt 5 (conform Bronze reference data into Silver, as Dynamic Tables)
-----------------------------------------------------------------------
Now conform the Bronze 
- countries, 
- currencies, and 
- branch_category_availability
tables into Silver-layer Dynamic Tables alongside stg_bookwave_reservations,
each with a target lag of 1 minute. 
Keep the grain of each table as-is, this is cleanup and standardization, not a redesign. 
Flag anything inconsistent, like a currency_code referenced by a branch that doesn't exist in the currencies table.
```

# Avelto Rentals – Bronze cleanup and Silver layer: summary and SQL log

Connection: `trial_20260917` · Role: `SYSADMIN` · Warehouse: `COMPUTE_WH` · Database: `AVELTO_RENTALS`

## Summary

1. **Fixed the stage query.** `SELECT * FROM @stage` failed with "SELECT with no columns". A stage has no columns that `*` can expand to, so staged files have to be read by position (`$1`, `$2`, …). The stage holds 7 CSV files and 1 JSON file (`reservations_export.json`).
2. **Checked the stage's directory feature.** It is **not enabled** on `BRONZE_LANDING_STAGE`. The `ALTER STAGE ... SET DIRECTORY` statements suggested were **not run**.
3. **Renamed tables.** All 8 BRONZE tables went from lowercase quoted names to uppercase unquoted names.
4. **Renamed columns.** 35 lowercase columns across the BRONZE tables became uppercase. SILVER columns were already uppercase. No quotes are needed anywhere now.
5. **Created the `AVELTO_RENTALS.SILVER` schema.**
6. **Created 4 Silver dynamic tables**, each with `TARGET_LAG = '1 minute'`, `REFRESH_MODE = AUTO` and the same grain as its Bronze source:

| Dynamic table | Source | Rows | Refresh mode | What it does |
|---|---|---|---|---|
| `STG_BOOKWAVE_RESERVATIONS` | `BRONZE_BOOKWAVE_RESERVATIONS_RAW` (VARIANT) | 2000 | ADAPTIVE | Flattens the JSON, pulls the first `paymentDetails` element up into columns, and converts `DD/MM/YYYY` strings to DATE |
| `STG_COUNTRIES` | `BRONZE_COUNTRIES` | 7 | FULL | Types `country_id`, trims text, uppercases codes, adds a `has_valid_currency` flag |
| `STG_CURRENCIES` | `BRONZE_CURRENCIES` | 6 | ADAPTIVE | Trims text and types `usd_exchange_rate` as `NUMBER(18,6)` and `decimals` as `NUMBER` |
| `STG_BRANCH_CATEGORY_AVAILABILITY` | `BRONZE_BRANCH_CATEGORY_AVAILABILITY` | 60 | FULL | Types the IDs, makes `is_offered` a BOOLEAN, adds `is_known_branch`, `is_known_category` and `branch_name_matches` flags |

7. **Consistency checks:** all came back with **0 problems**.
   - Every country's currency_code exists in currencies, and every currency is used by at least one country.
   - Every branch's country_id exists in countries.
   - Every branch and category referenced in availability exists, and the branch and category names match the master tables.
   - Every reservation's currency exists in currencies and matches the currency of its pickup branch's country.
   - Every pickup and dropoff branch referenced by a reservation exists.
   - There are no duplicate keys, all casts succeed, and the date columns have no NULLs.

### Things to know
- **Payments:** `STG_BOOKWAVE_RESERVATIONS` keeps only `paymentDetails[0]`. Today every reservation has exactly one payment, but extra payments would not appear.
- **Bad values:** `TRY_` casts turn malformed values into NULL instead of failing the refresh.
- **FULL refresh:** `STG_COUNTRIES` and `STG_BRANCH_CATEGORY_AVAILABILITY` refresh in FULL mode because of the expressions in their join keys. The tables are tiny, so the cost is negligible.
- **Old names:** any older SQL that uses quoted lowercase table or column names (e.g. `"bronze_cars"`, `"country_id"`) will now fail.

---

## SQL used, in run order

### 1. Fixing the stage query

```sql
DESCRIBE STAGE AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE;

LIST @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE;

SELECT METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, $1, $2, $3, $4, $5
FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE/branches.csv
LIMIT 5;

-- Working replacement for: select * from @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE;
SELECT METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, $1, $2, $3, $4, $5, $6, $7, $8
FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE (PATTERN => '.*[.]csv')
LIMIT 20;
```

Suggested for the JSON file (not run):

```sql
SELECT $1
FROM @AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE/reservations_export.json
  (FILE_FORMAT => (TYPE = JSON));
```

### 2. Directory table check

This one failed with "DIRECTORY not enabled".

```sql
SELECT * FROM DIRECTORY(@AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE);
```

Suggested to enable it (not run):

```sql
ALTER STAGE AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE SET DIRECTORY = (ENABLE = TRUE);
ALTER STAGE AVELTO_RENTALS.BRONZE.BRONZE_LANDING_STAGE REFRESH;
```

### 3. Looking at the reservations source (before the renames)

```sql
SELECT table_catalog, table_schema, table_name, row_count
FROM AVELTO_RENTALS.INFORMATION_SCHEMA.TABLES
WHERE table_name ILIKE '%BOOKWAVE%';

SELECT * FROM AVELTO_RENTALS.BRONZE."bronze_bookwave_reservations_raw" LIMIT 2;

DESCRIBE TABLE AVELTO_RENTALS.BRONZE."bronze_bookwave_reservations_raw";

SELECT ARRAY_SIZE(raw:paymentDetails) AS n_payments, COUNT(*) AS reservations,
       COUNT(DISTINCT raw:reservationId) AS distinct_ids,
       SUM(IFF(TRY_TO_DATE(raw:rentalStart::STRING,'DD/MM/YYYY') IS NULL,1,0)) AS bad_start,
       SUM(IFF(TRY_TO_DATE(raw:bookedOn::STRING,'DD/MM/YYYY') IS NULL,1,0)) AS bad_booked
FROM AVELTO_RENTALS.BRONZE."bronze_bookwave_reservations_raw"
GROUP BY 1 ORDER BY 1;

SELECT LISTAGG(schema_name, ', ') AS schemas, CURRENT_WAREHOUSE() AS wh, CURRENT_ROLE() AS role
FROM AVELTO_RENTALS.INFORMATION_SCHEMA.SCHEMATA;
```

The dynamic table's SELECT (section 6) was also run on its own with `LIMIT 3` as a test.

### 4. Renaming the BRONZE tables to uppercase

```sql
SELECT table_name, table_type
FROM AVELTO_RENTALS.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'BRONZE' ORDER BY 1;

BEGIN
ALTER TABLE AVELTO_RENTALS.BRONZE."bronze_bookwave_reservations_raw"    RENAME TO AVELTO_RENTALS.BRONZE.BRONZE_BOOKWAVE_RESERVATIONS_RAW;
ALTER TABLE AVELTO_RENTALS.BRONZE."bronze_branch_category_availability" RENAME TO AVELTO_RENTALS.BRONZE.BRONZE_BRANCH_CATEGORY_AVAILABILITY;
ALTER TABLE AVELTO_RENTALS.BRONZE."bronze_branches"                     RENAME TO AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES;
ALTER TABLE AVELTO_RENTALS.BRONZE."bronze_car_categories"               RENAME TO AVELTO_RENTALS.BRONZE.BRONZE_CAR_CATEGORIES;
ALTER TABLE AVELTO_RENTALS.BRONZE."bronze_cars"                         RENAME TO AVELTO_RENTALS.BRONZE.BRONZE_CARS;
ALTER TABLE AVELTO_RENTALS.BRONZE."bronze_countries"                    RENAME TO AVELTO_RENTALS.BRONZE.BRONZE_COUNTRIES;
ALTER TABLE AVELTO_RENTALS.BRONZE."bronze_currencies"                   RENAME TO AVELTO_RENTALS.BRONZE.BRONZE_CURRENCIES;
ALTER TABLE AVELTO_RENTALS.BRONZE."bronze_customers"                    RENAME TO AVELTO_RENTALS.BRONZE.BRONZE_CUSTOMERS;
END;
```

### 5. Silver schema and reservations dynamic table

```sql
CREATE SCHEMA IF NOT EXISTS AVELTO_RENTALS.SILVER;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    r.raw:reservationId::NUMBER                          AS reservation_id,
    r.raw:customerRef::NUMBER                            AS customer_id,
    r.raw:vehicleId::NUMBER                              AS vehicle_id,
    r.raw:pickupBranch::NUMBER                           AS pickup_branch_id,
    r.raw:dropoffBranch::NUMBER                          AS dropoff_branch_id,
    TRY_TO_DATE(r.raw:bookedOn::STRING,    'DD/MM/YYYY') AS booked_on,
    TRY_TO_DATE(r.raw:rentalStart::STRING, 'DD/MM/YYYY') AS rental_start,
    TRY_TO_DATE(r.raw:rentalEnd::STRING,   'DD/MM/YYYY') AS rental_end,
    r.raw:paymentDetails[0]:paymentId::NUMBER            AS payment_id,
    r.raw:paymentDetails[0]:amountPaid::NUMBER(12,2)     AS amount_paid,
    r.raw:paymentDetails[0]:currency::STRING             AS currency,
    r.raw:paymentDetails[0]:method::STRING               AS payment_method,
    TRY_TO_DATE(r.raw:paymentDetails[0]:paidOn::STRING, 'DD/MM/YYYY') AS payment_date
FROM AVELTO_RENTALS.BRONZE.BRONZE_BOOKWAVE_RESERVATIONS_RAW r;

SHOW DYNAMIC TABLES LIKE 'STG_BOOKWAVE_RESERVATIONS' IN SCHEMA AVELTO_RENTALS.SILVER;

SELECT COUNT(*) AS n, COUNT(DISTINCT reservation_id) AS ids,
  COUNT_IF(booked_on IS NULL OR rental_start IS NULL OR rental_end IS NULL OR payment_date IS NULL) AS null_dates
FROM AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS;

SELECT table_name
FROM AVELTO_RENTALS.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'BRONZE' ORDER BY 1;
```

### 6. Profiling countries, currencies and availability (before the column renames)

```sql
SELECT table_name, column_name, data_type, ordinal_position
FROM AVELTO_RENTALS.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'BRONZE'
  AND table_name IN ('BRONZE_COUNTRIES','BRONZE_CURRENCIES','BRONZE_BRANCH_CATEGORY_AVAILABILITY','BRONZE_BRANCHES')
ORDER BY table_name, ordinal_position;

SELECT * FROM AVELTO_RENTALS.BRONZE.BRONZE_CURRENCIES;

SELECT * FROM AVELTO_RENTALS.BRONZE.BRONZE_COUNTRIES;

SELECT "branch_id","branch_name","category_id","category_name","is_offered",
       COUNT(*) OVER (PARTITION BY "branch_id","category_id") AS dup
FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCH_CATEGORY_AVAILABILITY
ORDER BY TRY_TO_NUMBER("branch_id"), TRY_TO_NUMBER("category_id");

SELECT 'branch' t, "id" id, "name" name, "country_id" extra FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES
UNION ALL
SELECT 'category', $1::STRING, $2::STRING, NULL FROM AVELTO_RENTALS.BRONZE.BRONZE_CAR_CATEGORIES;

SELECT b."id", b."city", c."country_name", c."currency_code"
FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES b
LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_COUNTRIES c ON b."country_id" = c."country_id"
ORDER BY TRY_TO_NUMBER(b."id");
```

Consistency checks. A first version that used `NOT IN` subqueries failed with "Unsupported subquery type" and was rewritten with LEFT JOINs:

```sql
WITH b AS (SELECT TRY_TO_NUMBER("id") id, "name" name, TRY_TO_NUMBER("country_id") cid FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES),
c AS (SELECT TRY_TO_NUMBER("country_id") cid, "currency_code" cc FROM AVELTO_RENTALS.BRONZE.BRONZE_COUNTRIES),
cur AS (SELECT "currency_code" cc FROM AVELTO_RENTALS.BRONZE.BRONZE_CURRENCIES),
a AS (SELECT TRY_TO_NUMBER("branch_id") bid, "branch_name" bn, TRY_TO_NUMBER("category_id") catid, "category_name" catn, "is_offered" o FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCH_CATEGORY_AVAILABILITY),
cat AS (SELECT TRY_TO_NUMBER($1::STRING) id, $2::STRING n FROM AVELTO_RENTALS.BRONZE.BRONZE_CAR_CATEGORIES),
r AS (SELECT * FROM AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS)
SELECT 'country currency missing' chk, COUNT(*) n FROM c LEFT JOIN cur USING (cc) WHERE cur.cc IS NULL
UNION ALL SELECT 'branch country missing', COUNT(*) FROM b LEFT JOIN c ON b.cid=c.cid WHERE c.cid IS NULL
UNION ALL SELECT 'avail branch missing', COUNT(*) FROM a LEFT JOIN b ON a.bid=b.id WHERE b.id IS NULL
UNION ALL SELECT 'avail branch name mismatch', COUNT(*) FROM a JOIN b ON a.bid=b.id WHERE a.bn<>b.name
UNION ALL SELECT 'avail category missing', COUNT(*) FROM a LEFT JOIN cat ON a.catid=cat.id WHERE cat.id IS NULL
UNION ALL SELECT 'avail category name mismatch', COUNT(*) FROM a JOIN cat ON a.catid=cat.id WHERE a.catn<>cat.n
UNION ALL SELECT 'is_offered non-boolean', COUNT(*) FROM a WHERE TRY_TO_BOOLEAN(o) IS NULL
UNION ALL SELECT 'res currency not in currencies', COUNT(*) FROM r LEFT JOIN cur ON r.currency=cur.cc WHERE cur.cc IS NULL
UNION ALL SELECT 'res currency <> pickup branch currency', COUNT(*) FROM r JOIN b ON r.pickup_branch_id=b.id JOIN c ON b.cid=c.cid WHERE r.currency<>c.cc
UNION ALL SELECT 'res pickup branch missing', COUNT(*) FROM r LEFT JOIN b ON r.pickup_branch_id=b.id WHERE b.id IS NULL
UNION ALL SELECT 'res dropoff branch missing', COUNT(*) FROM r LEFT JOIN b ON r.dropoff_branch_id=b.id WHERE b.id IS NULL;

SELECT
 (SELECT COUNT_IF(TRY_TO_NUMBER("country_id") IS NULL) FROM AVELTO_RENTALS.BRONZE.BRONZE_COUNTRIES) bad_country_id,
 (SELECT COUNT_IF(TRY_TO_DECIMAL("usd_exchange_rate",18,6) IS NULL OR TRY_TO_NUMBER("decimals") IS NULL) FROM AVELTO_RENTALS.BRONZE.BRONZE_CURRENCIES) bad_cur_nums,
 (SELECT COUNT_IF(TRY_TO_NUMBER("branch_id") IS NULL OR TRY_TO_NUMBER("category_id") IS NULL) FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCH_CATEGORY_AVAILABILITY) bad_avail_ids;
```

### 7. Renaming the BRONZE columns to uppercase

```sql
SELECT table_schema, table_name, column_name
FROM AVELTO_RENTALS.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema IN ('BRONZE','SILVER') AND column_name <> UPPER(column_name)
ORDER BY 1, 2, ordinal_position;

-- Renamed 35 columns
EXECUTE IMMEDIATE $$
DECLARE
  c CURSOR FOR SELECT table_name, column_name FROM AVELTO_RENTALS.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema='BRONZE' AND column_name <> UPPER(column_name);
  n INTEGER DEFAULT 0;
  stmt STRING;
BEGIN
  FOR r IN c DO
    stmt := 'ALTER TABLE AVELTO_RENTALS.BRONZE.' || r.table_name || ' RENAME COLUMN "' || r.column_name || '" TO ' || UPPER(r.column_name);
    EXECUTE IMMEDIATE :stmt;
    n := n + 1;
  END FOR;
  RETURN n;
END;
$$;
```

### 8. Silver dynamic tables for countries, currencies and availability

```sql
CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_COUNTRIES
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    TRY_TO_NUMBER(TRIM(c.country_id))  AS country_id,
    UPPER(TRIM(c.country_code))        AS country_code,
    TRIM(c.country_name)               AS country_name,
    TRIM(c.region)                     AS region,
    UPPER(TRIM(c.currency_code))       AS currency_code,
    cur.currency_code IS NOT NULL      AS has_valid_currency
FROM AVELTO_RENTALS.BRONZE.BRONZE_COUNTRIES c
LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_CURRENCIES cur
  ON UPPER(TRIM(cur.currency_code)) = UPPER(TRIM(c.currency_code));

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_CURRENCIES
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    UPPER(TRIM(currency_code))                      AS currency_code,
    TRIM(currency_name)                             AS currency_name,
    TRIM(symbol)                                    AS symbol,
    TRY_TO_DECIMAL(TRIM(usd_exchange_rate), 18, 6)  AS usd_exchange_rate,
    TRY_TO_NUMBER(TRIM(decimals))                   AS decimals
FROM AVELTO_RENTALS.BRONZE.BRONZE_CURRENCIES;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_BRANCH_CATEGORY_AVAILABILITY
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    TRY_TO_NUMBER(TRIM(a.branch_id))    AS branch_id,
    TRIM(a.branch_name)                 AS branch_name,
    TRY_TO_NUMBER(TRIM(a.category_id))  AS category_id,
    TRIM(a.category_name)               AS category_name,
    TRY_TO_BOOLEAN(TRIM(a.is_offered))  AS is_offered,
    b.id   IS NOT NULL                  AS is_known_branch,
    cat.id IS NOT NULL                  AS is_known_category,
    TRIM(a.branch_name) = TRIM(b.name)  AS branch_name_matches
FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCH_CATEGORY_AVAILABILITY a
LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES b
  ON TRY_TO_NUMBER(TRIM(b.id)) = TRY_TO_NUMBER(TRIM(a.branch_id))
LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_CAR_CATEGORIES cat
  ON TRY_TO_NUMBER(TRIM(cat.id)) = TRY_TO_NUMBER(TRIM(a.category_id));
```

### 9. Final checks

```sql
SHOW DYNAMIC TABLES IN SCHEMA AVELTO_RENTALS.SILVER;

SELECT 'STG_COUNTRIES' t, COUNT(*) n, COUNT(DISTINCT country_id) k,
       COUNT_IF(NOT has_valid_currency OR country_id IS NULL) issues
FROM AVELTO_RENTALS.SILVER.STG_COUNTRIES
UNION ALL SELECT 'STG_CURRENCIES', COUNT(*), COUNT(DISTINCT currency_code),
       COUNT_IF(usd_exchange_rate IS NULL OR decimals IS NULL)
FROM AVELTO_RENTALS.SILVER.STG_CURRENCIES
UNION ALL SELECT 'STG_BRANCH_CATEGORY_AVAILABILITY', COUNT(*), COUNT(DISTINCT branch_id, category_id),
       COUNT_IF(NOT is_known_branch OR NOT is_known_category OR NOT branch_name_matches OR is_offered IS NULL)
FROM AVELTO_RENTALS.SILVER.STG_BRANCH_CATEGORY_AVAILABILITY
UNION ALL SELECT 'BRONZE non-upper columns', COUNT(*), NULL, NULL
FROM AVELTO_RENTALS.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema IN ('BRONZE','SILVER') AND column_name <> UPPER(column_name);
```

Result: 7/7, 6/6 and 60/60 rows to distinct keys, 0 issues in every table, and 0 non-uppercase columns left.

