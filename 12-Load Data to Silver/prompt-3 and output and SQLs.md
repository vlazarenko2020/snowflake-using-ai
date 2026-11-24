
```text
Prompt 5a (conform Bronze reference data into Silver, as Dynamic Tables)
------------------------------------------------------------------------
Is the silver layer complete? 
Check for completeness against the bronze layer.
```

## Output

The Silver layer is not complete. Only 4 of the 8 Bronze tables have a Silver dynamic table.

| Bronze table | Bronze rows | Silver table | Silver rows |
|---|---|---|---|
| `BRONZE_BOOKWAVE_RESERVATIONS_RAW` | 2000 | `STG_BOOKWAVE_RESERVATIONS` | 2000 |
| `BRONZE_BRANCH_CATEGORY_AVAILABILITY` | 60 | `STG_BRANCH_CATEGORY_AVAILABILITY` | 60 |
| `BRONZE_COUNTRIES` | 7 | `STG_COUNTRIES` | 7 |
| `BRONZE_CURRENCIES` | 6 | `STG_CURRENCIES` | 6 |
| `BRONZE_BRANCHES` | 10 | **missing** | – |
| `BRONZE_CAR_CATEGORIES` | 6 | **missing** | – |
| `BRONZE_CARS` | 210 | **missing** | – |
| `BRONZE_CUSTOMERS` | 500 | **missing** | – |

**The four that exist are complete.** Each has the same number of rows as its Bronze source, with no duplicate keys. Every Bronze column is carried over:
- Reservations: all 9 top-level JSON fields and all 5 payment fields.
- Countries, currencies and availability: all 5 columns each.

