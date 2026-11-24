
```text
Prompt 5a ( SQLs for Silver Layer Tables)
------------------------------------------------------------------------
Do the same for silver layer tables as you did for gold layer. 
Create s new folder silver and put there all SQLs needed to recreate the silver layer tables.
```

## Output

The new `silver/` folder has everything needed to recreate the Silver layer: one SQL file per table (8 in total) and a documentation file.

**SQL files**, one per table:
- `STG_BOOKWAVE_RESERVATIONS.sql`
- `STG_CUSTOMERS.sql`
- `STG_CARS.sql`
- `STG_CAR_CATEGORIES.sql`
- `STG_BRANCHES.sql`
- `STG_COUNTRIES.sql`
- `STG_CURRENCIES.sql`
- `STG_BRANCH_CATEGORY_AVAILABILITY.sql`

Each file contains `CREATE SCHEMA IF NOT EXISTS` followed by the `CREATE OR REPLACE DYNAMIC TABLE` statement. The SQL matches the definitions Snowflake has stored for the live tables. Silver tables depend only on Bronze, so the files can be run in any order.

**`Silver layer documentation.md`**, built like the Gold one:
- **Overview:** grain, row count, key, Bronze source, refresh mode and SQL file for each table.
- **Relationships:** the joins between tables and a Mermaid diagram.
- **Column reference:** for every table, each column's data type, a business description and the exact transformation from Bronze, with the data-quality flag columns marked.
- **Data quality:** the results of the checks so far, plus a recheck query. That query was run and returns 0 problems for every table.
- **Recreating the layer:** what must exist first (uppercase Bronze tables, `COMPUTE_WH`, a suitable role).
- **Known limitations.**

**One caution, also in the document:** running a file replaces the live table, and the Gold tables built on it reinitialise on their next refresh.

The `gold/` folder still has only `FACT_RESERVATIONS.sql` and its documentation; the other 6 Gold SQL files have not been written yet.

## SQL used

### Live definitions, row counts and refresh modes

```sql
-- The "text" column holds each table's stored definition; it was compared with the SQL files
SHOW DYNAMIC TABLES IN SCHEMA AVELTO_RENTALS.SILVER;
```

### Column names and data types for the documentation

```sql
SELECT table_name, ordinal_position, column_name,
       CASE WHEN data_type='NUMBER' THEN data_type||'('||numeric_precision||','||numeric_scale||')'
            WHEN data_type='TEXT' THEN 'VARCHAR' ELSE data_type END AS full_type
FROM AVELTO_RENTALS.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'SILVER'
ORDER BY table_name, ordinal_position;
```

### Data-quality flag recheck (result: 0 for every table)

```sql
SELECT 'STG_COUNTRIES' t, COUNT_IF(NOT has_valid_currency) bad FROM AVELTO_RENTALS.SILVER.STG_COUNTRIES
UNION ALL SELECT 'STG_BRANCHES', COUNT_IF(NOT is_known_country) FROM AVELTO_RENTALS.SILVER.STG_BRANCHES
UNION ALL SELECT 'STG_CARS', COUNT_IF(NOT is_known_category OR NOT is_known_branch) FROM AVELTO_RENTALS.SILVER.STG_CARS
UNION ALL SELECT 'STG_CUSTOMERS', COUNT_IF(NOT is_valid_email) FROM AVELTO_RENTALS.SILVER.STG_CUSTOMERS
UNION ALL SELECT 'STG_BRANCH_CATEGORY_AVAILABILITY', COUNT_IF(NOT is_known_branch OR NOT is_known_category OR NOT branch_name_matches) FROM AVELTO_RENTALS.SILVER.STG_BRANCH_CATEGORY_AVAILABILITY;
```

The `CREATE DYNAMIC TABLE` statements themselves are in the 8 files in `silver/`. They were written to files only, not run again.


Append the output to 12-Load Data to Silver/prompt-4 and output and SQLs.md file




