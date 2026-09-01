/* =====================================================================================
   RETAILMART SILVER LAYER — 04. employee
   -----------------------------------------------------------------------------------
   Run 00_Setup_Schemas_RefData_Functions.sql and 01_Stores.sql first.
   DEPENDS ON: silver.stores (FK + orphan-check on store_id).
   ===================================================================================== */


/* -------------------------------------------------------------------------------------
   STEP 1 — Silver table structure
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('silver.employee','U') IS NOT NULL DROP TABLE silver.employee;
GO

CREATE TABLE silver.employee (
    employee_id         INT             NOT NULL PRIMARY KEY,
    employee_name         VARCHAR(200)    NOT NULL,
    department              VARCHAR(100)    NULL,
    job_title                 VARCHAR(100)    NULL,
    store_id                    INT             NULL,
    manager_id                    VARCHAR(50)     NULL,
    joining_date                     DATE            NULL,
    employment_status                   VARCHAR(20)     NULL,
    city                                   VARCHAR(100)    NULL,
    salary                                    DECIMAL(12,2)   NULL,
    dq_flag                                      BIT             NOT NULL DEFAULT 0,
    dq_notes                                        VARCHAR(400)    NULL,
    silver_load_dt                                     DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_employee_store FOREIGN KEY (store_id) REFERENCES silver.stores(store_id),
    CONSTRAINT ck_employee_salary CHECK (salary IS NULL OR salary >= 0)
);
GO


/* -------------------------------------------------------------------------------------
   STEP 2 — Quarantine table structure
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('quarantine.employee','U') IS NOT NULL DROP TABLE quarantine.employee;
GO

SELECT *, CAST(NULL AS VARCHAR(300)) AS reject_reason, CAST(GETDATE() AS DATETIME) AS quarantined_at
INTO quarantine.employee FROM bronze.employee WHERE 1 = 0;
GO


/* -------------------------------------------------------------------------------------
   STEP 3 — Quarantine: reject invalid / duplicate / bad rows
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(employee_id AS INT) AS eidn,
        TRY_CAST(store_id AS INT) AS sidn,
        TRY_CAST(salary AS DECIMAL(12,2)) AS salary_n,
        dbo.fn_ParseFlexDate(joining_date) AS join_dt     -- bronze format seen: dd/mm/yyyy
    FROM bronze.employee
),
staged2 AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY eidn ORDER BY join_dt DESC) AS rn
    FROM staged
),
classified AS (
    SELECT *,
        CASE
            WHEN eidn IS NULL THEN 'invalid/unparseable employee_id'
            WHEN rn > 1 THEN 'duplicate employee_id - extra copy removed'
            WHEN salary_n IS NOT NULL AND salary_n < 0 THEN 'negative salary'
            WHEN sidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.stores st WHERE st.store_id = sidn)
                THEN 'orphan store_id - store not found in Silver'
            ELSE NULL
        END AS reject_reason
    FROM staged2
)
INSERT INTO quarantine.employee
SELECT employee_id, employee_name, department, job_title, store_id, manager_id,
       joining_date, employment_status, city, salary, reject_reason, GETDATE()
FROM classified WHERE reject_reason IS NOT NULL;
GO


/* -------------------------------------------------------------------------------------
   STEP 4 — Transform: Bronze -> Silver
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(employee_id AS INT) AS eidn,
        TRY_CAST(store_id AS INT) AS sidn,
        TRY_CAST(salary AS DECIMAL(12,2)) AS salary_n,
        dbo.fn_ParseFlexDate(joining_date) AS join_dt
    FROM bronze.employee
),
staged2 AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY eidn ORDER BY join_dt DESC) AS rn
    FROM staged
),
bounds AS (
    SELECT AVG(salary_n) + 4 * STDEV(salary_n) AS upper_bound
    FROM (SELECT TRY_CAST(salary AS DECIMAL(12,2)) AS salary_n FROM bronze.employee) x
    WHERE salary_n > 0
),
enriched AS (
    SELECT s.*,
        CASE WHEN s.joining_date IS NOT NULL AND s.join_dt IS NULL THEN 1 ELSE 0 END AS bad_join_fmt,
        CASE WHEN s.salary_n IS NOT NULL AND s.salary_n > b.upper_bound THEN 1 ELSE 0 END AS salary_outlier,
        CASE
            WHEN s.eidn IS NULL THEN 'reject'
            WHEN s.rn > 1 THEN 'reject'
            WHEN s.salary_n IS NOT NULL AND s.salary_n < 0 THEN 'reject'
            WHEN s.sidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.stores st WHERE st.store_id = s.sidn) THEN 'reject'
            ELSE 'keep'
        END AS decision
    FROM staged2 s CROSS JOIN bounds b
)
INSERT INTO silver.employee (employee_id, employee_name, department, job_title, store_id,
    manager_id, joining_date, employment_status, city, salary, dq_flag, dq_notes)
SELECT
    eidn,
    dbo.fn_TitleCase(LTRIM(RTRIM(employee_name))),
    COALESCE(NULLIF(LTRIM(RTRIM(department)), ''), 'Unassigned'),
    job_title,
    sidn,
    NULLIF(LTRIM(RTRIM(manager_id)), ''),
    CASE WHEN bad_join_fmt = 1 THEN NULL ELSE join_dt END,
    CASE WHEN UPPER(LTRIM(RTRIM(REPLACE(employment_status,'.','')))) LIKE 'ACTIVE%'     THEN 'Active'
         WHEN UPPER(LTRIM(RTRIM(REPLACE(employment_status,'.','')))) LIKE 'INACTIVE%'   THEN 'Inactive'
         WHEN UPPER(LTRIM(RTRIM(REPLACE(employment_status,'.','')))) LIKE 'TERMINATED%' THEN 'Terminated'
         WHEN UPPER(LTRIM(RTRIM(REPLACE(employment_status,'.','')))) LIKE 'ON LEAVE%'   THEN 'On Leave'
         ELSE employment_status END,
    NULLIF(LTRIM(RTRIM(city)), ''),
    salary_n,
    CASE WHEN (bad_join_fmt + salary_outlier + CASE WHEN salary_n IS NULL THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END,
    NULLIF(LTRIM(
        CASE WHEN salary_n IS NULL   THEN 'salary_missing_excluded_from_payroll_agg; ' ELSE '' END +
        CASE WHEN salary_outlier = 1 THEN 'salary_outlier_flagged_for_hr_review; ' ELSE '' END +
        CASE WHEN bad_join_fmt = 1   THEN 'joining_date_unparseable_nulled; ' ELSE '' END
    ), '')
FROM enriched WHERE decision = 'keep';
GO


/* -------------------------------------------------------------------------------------
   STEP 5 — Table-level validation (assertions; each should return 0)
   ------------------------------------------------------------------------------------- */
-- No duplicate primary keys
SELECT COUNT(*) - COUNT(DISTINCT employee_id) AS dup_count FROM silver.employee;

-- Referential integrity: employee -> stores
SELECT COUNT(*) AS orphans
FROM silver.employee e
WHERE e.store_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.stores s WHERE s.store_id = e.store_id);

-- Business rule: salary non-negative
SELECT COUNT(*) AS negative_salary FROM silver.employee WHERE salary < 0;

-- Bronze vs Silver vs Quarantine row counts
SELECT
    (SELECT COUNT(*) FROM bronze.employee)     AS bronze_rows,
    (SELECT COUNT(*) FROM silver.employee)     AS silver_rows,
    (SELECT COUNT(*) FROM quarantine.employee) AS quarantined_rows;
