/* =====================================================================================
   RETAILMART SILVER LAYER — 05. INVENTORY
   -----------------------------------------------------------------------------------
   Run 00_Setup_Schemas_RefData_Functions.sql, 01_Stores.sql and 02_Products.sql first.
   DEPENDS ON: silver.products, silver.stores (FK + orphan-checks).
   ===================================================================================== */


/* -------------------------------------------------------------------------------------
   STEP 1 — Silver table structure
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('silver.inventory','U') IS NOT NULL DROP TABLE silver.inventory;
GO

CREATE TABLE silver.inventory (
    inventory_id        INT             NOT NULL PRIMARY KEY,
    product_id             INT             NOT NULL,
    store_id                  INT             NOT NULL,
    warehouse_id                 VARCHAR(50)     NULL,
    snapshot_date                   DATE            NULL,
    stock_quantity                     INT             NOT NULL,
    reserved_quantity                     INT             NOT NULL,
    available_quantity                       INT             NOT NULL,
    reorder_level                               INT             NULL,
    inventory_status                               VARCHAR(20)     NULL,
    dq_flag                                           BIT             NOT NULL DEFAULT 0,
    dq_notes                                             VARCHAR(400)    NULL,
    silver_load_dt                                          DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES silver.products(product_id),
    CONSTRAINT fk_inventory_store   FOREIGN KEY (store_id)   REFERENCES silver.stores(store_id),
    CONSTRAINT ck_inventory_stock_nonneg CHECK (stock_quantity >= 0),
    CONSTRAINT ck_inventory_reserved_le_stock CHECK (reserved_quantity <= stock_quantity),
    CONSTRAINT ck_inventory_available CHECK (available_quantity = stock_quantity - reserved_quantity)
);
GO


/* -------------------------------------------------------------------------------------
   STEP 2 — Quarantine table structure
   ------------------------------------------------------------------------------------- */
IF OBJECT_ID('quarantine.inventory','U') IS NOT NULL DROP TABLE quarantine.inventory;
GO

SELECT *, CAST(NULL AS VARCHAR(300)) AS reject_reason, CAST(GETDATE() AS DATETIME) AS quarantined_at
INTO quarantine.inventory FROM bronze.inventory WHERE 1 = 0;
GO


/* -------------------------------------------------------------------------------------
   STEP 3 — Quarantine: reject invalid / duplicate / bad rows
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(inventory_id AS INT) AS iidn,
        TRY_CAST(product_id AS INT) AS pidn,
        TRY_CAST(store_id AS INT) AS sidn,
        TRY_CAST(stock_quantity AS INT) AS stock_n,
        TRY_CAST(reserved_quantity AS INT) AS reserved_n,
        TRY_CAST(snapshot_date AS DATE) AS snap_dt
    FROM bronze.inventory
),
staged2 AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY iidn ORDER BY snap_dt DESC) AS rn
    FROM staged
),
classified AS (
    SELECT *,
        CASE
            WHEN iidn IS NULL THEN 'invalid/unparseable inventory_id'
            WHEN rn > 1 THEN 'duplicate inventory_id - extra copy removed'
            WHEN stock_n IS NOT NULL AND stock_n < 0 THEN 'negative stock_quantity'
            WHEN reserved_n IS NOT NULL AND stock_n IS NOT NULL AND reserved_n > stock_n THEN 'reserved_quantity exceeds stock_quantity'
            WHEN pidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.products p WHERE p.product_id = pidn)
                THEN 'orphan product_id - product not found in Silver'
            WHEN sidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.stores st WHERE st.store_id = sidn)
                THEN 'orphan store_id - store not found in Silver'
            WHEN snap_dt IS NOT NULL AND snap_dt > CAST('2026-08-29' AS DATE) THEN 'snapshot_date is future-dated'
            ELSE NULL
        END AS reject_reason
    FROM staged2
)
INSERT INTO quarantine.inventory
SELECT inventory_id, product_id, store_id, warehouse_id, snapshot_date, stock_quantity,
       reserved_quantity, available_quantity, reorder_level, inventory_status,
       reject_reason, GETDATE()
FROM classified WHERE reject_reason IS NOT NULL;
GO


/* -------------------------------------------------------------------------------------
   STEP 4 — Transform: Bronze -> Silver
   NOTE: available_quantity is always RECALCULATED (stock - reserved), never trusted
   from Bronze — per the treatment decision matrix, this is a High-severity check whose
   Silver_Action is "recalculate," not reject.
   ------------------------------------------------------------------------------------- */