**The missing four weren't in either request so far.** The first request covered reservations and the second covered countries, currencies and availability. The missing tables are the ones the others refer to:
- `BRONZE_BRANCHES`: referenced by reservations (pickup and dropoff), availability, and branch to country.
- `BRONZE_CAR_CATEGORIES`: referenced by availability and cars.
- `BRONZE_CARS`: referenced by reservations through `vehicle_id`.
- `BRONZE_CUSTOMERS`: referenced by reservations through `customer_id`. It holds personal data (email, phone, driver's licence number, date of birth), so masking may be wanted on it in Silver.

The checks against branches and car categories have already passed. Cars and customers haven't been checked yet: whether every `vehicle_id` and `customer_id` in reservations exists, and whether every car's category and current branch exist.

Suggested next step: build the missing four the same way (1-minute target lag, typed and trimmed columns, flags for unknown references, same grain) and run those checks.

## SQL used

```sql
SELECT b.table_name AS bronze_table, b.row_count AS bronze_rows,
       s.table_name AS silver_table, s.row_count AS silver_rows
FROM AVELTO_RENTALS.INFORMATION_SCHEMA.TABLES b
LEFT JOIN AVELTO_RENTALS.INFORMATION_SCHEMA.TABLES s
  ON s.table_schema = 'SILVER'
 AND s.table_name = 'STG_' || REGEXP_REPLACE(REPLACE(b.table_name, 'BRONZE_', ''), '_RAW$', '')
WHERE b.table_schema = 'BRONZE'
ORDER BY 1;
```









```text
>Do you want me to build the missing four the same way (1-minute target lag, typed and trimmed columns, flags for unknown references, same grain) and run those checks?
yes
```

## Output

The Silver layer is now complete. All 8 Bronze tables have a Silver dynamic table, and every new check passed. All 8 dynamic tables are `ACTIVE` with a 1-minute target lag.

**The four new tables:**

| Dynamic table | Rows (= distinct keys) | Refresh mode | What it does |
|---|---|---|---|
| `STG_BRANCHES` | 10 | FULL | Types `branch_id`, `capacity` and `country_id`; adds an `is_known_country` flag |
| `STG_CAR_CATEGORIES` | 6 | ADAPTIVE | Types `category_id`; makes `daily_rate` a `NUMBER(12,2)` |
| `STG_CARS` | 210 | FULL | Types the IDs and `model_year` (from `year`); uppercases the licence plate; adds `is_known_category` and `is_known_branch` flags |
| `STG_CUSTOMERS` | 500 | ADAPTIVE | Lowercases the email; uppercases the licence number; makes `date_of_birth` a DATE; adds an `is_valid_email` flag |

Each one keeps the grain of its Bronze table, trims all text, and uses `TRY_` casts so a bad value becomes NULL instead of failing the refresh.

**Checks, all with 0 problems:**
- Row counts match Bronze, there are no duplicate IDs, licence plates or emails, and every cast and date conversion worked.
- Every car's category and current branch exist, and every branch's country exists.
- Every reservation's vehicle, customer, pickup branch and dropoff branch exists in Silver.
- No reservation was booked after its rental started, and none ends before it starts.

**Things to know:**
- **Phone numbers** come in mixed formats (`(554)724-9055x11961`, `977.884.1563x39201`, `001-…`). They are only trimmed; standardising them would mean choosing a target format, so they were left as they are.
- **Personal data:** `STG_CUSTOMERS` holds email, phone, driver's licence number and date of birth, with no masking applied yet.
- **FULL refresh:** `STG_BRANCHES` and `STG_CARS` refresh in FULL mode, like countries and availability. At these sizes the cost is negligible.

## SQL used

### Profiling the four Bronze tables

```sql
SELECT 'cars' t, OBJECT_CONSTRUCT(*)::STRING r FROM (SELECT * FROM AVELTO_RENTALS.BRONZE.BRONZE_CARS LIMIT 3)
UNION ALL SELECT 'cat', OBJECT_CONSTRUCT(*)::STRING FROM AVELTO_RENTALS.BRONZE.BRONZE_CAR_CATEGORIES
UNION ALL SELECT 'cust', OBJECT_CONSTRUCT(*)::STRING FROM (SELECT * FROM AVELTO_RENTALS.BRONZE.BRONZE_CUSTOMERS LIMIT 3)
UNION ALL SELECT 'branch', OBJECT_CONSTRUCT(*)::STRING FROM (SELECT * FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES LIMIT 2);

SELECT 'cars dup id' chk, COUNT(*)-COUNT(DISTINCT id) n FROM AVELTO_RENTALS.BRONZE.BRONZE_CARS
UNION ALL SELECT 'cars bad nums', COUNT_IF(TRY_TO_NUMBER(id) IS NULL OR TRY_TO_NUMBER(year) IS NULL OR TRY_TO_NUMBER(category_id) IS NULL OR TRY_TO_NUMBER(current_branch_id) IS NULL) FROM AVELTO_RENTALS.BRONZE.BRONZE_CARS
UNION ALL SELECT 'cars dup plate', COUNT(*)-COUNT(DISTINCT UPPER(TRIM(license_plate))) FROM AVELTO_RENTALS.BRONZE.BRONZE_CARS
UNION ALL SELECT 'cars unknown category', COUNT(*) FROM AVELTO_RENTALS.BRONZE.BRONZE_CARS c LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_CAR_CATEGORIES k ON c.category_id=k.id WHERE k.id IS NULL
UNION ALL SELECT 'cars unknown branch', COUNT(*) FROM AVELTO_RENTALS.BRONZE.BRONZE_CARS c LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES b ON c.current_branch_id=b.id WHERE b.id IS NULL
UNION ALL SELECT 'cat bad rate', COUNT_IF(TRY_TO_DECIMAL(daily_rate,12,2) IS NULL) FROM AVELTO_RENTALS.BRONZE.BRONZE_CAR_CATEGORIES
UNION ALL SELECT 'branch bad nums', COUNT_IF(TRY_TO_NUMBER(capacity) IS NULL) FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES
UNION ALL SELECT 'cust dup id', COUNT(*)-COUNT(DISTINCT id) FROM AVELTO_RENTALS.BRONZE.BRONZE_CUSTOMERS
UNION ALL SELECT 'cust dup email', COUNT(*)-COUNT(DISTINCT LOWER(TRIM(email))) FROM AVELTO_RENTALS.BRONZE.BRONZE_CUSTOMERS
UNION ALL SELECT 'cust bad dob (any fmt)', COUNT_IF(COALESCE(TRY_TO_DATE(date_of_birth,'YYYY-MM-DD'),TRY_TO_DATE(date_of_birth,'DD/MM/YYYY')) IS NULL) FROM AVELTO_RENTALS.BRONZE.BRONZE_CUSTOMERS
UNION ALL SELECT 'cust dob not ISO', COUNT_IF(TRY_TO_DATE(date_of_birth,'YYYY-MM-DD') IS NULL) FROM AVELTO_RENTALS.BRONZE.BRONZE_CUSTOMERS
UNION ALL SELECT 'cust bad email', COUNT_IF(NOT REGEXP_LIKE(TRIM(email), '^[^@ ]+@[^@ ]+\\.[^@ ]+$')) FROM AVELTO_RENTALS.BRONZE.BRONZE_CUSTOMERS
UNION ALL SELECT 'res unknown vehicle', COUNT(*) FROM AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS r LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_CARS c ON r.vehicle_id=TRY_TO_NUMBER(c.id) WHERE c.id IS NULL
UNION ALL SELECT 'res unknown customer', COUNT(*) FROM AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS r LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_CUSTOMERS c ON r.customer_id=TRY_TO_NUMBER(c.id) WHERE c.id IS NULL;
```

### Creating the dynamic tables

```sql
CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_CUSTOMERS
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    TRY_TO_NUMBER(TRIM(id))                        AS customer_id,
    TRIM(name)                                     AS customer_name,
    LOWER(TRIM(email))                             AS email,
    TRIM(phone)                                    AS phone,
    UPPER(TRIM(driver_license_number))             AS driver_license_number,
    TRY_TO_DATE(TRIM(date_of_birth), 'YYYY-MM-DD') AS date_of_birth,
    REGEXP_LIKE(TRIM(email), '^[^@ ]+@[^@ ]+\\.[^@ ]+$') AS is_valid_email
FROM AVELTO_RENTALS.BRONZE.BRONZE_CUSTOMERS;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_CAR_CATEGORIES
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    TRY_TO_NUMBER(TRIM(id))                  AS category_id,
    TRIM(name)                               AS category_name,
    TRY_TO_DECIMAL(TRIM(daily_rate), 12, 2)  AS daily_rate
FROM AVELTO_RENTALS.BRONZE.BRONZE_CAR_CATEGORIES;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_CARS
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    TRY_TO_NUMBER(TRIM(c.id))                 AS car_id,
    UPPER(TRIM(c.license_plate))              AS license_plate,
    TRIM(c.model)                             AS model,
    TRY_TO_NUMBER(TRIM(c.year))               AS model_year,
    TRY_TO_NUMBER(TRIM(c.category_id))        AS category_id,
    TRY_TO_NUMBER(TRIM(c.current_branch_id))  AS current_branch_id,
    k.id IS NOT NULL                          AS is_known_category,
    b.id IS NOT NULL                          AS is_known_branch
FROM AVELTO_RENTALS.BRONZE.BRONZE_CARS c
LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_CAR_CATEGORIES k
  ON TRY_TO_NUMBER(TRIM(k.id)) = TRY_TO_NUMBER(TRIM(c.category_id))
LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES b
  ON TRY_TO_NUMBER(TRIM(b.id)) = TRY_TO_NUMBER(TRIM(c.current_branch_id));

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.SILVER.STG_BRANCHES
  TARGET_LAG = '1 minute'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
AS
SELECT
    TRY_TO_NUMBER(TRIM(b.id))          AS branch_id,
    TRIM(b.name)                       AS branch_name,
    TRIM(b.city)                       AS city,
    TRY_TO_NUMBER(TRIM(b.capacity))    AS capacity,
    TRY_TO_NUMBER(TRIM(b.country_id))  AS country_id,
    c.country_id IS NOT NULL           AS is_known_country
FROM AVELTO_RENTALS.BRONZE.BRONZE_BRANCHES b
LEFT JOIN AVELTO_RENTALS.BRONZE.BRONZE_COUNTRIES c
  ON TRY_TO_NUMBER(TRIM(c.country_id)) = TRY_TO_NUMBER(TRIM(b.country_id));
```

### Checking the result

```sql
SELECT 'STG_BRANCHES' t, COUNT(*) n, COUNT(DISTINCT branch_id) k, COUNT_IF(NOT is_known_country OR branch_id IS NULL OR capacity IS NULL) issues FROM AVELTO_RENTALS.SILVER.STG_BRANCHES
UNION ALL SELECT 'STG_CAR_CATEGORIES', COUNT(*), COUNT(DISTINCT category_id), COUNT_IF(daily_rate IS NULL) FROM AVELTO_RENTALS.SILVER.STG_CAR_CATEGORIES
UNION ALL SELECT 'STG_CARS', COUNT(*), COUNT(DISTINCT car_id), COUNT_IF(NOT is_known_category OR NOT is_known_branch OR model_year IS NULL) FROM AVELTO_RENTALS.SILVER.STG_CARS
UNION ALL SELECT 'STG_CUSTOMERS', COUNT(*), COUNT(DISTINCT customer_id), COUNT_IF(NOT is_valid_email OR date_of_birth IS NULL) FROM AVELTO_RENTALS.SILVER.STG_CUSTOMERS
UNION ALL SELECT 'res unknown vehicle', COUNT(*), NULL, NULL FROM AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS r LEFT JOIN AVELTO_RENTALS.SILVER.STG_CARS c ON r.vehicle_id=c.car_id WHERE c.car_id IS NULL
UNION ALL SELECT 'res unknown customer', COUNT(*), NULL, NULL FROM AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS r LEFT JOIN AVELTO_RENTALS.SILVER.STG_CUSTOMERS c ON r.customer_id=c.customer_id WHERE c.customer_id IS NULL
UNION ALL SELECT 'res unknown branch', COUNT(*), NULL, NULL FROM AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS r LEFT JOIN AVELTO_RENTALS.SILVER.STG_BRANCHES p ON r.pickup_branch_id=p.branch_id LEFT JOIN AVELTO_RENTALS.SILVER.STG_BRANCHES d ON r.dropoff_branch_id=d.branch_id WHERE p.branch_id IS NULL OR d.branch_id IS NULL
UNION ALL SELECT 'res booked after rental start', COUNT_IF(booked_on > rental_start), NULL, NULL FROM AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS
UNION ALL SELECT 'res rental end before start', COUNT_IF(rental_end < rental_start), NULL, NULL FROM AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS
UNION ALL SELECT 'silver DTs not ACTIVE / lag<>1 min', COUNT(*), NULL, NULL FROM TABLE(AVELTO_RENTALS.INFORMATION_SCHEMA.DYNAMIC_TABLES()) WHERE schema_name='SILVER' AND (scheduling_state:state::STRING <> 'ACTIVE' OR target_lag_sec <> 60);

SHOW DYNAMIC TABLES IN SCHEMA AVELTO_RENTALS.SILVER;
```



