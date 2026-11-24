-- Gold: one row per reservation, with local amount and USD conversion
-- Joins to DIM_BRANCHES twice: pickup_branch_id and return_branch_id
-- Source: AVELTO_RENTALS.SILVER.STG_BOOKWAVE_RESERVATIONS, STG_CURRENCIES
CREATE SCHEMA IF NOT EXISTS AVELTO_RENTALS.GOLD;

CREATE OR REPLACE DYNAMIC TABLE AVELTO_RENTALS.GOLD.FACT_RESERVATIONS
  TARGET_LAG = '3 minutes'
  WAREHOUSE  = COMPUTE_WH
  REFRESH_MODE = AUTO
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
