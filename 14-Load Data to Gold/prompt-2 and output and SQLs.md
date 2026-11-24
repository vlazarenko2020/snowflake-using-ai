
```text
Create a markdown document which fully documents the gold layer star schema. 
 I want a technical documentation for 
  - the table attributes 
  - data types 
  - and relationships. 
 And also give business descriptions so we have a full documentation. 
 ```

## Output

The Gold layer documentation was saved as `14-Load Data to Gold/Gold layer star schema documentation.md` and later moved to `gold/Gold layer star schema documentation.md`. The data types come from Snowflake itself, and the value ranges and counts in it come from queries run against the tables on 2026-11-24.

What's in it:
1. **Purpose:** the business questions the model answers.
2. **Overview:** each table's type, grain, row count and key, plus a Mermaid diagram showing every column and how the tables relate.
3. **Relationships:** every join with its business meaning, including how `DIM_BRANCHES` is used twice (pickup and return), with an example query.
4. **Table reference:** one section per table with the column order, data type, key role, a business description and technical notes (source field, conversions, value ranges, personal-data marking).
5. **Lineage and refresh:** stage → Bronze → Silver → Gold, which Silver tables feed each Gold table, freshness, and refresh modes.
6. **Data quality:** the checks that passed on 2026-11-24.
7. **Known limitations.**
8. **Example queries.**

**Points worth knowing:**
- **Keys are logical only.** Snowflake reports every column as nullable, and dynamic tables don't declare primary or foreign keys. The document says so, and points to the checks that guarantee the keys hold.
- **Payments after the rental start:** on 132 reservations the payment date falls after the rental started. That looks like normal payment during the rental, but it's worth confirming with the business.
- **Exchange rates:** `TOTAL_AMOUNT_USD` is converted at today's rate, not the rate on the payment date, and is recalculated if a rate changes.

**Checks on the document itself:** the three example queries compile, and the 7 branch/category combinations that aren't offered are all Convertible, as the document states.

The diagram shows in VS Code's Markdown preview (Ctrl+Shift+V) only if a Mermaid extension is installed.

## SQL used

### Column names, data types and nullability

```sql
SELECT table_name, ordinal_position, column_name, data_type,
       CASE WHEN data_type='NUMBER' THEN data_type||'('||numeric_precision||','||numeric_scale||')'
            WHEN data_type='TEXT' THEN 'VARCHAR('||character_maximum_length||')' ELSE data_type END AS full_type,
       is_nullable
FROM AVELTO_RENTALS.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'GOLD'
ORDER BY table_name, ordinal_position;
```

### Value profiles for the business descriptions

```sql
SELECT 'booked_on range' k, MIN(booked_on)||' to '||MAX(booked_on) v FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'rental_start range', MIN(rental_start)||' to '||MAX(rental_start) FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'rental_days min/avg/max', MIN(rental_days)||' / '||ROUND(AVG(rental_days),1)||' / '||MAX(rental_days) FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'payment_method values', LISTAGG(DISTINCT payment_method, ', ') FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'amount_local min/max', MIN(amount_local)||' / '||MAX(amount_local) FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'total_amount_usd sum', SUM(total_amount_usd)::STRING FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'payment before booking', COUNT_IF(payment_date < booked_on)::STRING FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'payment after rental start', COUNT_IF(payment_date > rental_start)::STRING FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'regions', LISTAGG(DISTINCT region, ', ') FROM AVELTO_RENTALS.GOLD.DIM_COUNTRIES
UNION ALL SELECT 'branch capacity min/max', MIN(capacity)||' / '||MAX(capacity) FROM AVELTO_RENTALS.GOLD.DIM_BRANCHES
UNION ALL SELECT 'model_year range', MIN(model_year)||' to '||MAX(model_year) FROM AVELTO_RENTALS.GOLD.DIM_CARS
UNION ALL SELECT 'dob range', MIN(date_of_birth)||' to '||MAX(date_of_birth) FROM AVELTO_RENTALS.GOLD.DIM_CUSTOMERS
UNION ALL SELECT 'categories offered', COUNT_IF(is_offered)||' of '||COUNT(*) FROM AVELTO_RENTALS.GOLD.BRIDGE_BRANCH_CATEGORY_AVAILABILITY
UNION ALL SELECT 'reservations: car category not offered at pickup', COUNT(*)::STRING FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS f JOIN AVELTO_RENTALS.GOLD.DIM_CARS c ON c.car_id=f.car_id JOIN AVELTO_RENTALS.GOLD.BRIDGE_BRANCH_CATEGORY_AVAILABILITY b ON b.branch_id=f.pickup_branch_id AND b.category_id=c.category_id WHERE NOT b.is_offered
UNION ALL SELECT 'currency <> pickup branch currency', COUNT(*)::STRING FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS f JOIN AVELTO_RENTALS.GOLD.DIM_BRANCHES b ON b.branch_id=f.pickup_branch_id WHERE b.currency_code<>f.currency_code
UNION ALL SELECT 'customers with reservations', COUNT(DISTINCT customer_id)::STRING FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
UNION ALL SELECT 'cars with reservations', COUNT(DISTINCT car_id)::STRING FROM AVELTO_RENTALS.GOLD.FACT_RESERVATIONS;
```

| Profile | Result |
|---|---|
| booked_on range | 2023-08-11 to 2025-08-10 |
| rental_start range | 2023-08-12 to 2025-09-05 |
| rental_days min / avg / max | 1 / 7.4 / 14 |
| payment_method values | PayPal, Bank Transfer, Debit Card, Credit Card |
| amount_local min / max | 31.50 / 417,910.00 |
| total_amount_usd sum | 1,514,210.12 |
| payment before booking | 0 |
| payment after rental start | 132 |
| regions | Asia, North America, Europe, Oceania |
| branch capacity min / max | 21 / 96 |
| model_year range | 2015 to 2026 |
| date_of_birth range | 1949-08-22 to 2004-07-03 |
| categories offered | 53 of 60 |
| reservations whose car category is not offered at pickup | 0 |
| reservation currency ≠ pickup branch currency | 0 |
| customers with reservations | 495 |
| cars with reservations | 200 |

### Checks on the document's claims

```sql
-- Not-offered branch/category combinations (result: Convertible, 7)
SELECT category_name, COUNT(*)
FROM AVELTO_RENTALS.GOLD.BRIDGE_BRANCH_CATEGORY_AVAILABILITY
WHERE NOT is_offered
GROUP BY 1;
```

The three example queries in section 8 of the documentation were compile-checked (`only_compile`) and all compiled successfully.


Append the output to 14-Load Data to Gold/prompt-2 and output and SQLs.md file


