/* =====================================================================================
   RETAILMART SILVER LAYER — 06. SALES
   -----------------------------------------------------------------------------------
   Run 00_Setup, 01_Stores.sql, 02_Products.sql, 03_Customers.sql and 04_Employees.sql first.
   DEPENDS ON: silver.customers, silver.products, silver.stores, silver.employees.
   employee_id is a SOFT dependency: an orphan employee_id nulls the column and flags
   the row (FLAG), it does not reject the sale — see the treatment decision matrix.
   ===================================================================================== */


/* -------------------------------------------------------------------------------------
   STEP 1 — Silver table structure
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('silver.sales','U') IS NOT NULL DROP TABLE silver.sales;
GO

CREATE TABLE silver.sales (
    order_id              INT             NOT NULL PRIMARY KEY,
    customer_id             INT             NOT NULL,
    product_id                 INT             NOT NULL,
    store_id                      INT             NOT NULL,
    employee_id                      INT             NULL,
    order_date                          DATE            NULL,
    quantity                               INT             NOT NULL,
    unit_price                                DECIMAL(12,2)   NOT NULL,
    discount_amount                              DECIMAL(12,2)   NOT NULL DEFAULT 0,
    sales_amount                                    DECIMAL(12,2)   NOT NULL,
    cost_amount                                        DECIMAL(12,2)   NULL,
    profit_amount                                          DECIMAL(12,2)   NULL,
    dq_flag                                                   BIT             NOT NULL DEFAULT 0,
    dq_notes                                                     VARCHAR(400)    NULL,
    silver_load_dt                                                  DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_sales_customer FOREIGN KEY (customer_id) REFERENCES silver.customers(customer_id),
    CONSTRAINT fk_sales_product  FOREIGN KEY (product_id)  REFERENCES silver.products(product_id),
    CONSTRAINT fk_sales_store    FOREIGN KEY (store_id)    REFERENCES silver.stores(store_id),
    CONSTRAINT fk_sales_employee FOREIGN KEY (employee_id) REFERENCES silver.employees(employee_id),
    CONSTRAINT ck_sales_qty_nonneg CHECK (quantity >= 0),
    CONSTRAINT ck_sales_amount_nonneg CHECK (sales_amount >= 0)
);
GO


/* -------------------------------------------------------------------------------------
   STEP 2 — Quarantine table structure
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('quarantine.sales','U') IS NOT NULL DROP TABLE quarantine.sales;
GO

SELECT *, CAST(NULL AS VARCHAR(300)) AS reject_reason, CAST(GETDATE() AS DATETIME) AS quarantined_at
INTO quarantine.sales FROM bronze.sales WHERE 1 = 0;
GO


/* -------------------------------------------------------------------------------------
   STEP 3 — Quarantine: reject invalid / duplicate / bad rows
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(order_id AS INT) AS oidn,
        TRY_CAST(customer_id AS INT) AS cidn,
        TRY_CAST(product_id AS INT) AS pidn,
        TRY_CAST(store_id AS INT) AS sidn,
        TRY_CAST(employee_id AS INT) AS eidn,
        TRY_CAST(quantity AS INT) AS qty_n,
        TRY_CAST(unit_price AS DECIMAL(12,2)) AS price_n,
        TRY_CAST(discount_amount AS DECIMAL(12,2)) AS disc_n,
        TRY_CAST(order_date AS DATE) AS ord_dt_raw
    FROM bronze.sales
),
staged2 AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY oidn ORDER BY (SELECT NULL)) AS rn,
        (qty_n * price_n) AS base_amount
    FROM staged
),
classified AS (
    SELECT *,
        CASE
            WHEN oidn IS NULL THEN 'invalid/unparseable order_id'
            WHEN rn > 1 THEN 'duplicate order_id - extra copy removed'
            WHEN price_n IS NULL THEN 'unit_price missing - cannot derive sales_amount'
            WHEN qty_n IS NOT NULL AND qty_n < 0 THEN 'negative quantity'
            WHEN disc_n IS NOT NULL AND base_amount IS NOT NULL AND disc_n > base_amount THEN 'discount_amount exceeds quantity x unit_price'
            WHEN cidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.customers c WHERE c.customer_id = cidn)
                THEN 'orphan customer_id - customer not found in Silver'
            WHEN pidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.products p WHERE p.product_id = pidn)
                THEN 'orphan product_id - product not found in Silver'
            WHEN sidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.stores st WHERE st.store_id = sidn)
                THEN 'orphan store_id - store not found in Silver'
            WHEN ord_dt_raw IS NOT NULL AND ord_dt_raw > CAST('2026-08-29' AS DATE) THEN 'order_date is future-dated'
            ELSE NULL
        END AS reject_reason
    FROM staged2
)
INSERT INTO quarantine.sales
SELECT order_id, customer_id, product_id, store_id, employee_id, order_date, quantity,
       unit_price, discount_amount, sales_amount, cost_amount, profit_amount,
       reject_reason, GETDATE()
FROM classified WHERE reject_reason IS NOT NULL;
GO


/* -------------------------------------------------------------------------------------
   STEP 4 — Transform: Bronze -> Silver
   NOTE: sales_amount and profit_amount are always RECALCULATED, never trusted from
   Bronze — per the treatment decision matrix, sales.sales_amount is a High-severity
   check whose Silver_Action is "recalculate," not reject.
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(order_id AS INT) AS oidn,
        TRY_CAST(customer_id AS INT) AS cidn,
        TRY_CAST(product_id AS INT) AS pidn,
        TRY_CAST(store_id AS INT) AS sidn,
        TRY_CAST(employee_id AS INT) AS eidn,
        TRY_CAST(quantity AS INT) AS qty_n,
        TRY_CAST(unit_price AS DECIMAL(12,2)) AS price_n,
        TRY_CAST(discount_amount AS DECIMAL(12,2)) AS disc_n,
        TRY_CAST(cost_amount AS DECIMAL(12,2)) AS cost_n,
        dbo.fn_ParseFlexDate(order_date) AS ord_dt          -- bronze format seen: dd-mm-yyyy
    FROM bronze.sales
),
staged2 AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY oidn ORDER BY (SELECT NULL)) AS rn,
        (qty_n * price_n) AS base_amount
    FROM staged
),
classified AS (
    SELECT *,
        CASE WHEN order_date IS NOT NULL AND ord_dt IS NULL THEN 1 ELSE 0 END AS bad_date_fmt,
        CASE WHEN eidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.employees e WHERE e.employee_id = eidn)
             THEN 1 ELSE 0 END AS orphan_employee,
        CASE
            WHEN oidn IS NULL THEN 'reject'
            WHEN rn > 1 THEN 'reject'
            WHEN price_n IS NULL THEN 'reject'
            WHEN qty_n IS NOT NULL AND qty_n < 0 THEN 'reject'
            WHEN disc_n IS NOT NULL AND base_amount IS NOT NULL AND disc_n > base_amount THEN 'reject'
            WHEN cidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.customers c WHERE c.customer_id = cidn) THEN 'reject'
            WHEN pidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.products p WHERE p.product_id = pidn) THEN 'reject'
            WHEN sidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.stores st WHERE st.store_id = sidn) THEN 'reject'
            WHEN ord_dt IS NOT NULL AND ord_dt > CAST('2026-08-29' AS DATE) THEN 'reject'
            ELSE 'keep'
        END AS decision
    FROM staged2
)
INSERT INTO silver.sales (order_id, customer_id, product_id, store_id, employee_id,
    order_date, quantity, unit_price, discount_amount, sales_amount, cost_amount,
    profit_amount, dq_flag, dq_notes)
SELECT
    oidn, cidn, pidn, sidn,
    CASE WHEN orphan_employee = 1 THEN NULL ELSE eidn END,
    ord_dt, qty_n, price_n, ISNULL(disc_n, 0),
    base_amount - ISNULL(disc_n, 0),                          -- always recalculated, never trust bronze sales_amount
    cost_n,
    (base_amount - ISNULL(disc_n, 0)) - ISNULL(cost_n, 0),    -- profit recalculated consistently with sales_amount
    CASE WHEN (bad_date_fmt + orphan_employee) > 0 THEN 1 ELSE 0 END,
    NULLIF(LTRIM(
        CASE WHEN bad_date_fmt = 1     THEN 'order_date_unparseable_nulled; ' ELSE '' END +
        CASE WHEN orphan_employee = 1  THEN 'employee_id_orphan_nulled_excluded_from_employee_kpis; ' ELSE '' END
    ), '')
FROM classified WHERE decision = 'keep';
GO


/* -------------------------------------------------------------------------------------
   STEP 5 — Table-level validation (assertions; each should return 0)
   ------------------------------------------------------------------------------------- */
