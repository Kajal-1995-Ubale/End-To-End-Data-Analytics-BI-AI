/* =====================================================================================
   DASHBOARD 1 — EXECUTIVE SALES
   -----------------------------------------------------------------------------------
   Every query below answers one KPI card or chart on the Executive Sales dashboard.
   Source: gold.fact_sales, gold.dim_date, gold.dim_stores, gold.dim_products.
   Engine: Microsoft SQL Server (T-SQL).

   DATE SCOPE
   Adjust @period_start / @period_end to match the dashboard's Date Range filter
   (Year to Date / Quarter to Date / Last 30 Days). @prior_start / @prior_end is the
   same window one year earlier, used for every YoY delta chip.
   ===================================================================================== */

DECLARE @period_start DATE = DATEFROMPARTS(YEAR(GETDATE()), 1, 1);   -- YTD example; swap for QTD/Last 30 Days
DECLARE @period_end   DATE = CAST(GETDATE() AS DATE);
DECLARE @prior_start  DATE = DATEADD(YEAR, -1, @period_start);
DECLARE @prior_end    DATE = DATEADD(YEAR, -1, @period_end);


/* -------------------------------------------------------------------------------------
   KPI CARDS: Total Sales, Total Profit, Profit Margin %, Total Orders
   ------------------------------------------------------------------------------------- */
SELECT
    SUM(fs.sales_amount)                                            AS total_sales,
    SUM(fs.profit_amount)                                           AS total_profit,
    SUM(fs.profit_amount) / NULLIF(SUM(fs.sales_amount), 0) * 100   AS profit_margin_pct,
    COUNT(DISTINCT fs.order_id)                                     AS total_orders
FROM gold.fact_sales fs
JOIN gold.dim_date dd ON dd.date_key = fs.date_key
WHERE dd.full_date BETWEEN @period_start AND @period_end;

-- Same metrics for the prior-year window, to compute the YoY delta chips client-side
-- (or wrap both in a CTE and subtract, as shown at the very end of this script).
SELECT
    SUM(fs.sales_amount)                                            AS total_sales_prior,
    SUM(fs.profit_amount)                                           AS total_profit_prior,
    SUM(fs.profit_amount) / NULLIF(SUM(fs.sales_amount), 0) * 100   AS profit_margin_pct_prior,
    COUNT(DISTINCT fs.order_id)                                     AS total_orders_prior
FROM gold.fact_sales fs
JOIN gold.dim_date dd ON dd.date_key = fs.date_key
WHERE dd.full_date BETWEEN @prior_start AND @prior_end;


/* -------------------------------------------------------------------------------------
   KPI CARD: Return Rate % (returned units / sold units)
   ------------------------------------------------------------------------------------- */
SELECT
    CAST(SUM(fr.return_quantity) AS DECIMAL(12,2)) / NULLIF(SUM(fs.quantity), 0) * 100 AS return_rate_pct
FROM gold.fact_sales fs
JOIN gold.dim_date dd ON dd.date_key = fs.date_key
LEFT JOIN gold.fact_returns fr
       ON fr.sales_key = fs.sales_key
      AND fr.date_key IN (SELECT date_key FROM gold.dim_date WHERE full_date BETWEEN @period_start AND @period_end)
WHERE dd.full_date BETWEEN @period_start AND @period_end;


/* -------------------------------------------------------------------------------------
   CHART: Monthly Sales & Profit Trend (trailing 12 months, dual-axis)
   ------------------------------------------------------------------------------------- */
SELECT
    dd.year_num,
    dd.month_num,
    dd.month_name,
    SUM(fs.sales_amount)                                           AS monthly_sales,
    SUM(fs.profit_amount) / NULLIF(SUM(fs.sales_amount), 0) * 100  AS monthly_profit_margin_pct
