/* =====================================================================================
   RETAILMART GOLD LAYER — 00. SETUP: SCHEMA & DATE DIMENSION
   -----------------------------------------------------------------------------------
   Run this FIRST, before any of the per-table scripts (01_Dim_Stores.sql ... 07_Fact_Returns.sql).
   Requires the full Silver layer to already be loaded (00_Setup..07_Returns from the
   Silver scripts).

   GOLD DESIGN
   -----------
   Star schema, Kimball-style:
     gold.dim_date       -- calendar dimension
     gold.dim_stores      -- conformed dimension, "Unknown" member (-1) for nullable FKs
     gold.dim_products
     gold.dim_customers
     gold.dim_employees   -- "Unknown" member (-1) for nullable FKs
     gold.fact_sales       -- grain: one row per order_id
     gold.fact_inventory    -- grain: one row per inventory snapshot (inventory_id)
     gold.fact_returns       -- grain: one row per return_id

   Every dimension carries a surrogate integer key (<table>_key) generated with
   IDENTITY, plus the original Silver natural key for traceability. Fact tables store
   only surrogate keys (never natural keys) for joins, except where the natural key
   is itself needed for lineage (order_id on fact_returns, so you can trace a return
   back to its order without a join).

   "Unknown" member rows (surrogate key = -1) exist on dim_stores and dim_employees
   because those are the two dimensions that can be legitimately NULL on a fact row
   (silver.returns.store_id, silver.sales.employee_id) — this avoids NULL-able FK
   columns on the fact tables for those two relationships. dim_date FKs are left
   NULLable instead, since an unknown/missing date isn't a meaningful "Unknown date"
   business concept the way an unknown store or employee is.
   ===================================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold') EXEC('CREATE SCHEMA gold');
GO


/* -------------------------------------------------------------------------------------
   dim_date
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('gold.dim_date','U') IS NOT NULL DROP TABLE gold.dim_date;
GO

CREATE TABLE gold.dim_date (
    date_key        INT         NOT NULL PRIMARY KEY,   -- yyyymmdd
    full_date       DATE        NOT NULL,
    day_of_month    TINYINT     NOT NULL,
    day_name        VARCHAR(10) NOT NULL,
    day_of_week_num TINYINT     NOT NULL,               -- 1 = Sunday .. 7 = Saturday
    week_of_year    TINYINT     NOT NULL,
    month_num       TINYINT     NOT NULL,
    month_name      VARCHAR(10) NOT NULL,
    quarter_num     TINYINT     NOT NULL,
    quarter_name    VARCHAR(2)  NOT NULL,
    year_num        SMALLINT    NOT NULL,
    is_weekend      BIT         NOT NULL,
    is_month_start  BIT         NOT NULL,
    is_month_end    BIT         NOT NULL
);
GO

-- Range: Jan 1 of the earliest year seen across every date column in Silver, through
-- Dec 31 of the latest year seen. Covers transactional dates (orders, returns,
-- inventory snapshots) as well as reference dates (DOB, opening/launch/joining dates).
DECLARE @start_date DATE, @end_date DATE;

SELECT @start_date = MIN(d), @end_date = MAX(d)
FROM (
    SELECT opening_date AS d FROM silver.stores
    UNION ALL SELECT launch_date FROM silver.products
    UNION ALL SELECT registration_date FROM silver.customers
    UNION ALL SELECT date_of_birth FROM silver.customers
    UNION ALL SELECT joining_date FROM silver.employees
    UNION ALL SELECT snapshot_date FROM silver.inventory
    UNION ALL SELECT order_date FROM silver.sales
    UNION ALL SELECT return_date FROM silver.returns
) x
WHERE d IS NOT NULL;

SET @start_date = DATEFROMPARTS(YEAR(@start_date), 1, 1);
SET @end_date   = DATEFROMPARTS(YEAR(@end_date), 12, 31);

;WITH seq AS (
    SELECT 0 AS n
    UNION ALL
    SELECT n + 1 FROM seq WHERE n + 1 <= DATEDIFF(DAY, @start_date, @end_date)
),
dates AS (
    SELECT DATEADD(DAY, n, @start_date) AS d FROM seq
)
INSERT INTO gold.dim_date (date_key, full_date, day_of_month, day_name, day_of_week_num,
    week_of_year, month_num, month_name, quarter_num, quarter_name, year_num,
    is_weekend, is_month_start, is_month_end)
SELECT
    CAST(CONVERT(VARCHAR(8), d, 112) AS INT),
    d,
    DAY(d),
    DATENAME(WEEKDAY, d),
    DATEPART(WEEKDAY, d),
    DATEPART(WEEK, d),
    MONTH(d),
    DATENAME(MONTH, d),
    DATEPART(QUARTER, d),
    'Q' + CAST(DATEPART(QUARTER, d) AS VARCHAR(1)),
    YEAR(d),
    CASE WHEN DATEPART(WEEKDAY, d) IN (1, 7) THEN 1 ELSE 0 END,
    CASE WHEN d = DATEFROMPARTS(YEAR(d), MONTH(d), 1) THEN 1 ELSE 0 END,
    CASE WHEN d = EOMONTH(d) THEN 1 ELSE 0 END
FROM dates
OPTION (MAXRECURSION 0);
GO

-- Next: run 01_Dim_Stores.sql, 02_Dim_Products.sql, 03_Dim_Customers.sql,
-- 04_Dim_Employees.sql (dimensions before facts), then 05_Fact_Inventory.sql,
-- 06_Fact_Sales.sql, 07_Fact_Returns.sql, in that order (fact_returns needs
-- fact_sales for the order_id lineage lookup). Finish with 08_Gold_Validation.sql.
