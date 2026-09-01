/* =====================================================================================
   RETAILMART GOLD LAYER — 08. VALIDATION SUMMARY
   -----------------------------------------------------------------------------------
   Run this LAST, after all Gold scripts (00_Setup ... 07_Fact_Returns.sql).
   Each per-table script already validates that table on its own; this script rolls
   everything up into one report.

   Every query below is an assertion: it SHOULD return 0 (or match the noted
   expectation). A non-zero/unexpected result means a load bug to investigate before
   trusting the Gold layer for reporting.
   ===================================================================================== */

-- 1. No duplicate keys in any Gold table
SELECT 'dim_stores'      AS tbl, COUNT(*) - COUNT(DISTINCT store_key)    AS dup_count FROM gold.dim_stores
UNION ALL SELECT 'dim_products',  COUNT(*) - COUNT(DISTINCT product_key)   FROM gold.dim_products
UNION ALL SELECT 'dim_customers', COUNT(*) - COUNT(DISTINCT customer_key)  FROM gold.dim_customers
UNION ALL SELECT 'dim_employees', COUNT(*) - COUNT(DISTINCT employee_key)  FROM gold.dim_employees
UNION ALL SELECT 'fact_inventory', COUNT(*) - COUNT(DISTINCT inventory_id) FROM gold.fact_inventory
UNION ALL SELECT 'fact_sales',     COUNT(*) - COUNT(DISTINCT order_id)     FROM gold.fact_sales
UNION ALL SELECT 'fact_returns',   COUNT(*) - COUNT(DISTINCT return_id)    FROM gold.fact_returns;
-- EXPECTED: dup_count = 0 for every row

-- 2. Referential integrity holds across every fact -> dimension relationship
SELECT 'fact_inventory -> dim_products' AS relationship, COUNT(*) AS orphans
FROM gold.fact_inventory f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_products p WHERE p.product_key = f.product_key)
UNION ALL
SELECT 'fact_inventory -> dim_stores', COUNT(*) FROM gold.fact_inventory f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_stores s WHERE s.store_key = f.store_key)
UNION ALL
SELECT 'fact_sales -> dim_customers', COUNT(*) FROM gold.fact_sales f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_customers c WHERE c.customer_key = f.customer_key)
UNION ALL
SELECT 'fact_sales -> dim_products', COUNT(*) FROM gold.fact_sales f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_products p WHERE p.product_key = f.product_key)
UNION ALL
SELECT 'fact_sales -> dim_stores', COUNT(*) FROM gold.fact_sales f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_stores s WHERE s.store_key = f.store_key)
UNION ALL
SELECT 'fact_sales -> dim_employees', COUNT(*) FROM gold.fact_sales f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_employees e WHERE e.employee_key = f.employee_key)
UNION ALL
SELECT 'fact_returns -> fact_sales', COUNT(*) FROM gold.fact_returns f WHERE NOT EXISTS (SELECT 1 FROM gold.fact_sales s WHERE s.sales_key = f.sales_key)
UNION ALL
SELECT 'fact_returns -> dim_customers', COUNT(*) FROM gold.fact_returns f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_customers c WHERE c.customer_key = f.customer_key)
UNION ALL
SELECT 'fact_returns -> dim_products', COUNT(*) FROM gold.fact_returns f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_products p WHERE p.product_key = f.product_key)
UNION ALL
SELECT 'fact_returns -> dim_stores', COUNT(*) FROM gold.fact_returns f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_stores s WHERE s.store_key = f.store_key);
-- EXPECTED: orphans = 0 for every row

-- 3. Unknown-member usage — how often each fact table actually needed the fallback
-- (a high count here is worth investigating upstream in Bronze/Silver, not a Gold bug)
SELECT 'fact_sales.employee_key = Unknown' AS metric, COUNT(*) AS row_count FROM gold.fact_sales WHERE employee_key = -1
UNION ALL
SELECT 'fact_returns.store_key = Unknown', COUNT(*) FROM gold.fact_returns WHERE store_key = -1;

-- 4. Silver vs Gold row counts (dims include the +1 Unknown member where applicable;
-- facts should match Silver 1:1)
SELECT 'dim_stores'      AS tbl, (SELECT COUNT(*) FROM silver.stores)    AS silver_rows, (SELECT COUNT(*) FROM gold.dim_stores)     AS gold_rows
UNION ALL SELECT 'dim_products',  (SELECT COUNT(*) FROM silver.products),  (SELECT COUNT(*) FROM gold.dim_products)
UNION ALL SELECT 'dim_customers', (SELECT COUNT(*) FROM silver.customers), (SELECT COUNT(*) FROM gold.dim_customers)
UNION ALL SELECT 'dim_employees', (SELECT COUNT(*) FROM silver.employees), (SELECT COUNT(*) FROM gold.dim_employees)
UNION ALL SELECT 'fact_inventory', (SELECT COUNT(*) FROM silver.inventory), (SELECT COUNT(*) FROM gold.fact_inventory)
UNION ALL SELECT 'fact_sales',     (SELECT COUNT(*) FROM silver.sales),     (SELECT COUNT(*) FROM gold.fact_sales)
UNION ALL SELECT 'fact_returns',   (SELECT COUNT(*) FROM silver.returns),   (SELECT COUNT(*) FROM gold.fact_returns);

-- 5. Quick business sanity check: total sales_amount and profit_amount should be
-- non-negative in aggregate, and profit should never exceed sales
SELECT
    SUM(sales_amount)  AS total_sales,
    SUM(profit_amount) AS total_profit,
    SUM(CASE WHEN profit_amount > sales_amount THEN 1 ELSE 0 END) AS rows_where_profit_gt_sales
FROM gold.fact_sales;
-- EXPECTED: rows_where_profit_gt_sales = 0
