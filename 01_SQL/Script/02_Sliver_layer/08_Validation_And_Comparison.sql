/* =====================================================================================
   RETAILMART SILVER LAYER — 08. CROSS-TABLE VALIDATION & BRONZE-VS-SILVER COMPARISON
   -----------------------------------------------------------------------------------
   Run this LAST, after all 7 table scripts (01_Stores.sql ... 07_Returns.sql).
   Each per-table script already validates that table on its own; this script re-checks
   everything together in one place and adds the full-pipeline summary report.

   Every query below is an assertion: it SHOULD return 0 rows (or 0 in the count
   column). A non-zero result means either a transformation bug or a business rule
   that needs revisiting — not something to silently wave through.
   ===================================================================================== */

-- 1. No duplicate primary keys in any Silver table
SELECT 'silver.stores'    AS tbl, COUNT(*) - COUNT(DISTINCT store_id)    AS dup_count FROM silver.stores
UNION ALL SELECT 'silver.products',  COUNT(*) - COUNT(DISTINCT product_id)  FROM silver.products
UNION ALL SELECT 'silver.customers', COUNT(*) - COUNT(DISTINCT customer_id) FROM silver.customers
UNION ALL SELECT 'silver.employees', COUNT(*) - COUNT(DISTINCT employee_id) FROM silver.employees
UNION ALL SELECT 'silver.inventory', COUNT(*) - COUNT(DISTINCT inventory_id) FROM silver.inventory
UNION ALL SELECT 'silver.sales',     COUNT(*) - COUNT(DISTINCT order_id)    FROM silver.sales
UNION ALL SELECT 'silver.returns',   COUNT(*) - COUNT(DISTINCT return_id)   FROM silver.returns;
-- EXPECTED: dup_count = 0 for every row

-- 2. No NULLs in required (NOT NULL-equivalent business) fields
SELECT 'customers.customer_name' AS field, COUNT(*) AS null_count FROM silver.customers WHERE customer_name IS NULL
UNION ALL SELECT 'products.product_name', COUNT(*) FROM silver.products WHERE product_name IS NULL
UNION ALL SELECT 'sales.unit_price',      COUNT(*) FROM silver.sales WHERE unit_price IS NULL
UNION ALL SELECT 'sales.sales_amount',    COUNT(*) FROM silver.sales WHERE sales_amount IS NULL;
-- EXPECTED: null_count = 0 for every row (also enforced by NOT NULL constraints —
-- this query is a pre-load sanity check you can run before the INSERT if needed)

-- 3. Business rules hold (would also be blocked by CHECK constraints, verified here explicitly)
SELECT 'products: cost > price'          AS rule, COUNT(*) AS violations FROM silver.products WHERE unit_cost > selling_price
UNION ALL SELECT 'products: negative price', COUNT(*) FROM silver.products WHERE selling_price < 0
UNION ALL SELECT 'inventory: negative stock', COUNT(*) FROM silver.inventory WHERE stock_quantity < 0
UNION ALL SELECT 'inventory: reserved > stock', COUNT(*) FROM silver.inventory WHERE reserved_quantity > stock_quantity
UNION ALL SELECT 'inventory: available mismatch', COUNT(*) FROM silver.inventory WHERE available_quantity <> stock_quantity - reserved_quantity
UNION ALL SELECT 'sales: negative quantity', COUNT(*) FROM silver.sales WHERE quantity < 0
UNION ALL SELECT 'sales: negative sales_amount', COUNT(*) FROM silver.sales WHERE sales_amount < 0
UNION ALL SELECT 'returns: negative quantity', COUNT(*) FROM silver.returns WHERE return_quantity < 0
UNION ALL SELECT 'returns: refund > return_amount', COUNT(*) FROM silver.returns WHERE refund_amount > return_amount;
-- EXPECTED: violations = 0 for every row

-- 4. Referential integrity holds (would also be blocked by FK constraints)
SELECT 'employees -> stores'  AS relationship, COUNT(*) AS orphans
FROM silver.employees e WHERE e.store_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.stores s WHERE s.store_id = e.store_id)
UNION ALL
SELECT 'inventory -> products', COUNT(*) FROM silver.inventory i WHERE NOT EXISTS (SELECT 1 FROM silver.products p WHERE p.product_id = i.product_id)
UNION ALL
SELECT 'inventory -> stores', COUNT(*) FROM silver.inventory i WHERE NOT EXISTS (SELECT 1 FROM silver.stores s WHERE s.store_id = i.store_id)
UNION ALL
SELECT 'sales -> customers', COUNT(*) FROM silver.sales sa WHERE NOT EXISTS (SELECT 1 FROM silver.customers c WHERE c.customer_id = sa.customer_id)
UNION ALL
SELECT 'sales -> products', COUNT(*) FROM silver.sales sa WHERE NOT EXISTS (SELECT 1 FROM silver.products p WHERE p.product_id = sa.product_id)
UNION ALL
SELECT 'sales -> stores', COUNT(*) FROM silver.sales sa WHERE NOT EXISTS (SELECT 1 FROM silver.stores s WHERE s.store_id = sa.store_id)
UNION ALL
SELECT 'returns -> sales', COUNT(*) FROM silver.returns r WHERE NOT EXISTS (SELECT 1 FROM silver.sales sa WHERE sa.order_id = r.order_id)
UNION ALL
SELECT 'returns -> customers', COUNT(*) FROM silver.returns r WHERE NOT EXISTS (SELECT 1 FROM silver.customers c WHERE c.customer_id = r.customer_id)
UNION ALL
SELECT 'returns -> products', COUNT(*) FROM silver.returns r WHERE NOT EXISTS (SELECT 1 FROM silver.products p WHERE p.product_id = r.product_id);
-- EXPECTED: orphans = 0 for every row

