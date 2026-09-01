/* =====================================================================================
   RETAILMART GOLD LAYER — 01. DIM_STORES
   -----------------------------------------------------------------------------------
   Run 00_Setup_Gold_Schema_And_DimDate.sql first.
   Source: silver.stores. Includes an "Unknown" member (store_key = -1) because
   silver.returns.store_id is nullable, so fact_returns needs a store_key to point to
   when the source store is unknown rather than leaving the FK column NULL.
   ===================================================================================== */

IF OBJECT_ID('gold.dim_stores','U') IS NOT NULL DROP TABLE gold.dim_stores;
GO

CREATE TABLE gold.dim_stores (
    store_key       INT             NOT NULL PRIMARY KEY,
    store_id        INT             NULL,          -- NULL only for the Unknown member
    store_name      VARCHAR(200)    NOT NULL,
    city            VARCHAR(100)    NULL,
    state           VARCHAR(30)     NULL,
    region          VARCHAR(50)     NULL,
    store_type      VARCHAR(50)     NULL,
    opening_date    DATE            NULL,
    manager_id      VARCHAR(50)     NULL,
    store_status    VARCHAR(20)     NULL,
    square_feet     INT             NULL,
    gold_load_dt    DATETIME        NOT NULL DEFAULT GETDATE()
);
GO

-- Unknown member (store_key is a plain INT PK here, not IDENTITY, so -1 inserts directly)
INSERT INTO gold.dim_stores (store_key, store_id, store_name, city, state, region,
    store_type, opening_date, manager_id, store_status, square_feet)
VALUES (-1, NULL, 'Unknown Store', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
GO

-- Load from Silver. store_key = store_id 1:1 here since silver.stores.store_id is
-- already a clean, deduplicated, validated primary key — no need for a separate
-- IDENTITY surrogate; using the natural key directly keeps joins simple downstream.
INSERT INTO gold.dim_stores (store_key, store_id, store_name, city, state, region,
    store_type, opening_date, manager_id, store_status, square_feet)
SELECT
    store_id, store_id, store_name, city, state, region, store_type, opening_date,
    manager_id, store_status, square_feet
FROM silver.stores;
GO


/* -------------------------------------------------------------------------------------
   Validation
   ------------------------------------------------------------------------------------- */
-- No duplicate keys
SELECT COUNT(*) - COUNT(DISTINCT store_key) AS dup_count FROM gold.dim_stores;

-- Row counts (Gold should be Silver row count + 1 for the Unknown member)
SELECT
    (SELECT COUNT(*) FROM silver.stores)   AS silver_rows,
    (SELECT COUNT(*) FROM gold.dim_stores) AS gold_rows;
