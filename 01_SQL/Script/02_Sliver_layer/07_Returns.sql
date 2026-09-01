/* =====================================================================================
   RETAILMART SILVER LAYER — 07. RETURNS
   -----------------------------------------------------------------------------------
   Run 00_Setup, 01_Stores.sql, 02_Products.sql, 03_Customers.sql and 06_Sales.sql first.
   DEPENDS ON: silver.sales, silver.customers, silver.products. This is the last table
   in the load order.
   ===================================================================================== */


/* -------------------------------------------------------------------------------------
   STEP 1 — Silver table structure
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('silver.returns','U') IS NOT NULL DROP TABLE silver.returns;
GO

CREATE TABLE silver.returns (
    return_id            INT             NOT NULL PRIMARY KEY,
    order_id                INT             NOT NULL,
    customer_id                 INT             NOT NULL,
    product_id                     INT             NOT NULL,
    store_id                          INT             NULL,
    return_date                          DATE            NULL,
    return_quantity                         INT             NOT NULL,
    return_amount                              DECIMAL(12,2)   NULL,
    return_reason                                 VARCHAR(100)    NULL,
    return_status                                    VARCHAR(20)     NULL,
    refund_amount                                       DECIMAL(12,2)   NULL,
    dq_flag                                                BIT             NOT NULL DEFAULT 0,
    dq_notes                                                  VARCHAR(400)    NULL,
    silver_load_dt                                               DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_returns_order    FOREIGN KEY (order_id)    REFERENCES silver.sales(order_id),
    CONSTRAINT fk_returns_customer FOREIGN KEY (customer_id) REFERENCES silver.customers(customer_id),
    CONSTRAINT fk_returns_product  FOREIGN KEY (product_id)  REFERENCES silver.products(product_id),
    CONSTRAINT ck_returns_qty_nonneg CHECK (return_quantity >= 0),
    CONSTRAINT ck_returns_refund_le_amount CHECK (refund_amount IS NULL OR return_amount IS NULL OR refund_amount <= return_amount)
);
GO


/* -------------------------------------------------------------------------------------
   STEP 2 — Quarantine table structure
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('quarantine.returns','U') IS NOT NULL DROP TABLE quarantine.returns;
GO

SELECT *, CAST(NULL AS VARCHAR(300)) AS reject_reason, CAST(GETDATE() AS DATETIME) AS quarantined_at
INTO quarantine.returns FROM bronze.returns WHERE 1 = 0;
GO


/* -------------------------------------------------------------------------------------
   STEP 3 — Quarantine: reject invalid / duplicate / bad rows
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(return_id AS INT) AS ridn,
        TRY_CAST(order_id AS INT) AS oidn,
        TRY_CAST(customer_id AS INT) AS cidn,
        TRY_CAST(product_id AS INT) AS pidn,
        TRY_CAST(return_quantity AS INT) AS qty_n,
        TRY_CAST(return_amount AS DECIMAL(12,2)) AS ret_amt_n,
        TRY_CAST(refund_amount AS DECIMAL(12,2)) AS refund_n
    FROM bronze.returns
),
staged2 AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY ridn ORDER BY (SELECT NULL)) AS rn
    FROM staged
),
classified AS (
    SELECT *,
        CASE
            WHEN ridn IS NULL THEN 'invalid/unparseable return_id'
            WHEN rn > 1 THEN 'duplicate return_id - extra copy removed'
            WHEN qty_n IS NOT NULL AND qty_n < 0 THEN 'negative return_quantity'
            WHEN refund_n IS NOT NULL AND ret_amt_n IS NOT NULL AND refund_n > ret_amt_n THEN 'refund_amount exceeds return_amount'
            WHEN oidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.sales s WHERE s.order_id = oidn)
                THEN 'orphan order_id - order not found in Silver Sales'
            WHEN cidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.customers c WHERE c.customer_id = cidn)
                THEN 'orphan customer_id - customer not found in Silver'
            WHEN pidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.products p WHERE p.product_id = pidn)
                THEN 'orphan product_id - product not found in Silver'
            ELSE NULL
        END AS reject_reason
    FROM staged2
)
INSERT INTO quarantine.returns
SELECT return_id, order_id, customer_id, product_id, store_id, return_date,
       return_quantity, return_amount, return_reason, return_status, refund_amount,
       reject_reason, GETDATE()
FROM classified WHERE reject_reason IS NOT NULL;
GO


/* -------------------------------------------------------------------------------------
   STEP 4 — Transform: Bronze -> Silver
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(return_id AS INT) AS ridn,
        TRY_CAST(order_id AS INT) AS oidn,
        TRY_CAST(customer_id AS INT) AS cidn,
        TRY_CAST(product_id AS INT) AS pidn,
        TRY_CAST(store_id AS INT) AS sidn,
        TRY_CAST(return_quantity AS INT) AS qty_n,
        TRY_CAST(return_amount AS DECIMAL(12,2)) AS ret_amt_n,
        TRY_CAST(refund_amount AS DECIMAL(12,2)) AS refund_n,
        TRY_CAST(return_date AS DATE) AS ret_dt
    FROM bronze.returns
),
staged2 AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY ridn ORDER BY (SELECT NULL)) AS rn
    FROM staged
),
classified AS (
    SELECT *,
        CASE
            WHEN ridn IS NULL THEN 'reject'
            WHEN rn > 1 THEN 'reject'
            WHEN qty_n IS NOT NULL AND qty_n < 0 THEN 'reject'
            WHEN refund_n IS NOT NULL AND ret_amt_n IS NOT NULL AND refund_n > ret_amt_n THEN 'reject'
            WHEN oidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.sales s WHERE s.order_id = oidn) THEN 'reject'
            WHEN cidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.customers c WHERE c.customer_id = cidn) THEN 'reject'
            WHEN pidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.products p WHERE p.product_id = pidn) THEN 'reject'
            ELSE 'keep'
        END AS decision
    FROM staged2
)
INSERT INTO silver.returns (return_id, order_id, customer_id, product_id, store_id,
    return_date, return_quantity, return_amount, return_reason, return_status,
    refund_amount, dq_flag, dq_notes)
SELECT
    ridn, oidn, cidn, pidn, sidn, ret_dt, qty_n, ret_amt_n,
    dbo.fn_TitleCase(LTRIM(RTRIM(return_reason))),
    CASE WHEN UPPER(LTRIM(RTRIM(return_status))) LIKE 'APPROVED%' THEN 'Approved'
         WHEN UPPER(LTRIM(RTRIM(return_status))) LIKE 'REJECTED%' THEN 'Rejected'
         WHEN UPPER(LTRIM(RTRIM(return_status))) LIKE 'PENDING%'  THEN 'Pending'
         ELSE return_status END,
    refund_n,
    CASE WHEN refund_n IS NULL THEN 1 ELSE 0 END,
    CASE WHEN refund_n IS NULL THEN 'refund_amount missing; excluded from refund KPIs until Finance confirms' ELSE NULL END
FROM classified WHERE decision = 'keep';
GO


/* -------------------------------------------------------------------------------------
   STEP 5 — Table-level validation (assertions; each should return 0)
   ------------------------------------------------------------------------------------- */
