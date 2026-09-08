/* =====================================================================================
   DASHBOARD 5 — INVENTORY PERFORMANCE
   -----------------------------------------------------------------------------------
   Every query below answers one KPI card or chart on the Inventory Performance
   dashboard.
   Source: gold.fact_inventory, gold.dim_products, gold.dim_stores.
   Engine: Microsoft SQL Server (T-SQL).

   fact_inventory is a snapshot fact (one row per product/store/warehouse as of
   snapshot_date), so there's no "date range" sum here the way fact_sales has — the
   dashboard's Snapshot filter (Latest / Last Week / Last Month) instead picks WHICH
   snapshot_date to read. Set @snapshot_date accordingly; leave it as the latest
   available date for "Latest."

   Set @category_filter to a category name to reproduce the dashboard's Category
   filter; leave NULL for "All categories."
   ===================================================================================== */

DECLARE @snapshot_date    DATE = (SELECT MAX(dd.full_date)
                                   FROM gold.fact_inventory fi
                                   JOIN gold.dim_date dd ON dd.date_key = fi.date_key);
DECLARE @category_filter  VARCHAR(100) = NULL;


/* -------------------------------------------------------------------------------------
   KPI CARDS: Total Stock Units, Available Units, SKUs Below Reorder %,
   Out of Stock Count, Overstock Count
   ------------------------------------------------------------------------------------- */
SELECT
    SUM(fi.stock_quantity)                                                            AS total_stock_units,
    SUM(fi.available_quantity)                                                        AS available_units,
    CAST(SUM(CASE WHEN fi.is_below_reorder = 1 THEN 1 ELSE 0 END) AS DECIMAL(12,2))
        / NULLIF(COUNT(*), 0) * 100                                                   AS pct_skus_below_reorder,
    SUM(CASE WHEN fi.inventory_status = 'Out of Stock' THEN 1 ELSE 0 END)             AS out_of_stock_count,
    SUM(CASE WHEN fi.inventory_status = 'Overstock' THEN 1 ELSE 0 END)                AS overstock_count
FROM gold.fact_inventory fi
JOIN gold.dim_products dp ON dp.product_key = fi.product_key
JOIN gold.dim_date dd     ON dd.date_key    = fi.date_key
WHERE dd.full_date = @snapshot_date
  AND (@category_filter IS NULL OR dp.category = @category_filter);


/* -------------------------------------------------------------------------------------
   CHART: Inventory Status Mix (donut) — share of SKU-store rows by status
   ------------------------------------------------------------------------------------- */
SELECT
    fi.inventory_status,
    COUNT(*) AS row_count
FROM gold.fact_inventory fi
JOIN gold.dim_products dp ON dp.product_key = fi.product_key
JOIN gold.dim_date dd     ON dd.date_key    = fi.date_key
WHERE dd.full_date = @snapshot_date
  AND (@category_filter IS NULL OR dp.category = @category_filter)
GROUP BY fi.inventory_status
ORDER BY row_count DESC;


/* -------------------------------------------------------------------------------------
   CHART: Stock vs Reorder Level by Category
   ------------------------------------------------------------------------------------- */
SELECT
    dp.category,
    SUM(fi.stock_quantity) AS stock_on_hand,
    SUM(fi.reorder_level)  AS reorder_level_total
FROM gold.fact_inventory fi
JOIN gold.dim_products dp ON dp.product_key = fi.product_key
JOIN gold.dim_date dd     ON dd.date_key    = fi.date_key
WHERE dd.full_date = @snapshot_date
  AND (@category_filter IS NULL OR dp.category = @category_filter)
GROUP BY dp.category
ORDER BY stock_on_hand DESC;


/* -------------------------------------------------------------------------------------
   CHART: Most Critical Below-Reorder SKUs (sorted by shortfall)
   ------------------------------------------------------------------------------------- */
SELECT TOP 8
    dp.product_name,
    dp.category,
    ds.store_name,
    fi.stock_quantity,
    fi.reorder_level,
    fi.reorder_level - fi.stock_quantity AS shortfall
FROM gold.fact_inventory fi
JOIN gold.dim_products dp ON dp.product_key = fi.product_key
JOIN gold.dim_stores ds   ON ds.store_key   = fi.store_key
JOIN gold.dim_date dd     ON dd.date_key    = fi.date_key
WHERE dd.full_date = @snapshot_date
  AND fi.is_below_reorder = 1
  AND (@category_filter IS NULL OR dp.category = @category_filter)
ORDER BY shortfall DESC;


/* -------------------------------------------------------------------------------------
   CHART: Stock Units by Store (ranked)
   ------------------------------------------------------------------------------------- */
SELECT TOP 8
    ds.store_name,
    SUM(fi.stock_quantity) AS stock_units
FROM gold.fact_inventory fi
JOIN gold.dim_stores ds   ON ds.store_key   = fi.store_key
JOIN gold.dim_products dp ON dp.product_key = fi.product_key
JOIN gold.dim_date dd     ON dd.date_key    = fi.date_key
WHERE dd.full_date = @snapshot_date
  AND (@category_filter IS NULL OR dp.category = @category_filter)
GROUP BY ds.store_name
ORDER BY stock_units DESC;
