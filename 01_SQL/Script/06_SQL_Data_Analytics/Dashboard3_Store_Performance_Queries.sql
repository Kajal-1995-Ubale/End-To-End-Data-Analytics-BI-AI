/* =====================================================================================
   DASHBOARD 3 — STORE PERFORMANCE
   -----------------------------------------------------------------------------------
   Every query below answers one KPI card or chart on the Store Performance dashboard.
   Source: gold.fact_sales, gold.fact_inventory, gold.dim_stores, gold.dim_employees,
   gold.dim_products, gold.dim_date.
   Engine: Microsoft SQL Server (T-SQL).

   Set @region_filter to a region name to reproduce the dashboard's Region filter;
   leave NULL for "All regions."
   ===================================================================================== */

DECLARE @period_start  DATE        = DATEFROMPARTS(YEAR(GETDATE()), 1, 1);   -- YTD example
DECLARE @period_end    DATE        = CAST(GETDATE() AS DATE);
DECLARE @region_filter VARCHAR(50) = NULL;


/* -------------------------------------------------------------------------------------
   KPI CARDS: Total Store Sales, Sales / Sq Ft, Sales / Employee, Store Profit Margin %
   (aggregated across all stores in scope)
   ------------------------------------------------------------------------------------- */
WITH store_sales AS (
    SELECT ds.store_key, ds.square_feet,
           SUM(fs.sales_amount)  AS sales,
           SUM(fs.profit_amount) AS profit
    FROM gold.fact_sales fs
    JOIN gold.dim_stores ds ON ds.store_key = fs.store_key
    JOIN gold.dim_date dd   ON dd.date_key  = fs.date_key
    WHERE dd.full_date BETWEEN @period_start AND @period_end
      AND (@region_filter IS NULL OR ds.region = @region_filter)
    GROUP BY ds.store_key, ds.square_feet
),
store_headcount AS (
    SELECT ds.store_key, COUNT(DISTINCT de.employee_key) AS employee_count
    FROM gold.dim_stores ds
    LEFT JOIN gold.dim_employees de
           ON de.store_key = ds.store_key AND de.employment_status = 'Active'
    WHERE (@region_filter IS NULL OR ds.region = @region_filter)
    GROUP BY ds.store_key
)
SELECT
    SUM(ss.sales)                                    AS total_store_sales,
    SUM(ss.sales) / NULLIF(SUM(ss.square_feet), 0)   AS sales_per_sqft,
    SUM(ss.sales) / NULLIF(SUM(sh.employee_count), 0) AS sales_per_employee,
    SUM(ss.profit) / NULLIF(SUM(ss.sales), 0) * 100  AS store_profit_margin_pct
FROM store_sales ss
JOIN store_headcount sh ON sh.store_key = ss.store_key;


/* -------------------------------------------------------------------------------------
   PANEL: Store Ranking Table
   (Store | Region | Sales | Margin % | Sales/SqFt | YoY — matches the table exactly)
   ------------------------------------------------------------------------------------- */
DECLARE @prior_start DATE = DATEADD(YEAR, -1, @period_start);
DECLARE @prior_end   DATE = DATEADD(YEAR, -1, @period_end);

WITH current_yr AS (
    SELECT ds.store_key, ds.store_name, ds.region, ds.square_feet,
           SUM(fs.sales_amount)  AS sales,
           SUM(fs.profit_amount) AS profit
    FROM gold.fact_sales fs
    JOIN gold.dim_stores ds ON ds.store_key = fs.store_key
    JOIN gold.dim_date dd   ON dd.date_key  = fs.date_key
    WHERE dd.full_date BETWEEN @period_start AND @period_end
      AND (@region_filter IS NULL OR ds.region = @region_filter)
    GROUP BY ds.store_key, ds.store_name, ds.region, ds.square_feet
),
prior_yr AS (
    SELECT ds.store_key, SUM(fs.sales_amount) AS sales
    FROM gold.fact_sales fs
    JOIN gold.dim_stores ds ON ds.store_key = fs.store_key
    JOIN gold.dim_date dd   ON dd.date_key  = fs.date_key
    WHERE dd.full_date BETWEEN @prior_start AND @prior_end
      AND (@region_filter IS NULL OR ds.region = @region_filter)
    GROUP BY ds.store_key
)
SELECT
    c.store_name,
    c.region,
    c.sales,
    c.profit / NULLIF(c.sales, 0) * 100                          AS margin_pct,
    c.sales / NULLIF(c.square_feet, 0)                           AS sales_per_sqft,
    (c.sales - p.sales) / NULLIF(p.sales, 0) * 100                AS yoy_pct
FROM current_yr c
LEFT JOIN prior_yr p ON p.store_key = c.store_key
ORDER BY c.sales DESC;


/* -------------------------------------------------------------------------------------
   CHART: Sales by Store (ranked)
   ------------------------------------------------------------------------------------- */
SELECT TOP 8
    ds.store_name,
    ds.region,
    SUM(fs.sales_amount) AS store_sales
FROM gold.fact_sales fs
JOIN gold.dim_stores ds ON ds.store_key = fs.store_key
JOIN gold.dim_date dd   ON dd.date_key  = fs.date_key
WHERE dd.full_date BETWEEN @period_start AND @period_end
  AND (@region_filter IS NULL OR ds.region = @region_filter)
GROUP BY ds.store_name, ds.region
ORDER BY store_sales DESC;


/* -------------------------------------------------------------------------------------
   CHART: Inventory Health Heatmap — Store × Category, % of SKUs below reorder
   ------------------------------------------------------------------------------------- */
SELECT
    ds.store_name,
    dp.category,
    COUNT(*)                                                                       AS total_sku_rows,
    SUM(CASE WHEN fi.is_below_reorder = 1 THEN 1 ELSE 0 END)                       AS below_reorder_rows,
    CAST(SUM(CASE WHEN fi.is_below_reorder = 1 THEN 1 ELSE 0 END) AS DECIMAL(12,2))
        / NULLIF(COUNT(*), 0) * 100                                                AS pct_below_reorder
FROM gold.fact_inventory fi
JOIN gold.dim_stores ds   ON ds.store_key   = fi.store_key
JOIN gold.dim_products dp ON dp.product_key = fi.product_key
WHERE (@region_filter IS NULL OR ds.region = @region_filter)
GROUP BY ds.store_name, dp.category
ORDER BY ds.store_name, dp.category;
