


Prompt 3 (land Bronze, explicitly, no transformation)
-----------------------------------------------------
Load the seven FleetOps CSVs (branches, cars, car_categories, countries,
currencies, customers, branch_category_availability) into seven Bronze
tables, one per file, named bronze_branches, bronze_cars,
bronze_car_categories, bronze_countries, bronze_currencies,
bronze_customers, and bronze_branch_category_availability. Keep every
column name and value exactly as it appears in the source file, no
cleaning, no renaming, no type changes beyond what's needed to load it.
Then load reservations_export.json into a single table called
bronze_bookwave_reservations_raw, with the entire nested JSON structure
kept intact in one VARIANT column, one row per top-level reservation
record. Don't flatten or parse anything inside the JSON yet, this step is
only landing the data exactly as it arrived.
Create a new database AVELTO_RENTALS and schema BRONZE for loading.
