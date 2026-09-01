/* =====================================================================================
   RETAILMART GOLD LAYER — 05. FACT_INVENTORY
   -----------------------------------------------------------------------------------
   Run 00_Setup through 04_Dim_Employees.sql first.
   Grain: one row per silver.inventory row (one inventory snapshot for a given
   product/store/warehouse combination). Source: silver.inventory, joined to
   dim_products, dim_stores, dim_date.
   ===================================================================================== */

IF OBJECT_ID('gold.fact_inventory','U') IS NOT NULL DROP TABLE gold.fact_inventory;
GO

CREATE TABLE gold.fact_inventory (
    inventory_key       INT             IDENTITY(1,1) PRIMARY KEY,
    inventory_id          INT             NOT NULL,
    date_key                 INT             NULL,       -- FK to gold.dim_date (snapshot_date); NULL if date unknown
    product_key                 INT             NOT NULL,   -- FK to gold.dim_products
    store_key                      INT             NOT NULL,   -- FK to gold.dim_stores
    warehouse_id                      VARCHAR(50)     NULL,
    stock_quantity                       INT             NOT NULL,
    reserved_quantity                       INT             NOT NULL,
    available_quantity                         INT             NOT NULL,
    reorder_level                                 INT             NULL,
    inventory_status                                 VARCHAR(20)     NULL,
    is_below_reorder                                    BIT             NOT NULL,
    gold_load_dt                                           DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_fact_inventory_date    FOREIGN KEY (date_key)    REFERENCES gold.dim_date(date_key),
    CONSTRAINT fk_fact_inventory_product FOREIGN KEY (product_key) REFERENCES gold.dim_products(product_key),
    CONSTRAINT fk_fact_inventory_store   FOREIGN KEY (store_key)   REFERENCES gold.dim_stores(store_key)
);
GO

INSERT INTO gold.fact_inventory (inventory_id, date_key, product_key, store_key,
    warehouse_id, stock_quantity, reserved_quantity, available_quantity, reorder_level,
    inventory_status, is_below_reorder)
SELECT
    i.inventory_id,
    CASE WHEN i.snapshot_date IS NULL THEN NULL ELSE CAST(CONVERT(VARCHAR(8), i.snapshot_date, 112) AS INT) END,
    i.product_id,
    i.store_id,
    i.warehouse_id,
    i.stock_quantity, i.reserved_quantity, i.available_quantity, i.reorder_level,
    i.inventory_status,
    CASE WHEN i.reorder_level IS NOT NULL AND i.available_quantity < i.reorder_level THEN 1 ELSE 0 END
FROM silver.inventory i;
GO


/* -------------------------------------------------------------------------------------
   Validation
   ------------------------------------------------------------------------------------- */
-- No duplicate natural keys
SELECT COUNT(*) - COUNT(DISTINCT inventory_id) AS dup_count FROM gold.fact_inventory;

-- Referential integrity
SELECT COUNT(*) AS orphans_vs_date    FROM gold.fact_inventory f WHERE f.date_key IS NOT NULL AND NOT EXISTS (SELECT 1 FROM gold.dim_date d WHERE d.date_key = f.date_key);
SELECT COUNT(*) AS orphans_vs_product FROM gold.fact_inventory f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_products p WHERE p.product_key = f.product_key);
SELECT COUNT(*) AS orphans_vs_store   FROM gold.fact_inventory f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_stores s WHERE s.store_key = f.store_key);

-- Row counts
SELECT
    (SELECT COUNT(*) FROM silver.inventory)     AS silver_rows,
    (SELECT COUNT(*) FROM gold.fact_inventory)  AS gold_rows;
