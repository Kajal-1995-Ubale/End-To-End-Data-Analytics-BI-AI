/* =====================================================================================
   RETAILMART GOLD LAYER — 03. DIM_CUSTOMERS
   -----------------------------------------------------------------------------------
   Run 00_Setup_Gold_Schema_And_DimDate.sql first.
   Source: silver.customers. No Unknown member needed — customer_id is NOT NULL on
   every Silver fact table that references it (sales, returns).
   ===================================================================================== */

IF OBJECT_ID('gold.dim_customers','U') IS NOT NULL DROP TABLE gold.dim_customers;
GO

CREATE TABLE gold.dim_customers (
    customer_key       INT             NOT NULL PRIMARY KEY,
    customer_id        INT             NOT NULL,
    customer_name      VARCHAR(200)    NOT NULL,
    gender              VARCHAR(10)     NULL,
    date_of_birth        DATE            NULL,
    age_years              INT             NULL,   -- as of load date; NULL if DOB unknown
    age_band                 VARCHAR(10)     NULL,   -- Under 18 / 18-24 / 25-34 / 35-44 / 45-54 / 55-64 / 65+
    email                       VARCHAR(200)    NULL,
    phone_number                  VARCHAR(15)     NULL,
    city                             VARCHAR(100)    NULL,
    state                             VARCHAR(30)     NULL,
    customer_segment                    VARCHAR(50)     NULL,
    registration_date                      DATE            NULL,
    customer_status                           VARCHAR(20)     NULL,
    gold_load_dt                                 DATETIME        NOT NULL DEFAULT GETDATE()
);
GO

-- customer_key = customer_id 1:1 (see dim_stores for the rationale).
INSERT INTO gold.dim_customers (customer_key, customer_id, customer_name, gender,
    date_of_birth, age_years, age_band, email, phone_number, city, state,
    customer_segment, registration_date, customer_status)
SELECT
    customer_id, customer_id, customer_name, gender, date_of_birth,
    CASE WHEN date_of_birth IS NULL THEN NULL ELSE DATEDIFF(YEAR, date_of_birth, GETDATE())
         - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, date_of_birth, GETDATE()), date_of_birth) > GETDATE()
                THEN 1 ELSE 0 END END AS age_years,
    CASE
        WHEN date_of_birth IS NULL THEN NULL
        WHEN DATEDIFF(YEAR, date_of_birth, GETDATE()) < 18 THEN 'Under 18'
        WHEN DATEDIFF(YEAR, date_of_birth, GETDATE()) BETWEEN 18 AND 24 THEN '18-24'
        WHEN DATEDIFF(YEAR, date_of_birth, GETDATE()) BETWEEN 25 AND 34 THEN '25-34'
        WHEN DATEDIFF(YEAR, date_of_birth, GETDATE()) BETWEEN 35 AND 44 THEN '35-44'
        WHEN DATEDIFF(YEAR, date_of_birth, GETDATE()) BETWEEN 45 AND 54 THEN '45-54'
        WHEN DATEDIFF(YEAR, date_of_birth, GETDATE()) BETWEEN 55 AND 64 THEN '55-64'
        ELSE '65+'
    END,
    email, phone_number, city, state, customer_segment, registration_date, customer_status
FROM silver.customers;
GO


/* -------------------------------------------------------------------------------------
   Validation
   ------------------------------------------------------------------------------------- */
-- No duplicate keys
SELECT COUNT(*) - COUNT(DISTINCT customer_key) AS dup_count FROM gold.dim_customers;

-- Row counts (Gold should equal Silver — no Unknown member on this dimension)
SELECT
    (SELECT COUNT(*) FROM silver.customers)   AS silver_rows,
    (SELECT COUNT(*) FROM gold.dim_customers) AS gold_rows;

-- Age band sanity check
SELECT age_band, COUNT(*) AS customer_count FROM gold.dim_customers GROUP BY age_band ORDER BY age_band;