FROM gold.fact_sales fs
JOIN gold.dim_date dd ON dd.date_key = fs.date_key
WHERE dd.full_date >= DATEADD(MONTH, -11, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1))
  AND dd.full_date <  DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1))
GROUP BY dd.year_num, dd.month_num, dd.month_name
ORDER BY dd.year_num, dd.month_num;


/* -------------------------------------------------------------------------------------
   CHART: Sales by Region
   ------------------------------------------------------------------------------------- */
SELECT
    ds.region,
    SUM(fs.sales_amount) AS region_sales
FROM gold.fact_sales fs
JOIN gold.dim_stores ds ON ds.store_key = fs.store_key
JOIN gold.dim_date dd   ON dd.date_key  = fs.date_key
WHERE dd.full_date BETWEEN @period_start AND @period_end
GROUP BY ds.region
ORDER BY region_sales DESC;


/* -------------------------------------------------------------------------------------
   CHART: Top 10 Stores by Sales
   (Pass @region_filter = NULL for "All regions", or a region name to match the
   dashboard's click-to-filter behavior.)
   ------------------------------------------------------------------------------------- */
DECLARE @region_filter VARCHAR(50) = NULL;

SELECT TOP 10
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
   CHART: Sales by Category
   ------------------------------------------------------------------------------------- */
SELECT
    dp.category,
    SUM(fs.sales_amount) AS category_sales
FROM gold.fact_sales fs
JOIN gold.dim_products dp ON dp.product_key = fs.product_key
JOIN gold.dim_date dd     ON dd.date_key    = fs.date_key
WHERE dd.full_date BETWEEN @period_start AND @period_end
GROUP BY dp.category
ORDER BY category_sales DESC;


/* -------------------------------------------------------------------------------------
   CHART: Top 10 Products by Sales
   ------------------------------------------------------------------------------------- */
SELECT TOP 10
    dp.product_name,
    dp.category,
    SUM(fs.sales_amount) AS product_sales
FROM gold.fact_sales fs
JOIN gold.dim_products dp ON dp.product_key = fs.product_key
JOIN gold.dim_date dd     ON dd.date_key    = fs.date_key
WHERE dd.full_date BETWEEN @period_start AND @period_end
GROUP BY dp.product_name, dp.category
ORDER BY product_sales DESC;


/* -------------------------------------------------------------------------------------
   BONUS: All 4 headline KPIs with their YoY delta computed in one shot
   (this is the single query that feeds every KPI card + its delta chip at once)
   ------------------------------------------------------------------------------------- */
WITH current_period AS (
    SELECT SUM(fs.sales_amount) AS total_sales, SUM(fs.profit_amount) AS total_profit,
           COUNT(DISTINCT fs.order_id) AS total_orders
    FROM gold.fact_sales fs JOIN gold.dim_date dd ON dd.date_key = fs.date_key
    WHERE dd.full_date BETWEEN @period_start AND @period_end
),
prior_period AS (
    SELECT SUM(fs.sales_amount) AS total_sales, SUM(fs.profit_amount) AS total_profit,
           COUNT(DISTINCT fs.order_id) AS total_orders
    FROM gold.fact_sales fs JOIN gold.dim_date dd ON dd.date_key = fs.date_key
    WHERE dd.full_date BETWEEN @prior_start AND @prior_end
)
SELECT
    c.total_sales, c.total_profit,
    c.total_profit / NULLIF(c.total_sales, 0) * 100 AS profit_margin_pct,
    c.total_orders,
    (c.total_sales  - p.total_sales)  / NULLIF(p.total_sales, 0)  * 100 AS sales_yoy_pct,
    (c.total_profit - p.total_profit) / NULLIF(p.total_profit, 0) * 100 AS profit_yoy_pct,
    (c.total_orders - p.total_orders) / NULLIF(CAST(p.total_orders AS DECIMAL(12,2)), 0) * 100 AS orders_yoy_pct
FROM current_period c CROSS JOIN prior_period p;
