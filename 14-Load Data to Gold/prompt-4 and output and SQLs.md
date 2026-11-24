
```text
How many Ferrari cars do we have in each country?
```

## Output

We have **7 Ferrari cars** in total. All of them are the **Ferrari 488**.

| Country | Ferrari cars |
|---|---|
| United States | 3 |
| Australia | 1 |
| France | 1 |
| Germany | 1 |
| Japan | 1 |
| Canada | 0 |
| United Kingdom | 0 |

The country comes from the branch where each car is located now (`GOLD.DIM_CARS.CURRENT_BRANCH_ID` joined to `GOLD.DIM_BRANCHES`), not from where it was rented or registered. A car counts as a Ferrari if its model name contains "Ferrari"; matching only names that start with "Ferrari" gives the same 7.

## SQL used

### Ferrari cars by country of current branch

```sql
SELECT co.country_name,
       COUNT(c.car_id) AS ferrari_cars,
       LISTAGG(DISTINCT c.model, ', ') WITHIN GROUP (ORDER BY c.model) AS models
FROM AVELTO_RENTALS.GOLD.DIM_COUNTRIES co
LEFT JOIN AVELTO_RENTALS.GOLD.DIM_BRANCHES b ON b.country_id = co.country_id
LEFT JOIN AVELTO_RENTALS.GOLD.DIM_CARS c
  ON c.current_branch_id = b.branch_id AND c.model ILIKE 'Ferrari%'
GROUP BY co.country_name
ORDER BY ferrari_cars DESC, co.country_name;
```

Starting from `DIM_COUNTRIES` with `LEFT JOIN`s keeps countries with no Ferraris in the result, showing 0.

### Check that no Ferrari is missed by the name match

```sql
-- Result: anywhere = 7, prefix = 7
SELECT COUNT_IF(model ILIKE '%ferrari%') AS anywhere,
       COUNT_IF(model ILIKE 'Ferrari%')  AS prefix
FROM AVELTO_RENTALS.GOLD.DIM_CARS;
```