WITH staged AS (
    SELECT *,
        TRY_CAST(inventory_id AS INT) AS iidn,
        TRY_CAST(product_id AS INT) AS pidn,
        TRY_CAST(store_id AS INT) AS sidn,
        TRY_CAST(stock_quantity AS INT) AS stock_n,
        TRY_CAST(reserved_quantity AS INT) AS reserved_n,
        TRY_CAST(reorder_level AS INT) AS reorder_n,
        TRY_CAST(snapshot_date AS DATE) AS snap_dt
    FROM bronze.inventory
),
staged2 AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY iidn ORDER BY snap_dt DESC) AS rn
    FROM staged
),
classified AS (
    SELECT *,
        CASE
            WHEN iidn IS NULL THEN 'reject'
            WHEN rn > 1 THEN 'reject'
            WHEN stock_n IS NOT NULL AND stock_n < 0 THEN 'reject'
            WHEN reserved_n IS NOT NULL AND stock_n IS NOT NULL AND reserved_n > stock_n THEN 'reject'
            WHEN pidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.products p WHERE p.product_id = pidn) THEN 'reject'
            WHEN sidn IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.stores st WHERE st.store_id = sidn) THEN 'reject'
            WHEN snap_dt IS NOT NULL AND snap_dt > CAST('2026-08-29' AS DATE) THEN 'reject'
            ELSE 'keep'
        END AS decision
    FROM staged2
)
INSERT INTO silver.inventory (inventory_id, product_id, store_id, warehouse_id,
    snapshot_date, stock_quantity, reserved_quantity, available_quantity, reorder_level,
    inventory_status, dq_flag, dq_notes)
SELECT
    iidn, pidn, sidn, warehouse_id, snap_dt, stock_n, reserved_n,
    stock_n - reserved_n,                                  -- always recalculated, never trust bronze available_quantity
    reorder_n,
    CASE WHEN inventory_status IN ('In Stock','Low Stock','Overstock','Out of Stock') THEN inventory_status
         ELSE 'Unknown' END,
    CASE WHEN reorder_n IS NULL THEN 1 ELSE 0 END,
    CASE WHEN reorder_n IS NULL THEN 'reorder_level missing; defaulted downstream to category-average' ELSE NULL END
FROM classified WHERE decision = 'keep';
GO


/* -------------------------------------------------------------------------------------
   STEP 5 — Table-level validation (assertions; each should return 0)
   ------------------------------------------------------------------------------------- */
-- No duplicate primary keys
SELECT COUNT(*) - COUNT(DISTINCT inventory_id) AS dup_count FROM silver.inventory;

-- Business rules
SELECT COUNT(*) AS negative_stock FROM silver.inventory WHERE stock_quantity < 0;
SELECT COUNT(*) AS reserved_gt_stock FROM silver.inventory WHERE reserved_quantity > stock_quantity;
SELECT COUNT(*) AS available_mismatch FROM silver.inventory WHERE available_quantity <> stock_quantity - reserved_quantity;

-- Referential integrity
SELECT COUNT(*) AS orphans_vs_products FROM silver.inventory i WHERE NOT EXISTS (SELECT 1 FROM silver.products p WHERE p.product_id = i.product_id);
SELECT COUNT(*) AS orphans_vs_stores   FROM silver.inventory i WHERE NOT EXISTS (SELECT 1 FROM silver.stores s WHERE s.store_id = i.store_id);

-- Standardization landed correctly
SELECT DISTINCT inventory_status FROM silver.inventory;  -- EXPECTED: In Stock, Low Stock, Overstock, Out of Stock, Unknown

-- Bronze vs Silver vs Quarantine row counts
SELECT
    (SELECT COUNT(*) FROM bronze.inventory)     AS bronze_rows,
    (SELECT COUNT(*) FROM silver.inventory)     AS silver_rows,
    (SELECT COUNT(*) FROM quarantine.inventory) AS quarantined_rows;
