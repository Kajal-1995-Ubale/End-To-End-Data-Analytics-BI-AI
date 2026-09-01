/* =====================================================================================
   RETAILMART GOLD LAYER — 07. FACT_RETURNS
   -----------------------------------------------------------------------------------
   Run 00_Setup through 06_Fact_Sales.sql first (needs gold.fact_sales for the
   sales_key lineage lookup).
   Grain: one row per silver.returns row. Source: silver.returns, joined to
   dim_customers, dim_products, dim_stores, dim_date, and fact_sales (via order_id).
   store_key falls back to the Unknown member (-1) when silver.returns.store_id is
   NULL — see 01_Dim_Stores.sql.
   ===================================================================================== */

IF OBJECT_ID('gold.fact_returns','U') IS NOT NULL DROP TABLE gold.fact_returns;
GO

CREATE TABLE gold.fact_returns (
    return_key           INT             IDENTITY(1,1) PRIMARY KEY,
    return_id               INT             NOT NULL,
    order_id                   INT             NOT NULL,   -- natural key, kept for lineage back to the order
    sales_key                     INT             NOT NULL,   -- FK to gold.fact_sales
    date_key                         INT             NULL,       -- FK to gold.dim_date (return_date); NULL if date unknown
    customer_key                        INT             NOT NULL,   -- FK to gold.dim_customers
    product_key                            INT             NOT NULL,   -- FK to gold.dim_products
    store_key                                 INT             NOT NULL,   -- FK to gold.dim_stores (-1 = Unknown)
    return_quantity                              INT             NOT NULL,
    return_amount                                   DECIMAL(12,2)   NULL,
    refund_amount                                      DECIMAL(12,2)   NULL,
    return_reason                                         VARCHAR(100)    NULL,
    return_status                                            VARCHAR(20)     NULL,
    gold_load_dt                                                DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_fact_returns_sales    FOREIGN KEY (sales_key)    REFERENCES gold.fact_sales(sales_key),
    CONSTRAINT fk_fact_returns_date     FOREIGN KEY (date_key)     REFERENCES gold.dim_date(date_key),
    CONSTRAINT fk_fact_returns_customer FOREIGN KEY (customer_key) REFERENCES gold.dim_customers(customer_key),
    CONSTRAINT fk_fact_returns_product  FOREIGN KEY (product_key)  REFERENCES gold.dim_products(product_key),
    CONSTRAINT fk_fact_returns_store    FOREIGN KEY (store_key)    REFERENCES gold.dim_stores(store_key)
);
GO

INSERT INTO gold.fact_returns (return_id, order_id, sales_key, date_key, customer_key,
    product_key, store_key, return_quantity, return_amount, refund_amount,
    return_reason, return_status)
SELECT
    r.return_id,
    r.order_id,
    fs.sales_key,
    CASE WHEN r.return_date IS NULL THEN NULL ELSE CAST(CONVERT(VARCHAR(8), r.return_date, 112) AS INT) END,
    r.customer_id,
    r.product_id,
    ISNULL(r.store_id, -1),
    r.return_quantity, r.return_amount, r.refund_amount, r.return_reason, r.return_status
FROM silver.returns r
INNER JOIN gold.fact_sales fs ON fs.order_id = r.order_id;
GO


/* -------------------------------------------------------------------------------------
   Validation
   ------------------------------------------------------------------------------------- */
-- No duplicate natural keys
SELECT COUNT(*) - COUNT(DISTINCT return_id) AS dup_count FROM gold.fact_returns;

-- Referential integrity
SELECT COUNT(*) AS orphans_vs_sales    FROM gold.fact_returns f WHERE NOT EXISTS (SELECT 1 FROM gold.fact_sales s WHERE s.sales_key = f.sales_key);
SELECT COUNT(*) AS orphans_vs_date     FROM gold.fact_returns f WHERE f.date_key IS NOT NULL AND NOT EXISTS (SELECT 1 FROM gold.dim_date d WHERE d.date_key = f.date_key);
SELECT COUNT(*) AS orphans_vs_customer FROM gold.fact_returns f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_customers c WHERE c.customer_key = f.customer_key);
SELECT COUNT(*) AS orphans_vs_product  FROM gold.fact_returns f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_products p WHERE p.product_key = f.product_key);
SELECT COUNT(*) AS orphans_vs_store    FROM gold.fact_returns f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_stores s WHERE s.store_key = f.store_key);

-- Row counts (should match Silver 1:1, since every silver.returns row already has a
-- validated FK to silver.sales)
SELECT
    (SELECT COUNT(*) FROM silver.returns)     AS silver_rows,
    (SELECT COUNT(*) FROM gold.fact_returns)  AS gold_rows;
