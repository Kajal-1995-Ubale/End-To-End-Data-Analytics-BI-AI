/* =====================================================================================
   RETAILMART GOLD LAYER — 04. DIM_EMPLOYEES
   -----------------------------------------------------------------------------------
   Run 00_Setup_Gold_Schema_And_DimDate.sql and 01_Dim_Stores.sql first.
   Source: silver.employees. Includes an "Unknown" member (employee_key = -1) because
   silver.sales.employee_id is nullable (a sale can be an orphan-employee record that
   was flagged and nulled rather than rejected) — fact_sales needs an employee_key to
   point to in that case rather than leaving the FK column NULL.
   ===================================================================================== */

IF OBJECT_ID('gold.dim_employees','U') IS NOT NULL DROP TABLE gold.dim_employees;
GO

CREATE TABLE gold.dim_employees (
    employee_key        INT             NOT NULL PRIMARY KEY,
    employee_id          INT             NULL,          -- NULL only for the Unknown member
    employee_name          VARCHAR(200)    NOT NULL,
    department                VARCHAR(100)    NULL,
    job_title                   VARCHAR(100)    NULL,
    store_key                     INT             NULL,   -- FK to gold.dim_stores
    manager_id                       VARCHAR(50)     NULL,
    joining_date                        DATE            NULL,
    tenure_years                           INT             NULL,   -- as of load date
    employment_status                         VARCHAR(20)     NULL,
    city                                         VARCHAR(100)    NULL,
    salary                                          DECIMAL(12,2)   NULL,
    gold_load_dt                                       DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_dim_employees_store FOREIGN KEY (store_key) REFERENCES gold.dim_stores(store_key)
);
GO

-- Unknown member (employee_key is a plain INT PK here, not IDENTITY, so -1 inserts directly)
INSERT INTO gold.dim_employees (employee_key, employee_id, employee_name, department,
    job_title, store_key, manager_id, joining_date, tenure_years, employment_status,
    city, salary)
VALUES (-1, NULL, 'Unknown Employee', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
GO

-- employee_key = employee_id 1:1 (see dim_stores for the rationale).
INSERT INTO gold.dim_employees (employee_key, employee_id, employee_name, department,
    job_title, store_key, manager_id, joining_date, tenure_years, employment_status,
    city, salary)
SELECT
    e.employee_id, e.employee_id, e.employee_name, e.department, e.job_title,
    ISNULL(e.store_id, -1),
    e.manager_id, e.joining_date,
    CASE WHEN e.joining_date IS NULL THEN NULL ELSE DATEDIFF(YEAR, e.joining_date, GETDATE())
         - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, e.joining_date, GETDATE()), e.joining_date) > GETDATE()
                THEN 1 ELSE 0 END END,
    e.employment_status, e.city, e.salary
FROM silver.employees e;
GO


/* -------------------------------------------------------------------------------------
   Validation
   ------------------------------------------------------------------------------------- */
-- No duplicate keys
SELECT COUNT(*) - COUNT(DISTINCT employee_key) AS dup_count FROM gold.dim_employees;

-- Referential integrity to dim_stores
SELECT COUNT(*) AS orphans
FROM gold.dim_employees e
WHERE e.store_key IS NOT NULL AND NOT EXISTS (SELECT 1 FROM gold.dim_stores s WHERE s.store_key = e.store_key);

-- Row counts (Gold should be Silver row count + 1 for the Unknown member)
SELECT
    (SELECT COUNT(*) FROM silver.employees)   AS silver_rows,
    (SELECT COUNT(*) FROM gold.dim_employees) AS gold_rows;