-- 5. Standardization actually landed (categorical fields should only show the
-- canonical values after cleaning)
SELECT DISTINCT gender FROM silver.customers;                -- EXPECTED: Male, Female, Other, NULL only
SELECT DISTINCT customer_status FROM silver.customers;        -- EXPECTED: Active, Inactive, NULL only
SELECT DISTINCT store_status FROM silver.stores;               -- EXPECTED: Active, Closed, Renovating, NULL only
SELECT DISTINCT inventory_status FROM silver.inventory;        -- EXPECTED: In Stock, Low Stock, Overstock, Out of Stock, Unknown


/* =====================================================================================
   BRONZE VS SILVER COMPARISON
   One summary row per table: how many rows came in, how many made it to Silver, how
   many were quarantined, and what % survived. This is the number you report back
   after every load — the same shape as the Bronze DQ report's Summary tab.
   ===================================================================================== */

SELECT
    b.tbl AS [Table],
    b.bronze_rows,
    ISNULL(s.silver_rows, 0)      AS silver_rows,
    ISNULL(q.quarantined_rows, 0) AS quarantined_rows,
    CAST(ISNULL(s.silver_rows, 0) AS DECIMAL(10,4)) / b.bronze_rows AS pct_loaded_to_silver,
    CAST(ISNULL(q.quarantined_rows, 0) AS DECIMAL(10,4)) / b.bronze_rows AS pct_quarantined
FROM (
    SELECT 'stores' AS tbl, COUNT(*) AS bronze_rows FROM bronze.stores
    UNION ALL SELECT 'products', COUNT(*) FROM bronze.products
    UNION ALL SELECT 'customers', COUNT(*) FROM bronze.customers
    UNION ALL SELECT 'employees', COUNT(*) FROM bronze.employees
    UNION ALL SELECT 'inventory', COUNT(*) FROM bronze.inventory
    UNION ALL SELECT 'sales', COUNT(*) FROM bronze.sales
    UNION ALL SELECT 'returns', COUNT(*) FROM bronze.returns
) b
LEFT JOIN (
    SELECT 'stores' AS tbl, COUNT(*) AS silver_rows FROM silver.stores
    UNION ALL SELECT 'products', COUNT(*) FROM silver.products
    UNION ALL SELECT 'customers', COUNT(*) FROM silver.customers
    UNION ALL SELECT 'employees', COUNT(*) FROM silver.employees
    UNION ALL SELECT 'inventory', COUNT(*) FROM silver.inventory
    UNION ALL SELECT 'sales', COUNT(*) FROM silver.sales
    UNION ALL SELECT 'returns', COUNT(*) FROM silver.returns
) s ON s.tbl = b.tbl
LEFT JOIN (
    SELECT 'stores' AS tbl, COUNT(*) AS quarantined_rows FROM quarantine.stores
    UNION ALL SELECT 'products', COUNT(*) FROM quarantine.products
    UNION ALL SELECT 'customers', COUNT(*) FROM quarantine.customers
    UNION ALL SELECT 'employees', COUNT(*) FROM quarantine.employees
    UNION ALL SELECT 'inventory', COUNT(*) FROM quarantine.inventory
    UNION ALL SELECT 'sales', COUNT(*) FROM quarantine.sales
    UNION ALL SELECT 'returns', COUNT(*) FROM quarantine.returns
) q ON q.tbl = b.tbl
ORDER BY b.tbl;

-- Also worth reviewing: which rejection reasons are most common, per table —
-- tells you where to focus a source-system fix rather than a Silver-layer workaround.
SELECT 'stores' AS tbl, reject_reason, COUNT(*) AS row_count FROM quarantine.stores GROUP BY reject_reason
UNION ALL SELECT 'products', reject_reason, COUNT(*) FROM quarantine.products GROUP BY reject_reason
UNION ALL SELECT 'customers', reject_reason, COUNT(*) FROM quarantine.customers GROUP BY reject_reason
UNION ALL SELECT 'employees', reject_reason, COUNT(*) FROM quarantine.employees GROUP BY reject_reason
UNION ALL SELECT 'inventory', reject_reason, COUNT(*) FROM quarantine.inventory GROUP BY reject_reason
UNION ALL SELECT 'sales', reject_reason, COUNT(*) FROM quarantine.sales GROUP BY reject_reason
UNION ALL SELECT 'returns', reject_reason, COUNT(*) FROM quarantine.returns GROUP BY reject_reason
ORDER BY tbl, row_count DESC;