-- No duplicate primary keys
SELECT COUNT(*) - COUNT(DISTINCT return_id) AS dup_count FROM silver.returns;

-- Business rules
SELECT COUNT(*) AS negative_quantity      FROM silver.returns WHERE return_quantity < 0;
SELECT COUNT(*) AS refund_gt_return_amount FROM silver.returns WHERE refund_amount > return_amount;

-- Referential integrity
SELECT COUNT(*) AS orphans_vs_sales     FROM silver.returns r WHERE NOT EXISTS (SELECT 1 FROM silver.sales sa WHERE sa.order_id = r.order_id);
SELECT COUNT(*) AS orphans_vs_customers FROM silver.returns r WHERE NOT EXISTS (SELECT 1 FROM silver.customers c WHERE c.customer_id = r.customer_id);
SELECT COUNT(*) AS orphans_vs_products  FROM silver.returns r WHERE NOT EXISTS (SELECT 1 FROM silver.products p WHERE p.product_id = r.product_id);

-- Bronze vs Silver vs Quarantine row counts
SELECT
    (SELECT COUNT(*) FROM bronze.returns)     AS bronze_rows,
    (SELECT COUNT(*) FROM silver.returns)     AS silver_rows,
    (SELECT COUNT(*) FROM quarantine.returns) AS quarantined_rows;
