
```text
Prompt 6 (land the Gold star schema, as chained Dynamic Tables)
---------------------------------------------------------------
Using the Silver-layer Dynamic Tables (plus the already-clean Bronze
branches, cars, and customers tables), build the Gold-layer star schema as
Dynamic Tables, each with a target lag of 3 minutes so they refresh shortly
after Silver does:
- fact_reservations: one row per reservation, with amount_local, currency_code,
  and a total_amount_usd column converted using the currencies exchange rate
- dim_branches: branches enriched with country, region, and currency_code
- dim_cars, dim_customers: as-is from Bronze, no cleanup was needed
- dim_countries, dim_currencies: new reference dimensions
- bridge_branch_category_availability: one row per branch x category with an
  is_offered flag

Use dim_branches twice in fact_reservations, once for pickup_branch_id, once
for return_branch_id, since a rental can start and end at different branches.
```

## Output

The Gold star schema is built: all 7 dynamic tables in `AVELTO_RENTALS.GOLD` are `ACTIVE` with a 3-minute target lag, and every check passed.

| Dynamic table | Rows (= distinct keys) | Built from | Refresh mode |
|---|---|---|---|
| `FACT_RESERVATIONS` | 2000 | `STG_BOOKWAVE_RESERVATIONS` + `STG_CURRENCIES` | ADAPTIVE |
| `DIM_BRANCHES` | 10 | `STG_BRANCHES` + `STG_COUNTRIES` | FULL |
| `DIM_CARS` | 210 | `STG_CARS` | FULL |
| `DIM_CUSTOMERS` | 500 | `STG_CUSTOMERS` | ADAPTIVE |
| `DIM_COUNTRIES` | 7 | `STG_COUNTRIES` | FULL |
| `DIM_CURRENCIES` | 6 | `STG_CURRENCIES` | ADAPTIVE |
| `BRIDGE_BRANCH_CATEGORY_AVAILABILITY` | 60 | `STG_BRANCH_CATEGORY_AVAILABILITY` | FULL |