-- No duplicate primary keys
SELECT COUNT(*) - COUNT(DISTINCT order_id) AS dup_count FROM silver.sales;

-- No NULLs in required fields
SELECT COUNT(*) AS null_unit_price   FROM silver.sales WHERE unit_price IS NULL;
SELECT COUNT(*) AS null_sales_amount FROM silver.sales WHERE sales_amount IS NULL;

-- Business rules
SELECT COUNT(*) AS negative_quantity     FROM silver.sales WHERE quantity < 0;
SELECT COUNT(*) AS negative_sales_amount FROM silver.sales WHERE sales_amount < 0;

-- Referential integrity
SELECT COUNT(*) AS orphans_vs_customers FROM silver.sales sa WHERE NOT EXISTS (SELECT 1 FROM silver.customers c WHERE c.customer_id = sa.customer_id);
SELECT COUNT(*) AS orphans_vs_products  FROM silver.sales sa WHERE NOT EXISTS (SELECT 1 FROM silver.products p WHERE p.product_id = sa.product_id);
SELECT COUNT(*) AS orphans_vs_stores    FROM silver.sales sa WHERE NOT EXISTS (SELECT 1 FROM silver.stores s WHERE s.store_id = sa.store_id);

-- Bronze vs Silver vs Quarantine row counts
SELECT
    (SELECT COUNT(*) FROM bronze.sales)     AS bronze_rows,
    (SELECT COUNT(*) FROM silver.sales)     AS silver_rows,
    (SELECT COUNT(*) FROM quarantine.sales) AS quarantined_rows;
