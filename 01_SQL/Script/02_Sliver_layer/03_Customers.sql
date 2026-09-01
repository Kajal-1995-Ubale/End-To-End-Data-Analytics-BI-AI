/* =====================================================================================
   RETAILMART SILVER LAYER — 03. CUSTOMERS
   -----------------------------------------------------------------------------------
   Run 00_Setup_Schemas_RefData_Functions.sql first.
   No dependencies on other Silver tables.

   NOTE ON EMAIL: "invalid email format" is FLAGGED (email set to NULL, row kept),
   not rejected — see the treatment decision matrix in 00_Setup for why.
   ===================================================================================== */


/* -------------------------------------------------------------------------------------
   STEP 1 — Silver table structure
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('silver.customers','U') IS NOT NULL DROP TABLE silver.customers;
GO

CREATE TABLE silver.customers (
    customer_id         INT             NOT NULL PRIMARY KEY,
    customer_name       VARCHAR(200)    NOT NULL,
    gender               VARCHAR(10)     NULL,
    date_of_birth        DATE            NULL,
    email                 VARCHAR(200)    NULL,
    phone_number           VARCHAR(15)     NULL,
    city                     VARCHAR(100)    NULL,
    state                     VARCHAR(30)     NULL,
    customer_segment           VARCHAR(50)     NULL,
    registration_date            DATE            NULL,
    customer_status                 VARCHAR(20)     NULL,
    dq_flag                            BIT             NOT NULL DEFAULT 0,
    dq_notes                              VARCHAR(400)    NULL,
    silver_load_dt                           DATETIME        NOT NULL DEFAULT GETDATE()
);
GO


/* -------------------------------------------------------------------------------------
   STEP 2 — Quarantine table structure
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('quarantine.customers','U') IS NOT NULL DROP TABLE quarantine.customers;
GO

SELECT *, CAST(NULL AS VARCHAR(300)) AS reject_reason, CAST(GETDATE() AS DATETIME) AS quarantined_at
INTO quarantine.customers FROM bronze.customers WHERE 1 = 0;
GO


/* -------------------------------------------------------------------------------------
   STEP 3 — Quarantine: reject invalid / duplicate / bad rows
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(customer_id AS INT) AS cidn,
        dbo.fn_ParseFlexDate(registration_date) AS reg_dt      -- bronze format seen: mm/dd/yyyy
    FROM bronze.customers
),
staged2 AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY cidn ORDER BY reg_dt DESC) AS rn
    FROM staged
),
classified AS (
    SELECT *,
        CASE
            WHEN cidn IS NULL THEN 'invalid/unparseable customer_id'
            WHEN rn > 1 THEN 'duplicate customer_id - extra copy removed'
            WHEN reg_dt IS NOT NULL AND reg_dt > CAST('2026-08-29' AS DATE) THEN 'registration_date is future-dated'
            ELSE NULL
        END AS reject_reason
    FROM staged2
)
INSERT INTO quarantine.customers
SELECT customer_id, customer_name, gender, date_of_birth, email, phone_number, city,
       state, customer_segment, registration_date, customer_status, reject_reason, GETDATE()
FROM classified WHERE reject_reason IS NOT NULL;
GO


/* -------------------------------------------------------------------------------------
   STEP 4 — Transform: Bronze -> Silver
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(customer_id AS INT) AS cidn,
        dbo.fn_ParseFlexDate(registration_date) AS reg_dt,
        dbo.fn_ParseFlexDate(date_of_birth) AS dob,             -- bronze format seen: dd-mm-yyyy
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(phone_number,'-',''),' ',''),'(',''),')',''),'+',''),'.','') AS phone_digits_only
    FROM bronze.customers
),
staged2 AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY cidn ORDER BY reg_dt DESC) AS rn
    FROM staged
),
enriched AS (
    SELECT *,
        CASE WHEN email IS NOT NULL AND LTRIM(RTRIM(email)) <> ''
                  AND (email NOT LIKE '%_@__%.__%' OR email LIKE '% %')
             THEN 1 ELSE 0 END AS bad_email,
        CASE WHEN phone_digits_only IS NOT NULL AND phone_digits_only <> '' AND LEN(phone_digits_only) <> 10
             THEN 1 ELSE 0 END AS bad_phone,
        CASE WHEN date_of_birth IS NOT NULL AND dob IS NULL THEN 1 ELSE 0 END AS bad_dob_fmt,
        CASE WHEN dob IS NOT NULL
                  AND (DATEDIFF(YEAR, dob, '2026-08-29') > 100 OR DATEDIFF(YEAR, dob, '2026-08-29') < 10)
             THEN 1 ELSE 0 END AS dob_outlier,
        CASE
            WHEN cidn IS NULL THEN 'reject'
            WHEN rn > 1 THEN 'reject'
            WHEN reg_dt IS NOT NULL AND reg_dt > CAST('2026-08-29' AS DATE) THEN 'reject'
            ELSE 'keep'
        END AS decision
    FROM staged2
)
INSERT INTO silver.customers (customer_id, customer_name, gender, date_of_birth, email,
    phone_number, city, state, customer_segment, registration_date, customer_status,
    dq_flag, dq_notes)
SELECT
    e.cidn,
    dbo.fn_TitleCase(LTRIM(RTRIM(e.customer_name))),
    CASE WHEN UPPER(LTRIM(RTRIM(e.gender))) IN ('M','MALE')   THEN 'Male'
         WHEN UPPER(LTRIM(RTRIM(e.gender))) IN ('F','FEMALE') THEN 'Female'
         WHEN UPPER(LTRIM(RTRIM(e.gender))) = 'OTHER'         THEN 'Other'
         ELSE e.gender END,
    CASE WHEN e.bad_dob_fmt = 1 THEN NULL ELSE e.dob END,
    CASE WHEN e.bad_email = 1 THEN NULL ELSE LOWER(LTRIM(RTRIM(e.email))) END,
    CASE WHEN e.bad_phone = 1 THEN NULL ELSE NULLIF(e.phone_digits_only, '') END,
    NULLIF(LTRIM(RTRIM(e.city)), ''),
    COALESCE(sl.state_name, NULLIF(LTRIM(RTRIM(e.state)), '')),
    e.customer_segment,
    e.reg_dt,
    CASE WHEN UPPER(LTRIM(RTRIM(e.customer_status))) LIKE 'ACTIVE%' THEN 'Active'
         WHEN UPPER(LTRIM(RTRIM(e.customer_status))) LIKE 'INACTIVE%' THEN 'Inactive'
         ELSE LTRIM(RTRIM(e.customer_status)) END,
    CASE WHEN (e.bad_email + e.bad_phone + e.bad_dob_fmt + e.dob_outlier) > 0 THEN 1 ELSE 0 END,
    NULLIF(LTRIM(
        CASE WHEN e.bad_email = 1   THEN 'invalid_email_nulled; ' ELSE '' END +
        CASE WHEN e.bad_phone = 1   THEN 'invalid_phone_nulled; ' ELSE '' END +
        CASE WHEN e.bad_dob_fmt = 1 THEN 'dob_unparseable_nulled; ' ELSE '' END +
        CASE WHEN e.dob_outlier = 1 THEN 'dob_implausible_age_flagged; ' ELSE '' END
    ), '')
FROM enriched e
LEFT JOIN ref.state_lookup sl ON sl.state_abbr = LTRIM(RTRIM(e.state))
WHERE e.decision = 'keep';
GO


/* -------------------------------------------------------------------------------------
   STEP 5 — Table-level validation (assertions; each should return 0)
   ------------------------------------------------------------------------------------- */
-- No duplicate primary keys
SELECT COUNT(*) - COUNT(DISTINCT customer_id) AS dup_count FROM silver.customers;

-- No NULLs in required field
SELECT COUNT(*) AS null_customer_name FROM silver.customers WHERE customer_name IS NULL;

-- Invalid emails should all have been nulled out
SELECT COUNT(*) AS bad_email_remaining
FROM silver.customers
WHERE email IS NOT NULL AND (email NOT LIKE '%_@__%.__%' OR email LIKE '% %');

-- Standardization landed correctly
SELECT DISTINCT gender FROM silver.customers;           -- EXPECTED: Male, Female, Other, NULL only
SELECT DISTINCT customer_status FROM silver.customers;   -- EXPECTED: Active, Inactive, NULL only

-- Bronze vs Silver vs Quarantine row counts
SELECT
    (SELECT COUNT(*) FROM bronze.customers)     AS bronze_rows,
    (SELECT COUNT(*) FROM silver.customers)     AS silver_rows,
    (SELECT COUNT(*) FROM quarantine.customers) AS quarantined_rows;