**Fact table:**
- Each row has `amount_local`, `currency_code` and `total_amount_usd`, which is `amount_local × usd_exchange_rate` rounded to 2 decimals. It also has `rental_days` and the payment fields.
- It has both `pickup_branch_id` and `return_branch_id` (the source's `dropoff_branch_id`). Each joins to `DIM_BRANCHES` separately.
- **Most rentals are one-way:** 1,818 of the 2,000 start and end at different branches.

**Checks:**
- Every foreign key in the fact table finds its dimension row: customer, car, pickup branch, return branch and currency.
- `total_amount_usd` is never NULL.
- Every branch has a country, and every bridge row's branch exists.

A sample query joining `DIM_BRANCHES` twice works. The top routes by revenue are US → US ($115,950) and US → Germany ($101,270).

**Things to know:**
- **Source tables:** branches, cars and customers come from the Silver `STG_` tables instead of Bronze. The rows are the same, but the columns have proper types (in Bronze every column is TEXT).
- **FULL refresh:** four Gold tables refresh in FULL mode because their Silver sources do. At these sizes the cost is negligible.
- **Personal data:** customer email, phone, driver's licence number and date of birth are still unmasked in `DIM_CUSTOMERS`.
- **Car categories:** there is no `DIM_CAR_CATEGORIES`. `DIM_CARS` and the bridge carry only `category_id`, and the bridge also has `category_name`.

## SQL used

### Pre-checks

```sql
SELECT (SELECT LISTAGG(schema_name, ',') FROM AVELTO_RENTALS.INFORMATION_SCHEMA.SCHEMATA) schemas,
 (SELECT MIN(DATEDIFF(day, rental_start, rental_end)) FROM AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS) min_days,
 (SELECT COUNT_IF(DATEDIFF(day, rental_start, rental_end)=0) FROM AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS) zero_day;
```

The `FACT_RESERVATIONS` SELECT below was also run on its own with `LIMIT 3` as a test.

### Creating the Gold schema and dynamic tables

```sql
CREATE SCHEMA IF NOT EXISTS AVELTO_RENTALS.GOLD;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.GOLD.DIM_CURRENCIES
  TARGET_LAG = '3 minutes' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO
AS
SELECT currency_code, currency_name, symbol, usd_exchange_rate, decimals
FROM AVELTO_RENTALS.SILVER.STG_CURRENCIES;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.GOLD.DIM_COUNTRIES
  TARGET_LAG = '3 minutes' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO
AS
SELECT country_id, country_code, country_name, region, currency_code
FROM AVELTO_RENTALS.SILVER.STG_COUNTRIES;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.GOLD.DIM_BRANCHES
  TARGET_LAG = '3 minutes' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO
AS
SELECT b.branch_id, b.branch_name, b.city, b.capacity, b.country_id,
       c.country_name, c.region, c.currency_code
FROM AVELTO_RENTALS.SILVER.STG_BRANCHES b
LEFT JOIN AVELTO_RENTALS.SILVER.STG_COUNTRIES c ON c.country_id = b.country_id;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.GOLD.DIM_CARS
  TARGET_LAG = '3 minutes' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO
AS
SELECT car_id, license_plate, model, model_year, category_id, current_branch_id
FROM AVELTO_RENTALS.SILVER.STG_CARS;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.GOLD.DIM_CUSTOMERS
  TARGET_LAG = '3 minutes' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO
AS
SELECT customer_id, customer_name, email, phone, driver_license_number, date_of_birth
FROM AVELTO_RENTALS.SILVER.STG_CUSTOMERS;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.GOLD.BRIDGE_BRANCH_CATEGORY_AVAILABILITY
  TARGET_LAG = '3 minutes' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO
AS
SELECT branch_id, category_id, category_name, is_offered
FROM AVELTO_RENTALS.SILVER.STG_BRANCH_CATEGORY_AVAILABILITY;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
  TARGET_LAG = '3 minutes' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO
AS
SELECT
    r.reservation_id,
    r.customer_id,
    r.vehicle_id                                   AS car_id,
    r.pickup_branch_id,
    r.dropoff_branch_id                            AS return_branch_id,
    r.booked_on,
    r.rental_start,
    r.rental_end,
    DATEDIFF(day, r.rental_start, r.rental_end)    AS rental_days,
    r.payment_id,
    r.payment_method,
    r.payment_date,
    r.amount_paid                                  AS amount_local,
    r.currency                                     AS currency_code,
    ROUND(r.amount_paid * c.usd_exchange_rate, 2)  AS total_amount_usd
FROM AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS r
LEFT JOIN AVELTO_RENTALS.SILVER.STG_CURRENCIES c ON c.currency_code = r.currency;
```

These statements were run together in one `EXECUTE IMMEDIATE $$ BEGIN ... END; $$` block.

### Checking the result

```sql
SHOW DYNAMIC TABLES IN SCHEMA AVELTO_RENTALS.GOLD;

SELECT 'FACT_RESERVATIONS' t, COUNT(*) n, COUNT(DISTINCT reservation_id) k FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'DIM_BRANCHES', COUNT(*), COUNT(DISTINCT branch_id) FROM AVELTO_RENTALS.GOLD.DIM_BRANCHES
UNION ALL SELECT 'DIM_CARS', COUNT(*), COUNT(DISTINCT car_id) FROM AVELTO_RENTALS.GOLD.DIM_CARS
UNION ALL SELECT 'DIM_CUSTOMERS', COUNT(*), COUNT(DISTINCT customer_id) FROM AVELTO_RENTALS.GOLD.DIM_CUSTOMERS
UNION ALL SELECT 'DIM_COUNTRIES', COUNT(*), COUNT(DISTINCT country_id) FROM AVELTO_RENTALS.GOLD.DIM_COUNTRIES
UNION ALL SELECT 'DIM_CURRENCIES', COUNT(*), COUNT(DISTINCT currency_code) FROM AVELTO_RENTALS.GOLD.DIM_CURRENCIES
UNION ALL SELECT 'BRIDGE_BRANCH_CATEGORY_AVAILABILITY', COUNT(*), COUNT(DISTINCT branch_id, category_id) FROM AVELTO_RENTALS.GOLD.BRIDGE_BRANCH_CATEGORY_AVAILABILITY
UNION ALL SELECT 'orphan: fact.customer_id', COUNT(*), NULL FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS f LEFT JOIN AVELTO_RENTALS.GOLD.DIM_CUSTOMERS d ON d.customer_id=f.customer_id WHERE d.customer_id IS NULL
UNION ALL SELECT 'orphan: fact.car_id', COUNT(*), NULL FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS f LEFT JOIN AVELTO_RENTALS.GOLD.DIM_CARS d ON d.car_id=f.car_id WHERE d.car_id IS NULL
UNION ALL SELECT 'orphan: fact.pickup_branch_id', COUNT(*), NULL FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS f LEFT JOIN AVELTO_RENTALS.GOLD.DIM_BRANCHES d ON d.branch_id=f.pickup_branch_id WHERE d.branch_id IS NULL
UNION ALL SELECT 'orphan: fact.return_branch_id', COUNT(*), NULL FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS f LEFT JOIN AVELTO_RENTALS.GOLD.DIM_BRANCHES d ON d.branch_id=f.return_branch_id WHERE d.branch_id IS NULL
UNION ALL SELECT 'orphan: fact.currency_code', COUNT(*), NULL FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS f LEFT JOIN AVELTO_RENTALS.GOLD.DIM_CURRENCIES d ON d.currency_code=f.currency_code WHERE d.currency_code IS NULL
UNION ALL SELECT 'null total_amount_usd', COUNT_IF(total_amount_usd IS NULL), NULL FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'orphan: branch.country_id', COUNT_IF(country_name IS NULL), NULL FROM AVELTO_RENTALS.GOLD.DIM_BRANCHES
UNION ALL SELECT 'orphan: bridge.branch_id', COUNT(*), NULL FROM AVELTO_RENTALS.GOLD.BRIDGE_BRANCH_CATEGORY_AVAILABILITY x LEFT JOIN AVELTO_RENTALS.GOLD.DIM_BRANCHES d ON d.branch_id=x.branch_id WHERE d.branch_id IS NULL
UNION ALL SELECT 'reservations pickup <> return branch', COUNT_IF(pickup_branch_id<>return_branch_id), NULL FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS;
```

### Sample star query (DIM_BRANCHES joined twice)

```sql
SELECT pb.country_name AS pickup_country, rb.country_name AS return_country,
       COUNT(*) AS reservations, SUM(f.total_amount_usd) AS revenue_usd
FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS f
JOIN AVELTO_RENTALS.GOLD.DIM_BRANCHES pb ON pb.branch_id = f.pickup_branch_id
JOIN AVELTO_RENTALS.GOLD.DIM_BRANCHES rb ON rb.branch_id = f.return_branch_id
GROUP BY 1, 2 ORDER BY revenue_usd DESC LIMIT 5;
```






