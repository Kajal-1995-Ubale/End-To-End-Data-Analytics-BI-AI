/* =====================================================================================
   RETAILMART SILVER LAYER — 01. STORES
   -----------------------------------------------------------------------------------
   Run 00_Setup_Schemas_RefData_Functions.sql first.
   No dependencies on other Silver tables — stores is the first table loaded.
   ===================================================================================== */


/* -------------------------------------------------------------------------------------
   STEP 1 — Silver table structure
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('silver.stores','U') IS NOT NULL DROP TABLE silver.stores;
GO

CREATE TABLE silver.stores (
    store_id        INT             NOT NULL PRIMARY KEY,
    store_name      VARCHAR(200)    NOT NULL,
    city            VARCHAR(100)    NULL,
    state           VARCHAR(30)     NULL,
    region          VARCHAR(50)     NULL,
    store_type      VARCHAR(50)     NULL,
    opening_date    DATE            NULL,
    manager_id      VARCHAR(50)     NULL,
    store_status    VARCHAR(20)     NULL,
    square_feet     INT             NULL,
    dq_flag         BIT             NOT NULL DEFAULT 0,
    dq_notes        VARCHAR(400)    NULL,
    silver_load_dt  DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT ck_stores_sqft CHECK (square_feet IS NULL OR square_feet > 0)
);
GO


/* -------------------------------------------------------------------------------------
   STEP 2 — Quarantine table structure
   Built directly off the Bronze schema shape, plus audit columns.
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('quarantine.stores','U') IS NOT NULL DROP TABLE quarantine.stores;
GO

SELECT *, CAST(NULL AS VARCHAR(300)) AS reject_reason, CAST(GETDATE() AS DATETIME) AS quarantined_at
INTO quarantine.stores FROM bronze.stores WHERE 1 = 0;
GO


/* -------------------------------------------------------------------------------------
   STEP 3 — Quarantine: reject invalid / duplicate / bad rows
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(store_id AS INT)                                             AS sidn,
        dbo.fn_ParseFlexDate(opening_date)                                    AS open_dt,   -- bronze format seen: mm-dd-yyyy
        TRY_CAST(square_feet AS INT)                                          AS sqft_n,
        ROW_NUMBER() OVER (PARTITION BY TRY_CAST(store_id AS INT)
                            ORDER BY dbo.fn_ParseFlexDate(opening_date) DESC)  AS rn
    FROM bronze.stores
),
classified AS (
    SELECT *,
        CASE
            WHEN sidn IS NULL THEN 'invalid/unparseable store_id'
            WHEN rn > 1 THEN 'duplicate store_id - extra copy removed'
            WHEN sqft_n IS NOT NULL AND sqft_n <= 0 THEN 'square_feet non-positive'
            ELSE NULL
        END AS reject_reason
    FROM staged
)
INSERT INTO quarantine.stores
SELECT store_id, store_name, city, state, region, store_type, opening_date, manager_id,
       store_status, square_feet, reject_reason, GETDATE()
FROM classified WHERE reject_reason IS NOT NULL;
GO


/* -------------------------------------------------------------------------------------
   STEP 4 — Transform: Bronze -> Silver
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(store_id AS INT)                                             AS sidn,
        dbo.fn_ParseFlexDate(opening_date)                                    AS open_dt,
        TRY_CAST(square_feet AS INT)                                          AS sqft_n,
        ROW_NUMBER() OVER (PARTITION BY TRY_CAST(store_id AS INT)
                            ORDER BY dbo.fn_ParseFlexDate(opening_date) DESC)  AS rn
    FROM bronze.stores
),
classified AS (
    SELECT *,
        CASE WHEN opening_date IS NOT NULL AND open_dt IS NULL THEN 1 ELSE 0 END AS bad_date_fmt,
        CASE
            WHEN sidn IS NULL THEN 'reject'
            WHEN rn > 1 THEN 'reject'
            WHEN sqft_n IS NOT NULL AND sqft_n <= 0 THEN 'reject'
            ELSE 'keep'
        END AS decision
    FROM staged
)
INSERT INTO silver.stores (store_id, store_name, city, state, region, store_type,
    opening_date, manager_id, store_status, square_feet, dq_flag, dq_notes)
SELECT
    sidn,
    dbo.fn_TitleCase(LTRIM(RTRIM(store_name))),
    LTRIM(RTRIM(city)),
    COALESCE(sl.state_name, NULLIF(LTRIM(RTRIM(c.state)), '')),
    region, store_type,
    open_dt,
    NULLIF(LTRIM(RTRIM(manager_id)), ''),
    CASE WHEN UPPER(LTRIM(RTRIM(store_status))) LIKE 'ACTIVE%'     THEN 'Active'
         WHEN UPPER(LTRIM(RTRIM(store_status))) LIKE 'CLOSED%'     THEN 'Closed'
         WHEN UPPER(LTRIM(RTRIM(store_status))) LIKE 'RENOVATING%' THEN 'Renovating'
         ELSE LTRIM(RTRIM(store_status)) END,
    sqft_n,
    CASE WHEN bad_date_fmt = 1 THEN 1 ELSE 0 END,
    CASE WHEN bad_date_fmt = 1 THEN 'opening_date unparseable, set NULL' ELSE NULL END
FROM classified c
LEFT JOIN ref.state_lookup sl ON sl.state_abbr = LTRIM(RTRIM(c.state))
WHERE decision = 'keep';
GO


/* -------------------------------------------------------------------------------------
   STEP 5 — Table-level validation (assertions; each should return 0)
   ------------------------------------------------------------------------------------- */
-- No duplicate primary keys
SELECT COUNT(*) - COUNT(DISTINCT store_id) AS dup_count FROM silver.stores;

-- Business rule: square_feet must be positive when present
SELECT COUNT(*) AS bad_sqft_count FROM silver.stores WHERE square_feet IS NOT NULL AND square_feet <= 0;

-- Standardization landed correctly
SELECT DISTINCT store_status FROM silver.stores;  -- EXPECTED: Active, Closed, Renovating, NULL only

-- Bronze vs Silver vs Quarantine row counts
SELECT
    (SELECT COUNT(*) FROM bronze.stores)     AS bronze_rows,
    (SELECT COUNT(*) FROM silver.stores)     AS silver_rows,
    (SELECT COUNT(*) FROM quarantine.stores) AS quarantined_rows;
