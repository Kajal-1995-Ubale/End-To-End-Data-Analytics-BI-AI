/* =====================================================================================
   RETAILMART SILVER LAYER — 02. PRODUCTS
   -----------------------------------------------------------------------------------
   Run 00_Setup_Schemas_RefData_Functions.sql first.
   No dependencies on other Silver tables.
   ===================================================================================== */


/* -------------------------------------------------------------------------------------
   STEP 1 — Silver table structure
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('silver.products','U') IS NOT NULL DROP TABLE silver.products;
GO

CREATE TABLE silver.products (
    product_id      INT             NOT NULL PRIMARY KEY,
    product_name    VARCHAR(200)    NOT NULL,
    category        VARCHAR(100)    NULL,
    subcategory     VARCHAR(100)    NULL,
    brand           VARCHAR(100)    NULL,
    unit_cost       DECIMAL(12,2)   NULL,
    selling_price   DECIMAL(12,2)   NULL,
    supplier_id     VARCHAR(50)     NULL,
    product_status  VARCHAR(20)     NULL,
    launch_date     DATE            NULL,
    dq_flag         BIT             NOT NULL DEFAULT 0,
    dq_notes        VARCHAR(400)    NULL,
    silver_load_dt  DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT ck_products_price CHECK (selling_price IS NULL OR selling_price >= 0),
    CONSTRAINT ck_products_margin CHECK (unit_cost IS NULL OR selling_price IS NULL OR unit_cost <= selling_price)
);
GO


/* -------------------------------------------------------------------------------------
   STEP 2 — Quarantine table structure
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('quarantine.products','U') IS NOT NULL DROP TABLE quarantine.products;
GO

SELECT *, CAST(NULL AS VARCHAR(300)) AS reject_reason, CAST(GETDATE() AS DATETIME) AS quarantined_at
INTO quarantine.products FROM bronze.products WHERE 1 = 0;
GO


/* -------------------------------------------------------------------------------------
   STEP 3 — Quarantine: reject invalid / duplicate / bad rows
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(product_id AS INT)          AS pidn,
        TRY_CAST(unit_cost AS DECIMAL(12,2))  AS cost_n,
        TRY_CAST(selling_price AS DECIMAL(12,2)) AS price_n,
        ROW_NUMBER() OVER (PARTITION BY TRY_CAST(product_id AS INT)
                            ORDER BY TRY_CAST(launch_date AS DATE) DESC) AS rn
    FROM bronze.products
),
classified AS (
    SELECT *,
        CASE
            WHEN pidn IS NULL THEN 'invalid/unparseable product_id'
            WHEN rn > 1 THEN 'duplicate product_id - extra copy removed'
            WHEN cost_n IS NOT NULL AND price_n IS NOT NULL AND cost_n > price_n THEN 'unit_cost > selling_price'
            WHEN price_n IS NOT NULL AND price_n < 0 THEN 'negative selling_price'
            ELSE NULL
        END AS reject_reason
    FROM staged
)
INSERT INTO quarantine.products
SELECT product_id, product_name, category, subcategory, brand, unit_cost, selling_price,
       supplier_id, product_status, launch_date, reject_reason, GETDATE()
FROM classified WHERE reject_reason IS NOT NULL;
GO


/* -------------------------------------------------------------------------------------
   STEP 4 — Transform: Bronze -> Silver
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(product_id AS INT)          AS pidn,
        TRY_CAST(unit_cost AS DECIMAL(12,2))  AS cost_n,
        TRY_CAST(selling_price AS DECIMAL(12,2)) AS price_n,
        ROW_NUMBER() OVER (PARTITION BY TRY_CAST(product_id AS INT)
                            ORDER BY TRY_CAST(launch_date AS DATE) DESC) AS rn
    FROM bronze.products
),
classified AS (
    SELECT *,
        CASE
            WHEN pidn IS NULL THEN 'reject'
            WHEN rn > 1 THEN 'reject'
            WHEN cost_n IS NOT NULL AND price_n IS NOT NULL AND cost_n > price_n THEN 'reject'
            WHEN price_n IS NOT NULL AND price_n < 0 THEN 'reject'
            ELSE 'keep'
        END AS decision
    FROM staged
)
INSERT INTO silver.products (product_id, product_name, category, subcategory, brand,
    unit_cost, selling_price, supplier_id, product_status, launch_date, dq_flag, dq_notes)
SELECT
    pidn,
    dbo.fn_TitleCase(LTRIM(RTRIM(product_name))),
    NULLIF(LTRIM(RTRIM(category)), ''),
    subcategory,
    COALESCE(NULLIF(LTRIM(RTRIM(brand)), ''), 'Unbranded'),
    cost_n,
    price_n,
    supplier_id,
    CASE WHEN UPPER(LTRIM(RTRIM(product_status))) LIKE 'ACTIVE%' THEN 'Active'
         WHEN UPPER(LTRIM(RTRIM(product_status))) LIKE 'INACTIVE%' THEN 'Inactive'
         ELSE LTRIM(RTRIM(product_status)) END,
    TRY_CAST(launch_date AS DATE),
    CASE WHEN category IS NULL OR LTRIM(RTRIM(category)) = '' THEN 1 ELSE 0 END,
    CASE WHEN category IS NULL OR LTRIM(RTRIM(category)) = '' THEN 'category missing, excluded from category KPIs until corrected' ELSE NULL END
FROM classified WHERE decision = 'keep';
GO


/* -------------------------------------------------------------------------------------
   STEP 5 — Table-level validation (assertions; each should return 0)
   ------------------------------------------------------------------------------------- */
-- No duplicate primary keys
SELECT COUNT(*) - COUNT(DISTINCT product_id) AS dup_count FROM silver.products;

-- No NULLs in required field
SELECT COUNT(*) AS null_product_name FROM silver.products WHERE product_name IS NULL;

-- Business rules: cost <= price, non-negative price
SELECT COUNT(*) AS cost_gt_price FROM silver.products WHERE unit_cost > selling_price;
SELECT COUNT(*) AS negative_price FROM silver.products WHERE selling_price < 0;

-- Bronze vs Silver vs Quarantine row counts
SELECT
    (SELECT COUNT(*) FROM bronze.products)     AS bronze_rows,
    (SELECT COUNT(*) FROM silver.products)     AS silver_rows,
    (SELECT COUNT(*) FROM quarantine.products) AS quarantined_rows;
