/* =====================================================================================
   RETAILMART GOLD LAYER — 02. DIM_PRODUCTS
   -----------------------------------------------------------------------------------
   Run 00_Setup_Gold_Schema_And_DimDate.sql first.
   Source: silver.products. No Unknown member needed — product_id is NOT NULL on every
   Silver fact table that references it (inventory, sales, returns), so there is never
   a genuinely missing product to point a fact row at.
   ===================================================================================== */

IF OBJECT_ID('gold.dim_products','U') IS NOT NULL DROP TABLE gold.dim_products;
GO

CREATE TABLE gold.dim_products (
    product_key     INT             NOT NULL PRIMARY KEY,
    product_id      INT             NOT NULL,
    product_name    VARCHAR(200)    NOT NULL,
    category        VARCHAR(100)    NULL,
    subcategory     VARCHAR(100)    NULL,
    brand           VARCHAR(100)    NULL,
    unit_cost       DECIMAL(12,2)   NULL,
    selling_price   DECIMAL(12,2)   NULL,
    margin_amount   DECIMAL(12,2)   NULL,   -- selling_price - unit_cost
    margin_pct      DECIMAL(6,2)    NULL,   -- (selling_price - unit_cost) / selling_price * 100
    supplier_id     VARCHAR(50)     NULL,
    product_status  VARCHAR(20)     NULL,
    launch_date     DATE            NULL,
    gold_load_dt    DATETIME        NOT NULL DEFAULT GETDATE()
);
GO

-- product_key = product_id 1:1 (see dim_stores for the rationale).
INSERT INTO gold.dim_products (product_key, product_id, product_name, category,
    subcategory, brand, unit_cost, selling_price, margin_amount, margin_pct,
    supplier_id, product_status, launch_date)
SELECT
    product_id, product_id, product_name, category, subcategory, brand,
    unit_cost, selling_price,
    selling_price - unit_cost,
    CASE WHEN selling_price IS NULL OR selling_price = 0 OR unit_cost IS NULL THEN NULL
         ELSE ROUND((selling_price - unit_cost) / selling_price * 100, 2) END,
    supplier_id, product_status, launch_date
FROM silver.products;
GO


/* -------------------------------------------------------------------------------------
   Validation
   ------------------------------------------------------------------------------------- */
-- No duplicate keys
SELECT COUNT(*) - COUNT(DISTINCT product_key) AS dup_count FROM gold.dim_products;

-- Row counts (Gold should equal Silver — no Unknown member on this dimension)
SELECT
    (SELECT COUNT(*) FROM silver.products)   AS silver_rows,
    (SELECT COUNT(*) FROM gold.dim_products) AS gold_rows;
