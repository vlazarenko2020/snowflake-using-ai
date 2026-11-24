-- Silver: one row per BookWave reservation.
-- Flattens the raw JSON, pulls the first paymentDetails element up into columns,
-- and converts DD/MM/YYYY strings to DATE.
-- Source: AVELTO_RENTALS.BRONZE.BRONZE_BOOKWAVE_RESERVATIONS_RAW (VARIANT column RAW)
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
