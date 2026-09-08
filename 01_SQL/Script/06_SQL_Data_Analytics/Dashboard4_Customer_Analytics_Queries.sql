/* =====================================================================================
   DASHBOARD 4 — CUSTOMER ANALYTICS
   -----------------------------------------------------------------------------------
   Every query below answers one KPI card or chart on the Customer Analytics dashboard.
   Source: gold.fact_sales, gold.fact_returns, gold.dim_customers, gold.dim_date.
   Engine: Microsoft SQL Server (T-SQL).

   Set @segment_filter to a customer_segment value to reproduce the dashboard's
   Segment filter / "click a donut slice" behavior; leave NULL for "All segments."
   ===================================================================================== */

DECLARE @period_start   DATE         = DATEFROMPARTS(YEAR(GETDATE()), 1, 1);   -- YTD example
DECLARE @period_end     DATE         = CAST(GETDATE() AS DATE);
DECLARE @segment_filter VARCHAR(50)  = NULL;


/* -------------------------------------------------------------------------------------
   Shared building block: each customer's first-ever order date, used to classify
   New vs Returning below. Computed once here as a CTE pattern — repeat this CTE (or
   materialize it as a view) in each query below that needs it.
   ------------------------------------------------------------------------------------- */
-- CREATE VIEW gold.vw_customer_first_order AS
-- SELECT customer_key, MIN(order_date_actual) AS first_order_date
-- FROM (
--     SELECT fs.customer_key, dd.full_date AS order_date_actual
--     FROM gold.fact_sales fs JOIN gold.dim_date dd ON dd.date_key = fs.date_key
-- ) x
-- GROUP BY customer_key;
-- (Uncomment and run once if you want this as a reusable view instead of a repeated CTE.)


/* -------------------------------------------------------------------------------------
   KPI CARDS: Total Customers, New Customers, Repeat Purchase Rate %, AOV
   ------------------------------------------------------------------------------------- */
WITH first_order AS (
    SELECT fs.customer_key, MIN(dd.full_date) AS first_order_date
    FROM gold.fact_sales fs
    JOIN gold.dim_date dd ON dd.date_key = fs.date_key
    GROUP BY fs.customer_key
),
scoped_sales AS (
    SELECT fs.order_id, fs.customer_key, fs.sales_amount, dd.full_date
    FROM gold.fact_sales fs
    JOIN gold.dim_date dd ON dd.date_key = fs.date_key
    JOIN gold.dim_customers dc ON dc.customer_key = fs.customer_key
    WHERE dd.full_date BETWEEN @period_start AND @period_end
      AND (@segment_filter IS NULL OR dc.customer_segment = @segment_filter)
),
customer_order_counts AS (
    SELECT customer_key, COUNT(DISTINCT order_id) AS order_count
    FROM scoped_sales
    GROUP BY customer_key
)
SELECT
    COUNT(DISTINCT ss.customer_key)                                                        AS total_customers,
    COUNT(DISTINCT CASE WHEN fo.first_order_date BETWEEN @period_start AND @period_end
                         THEN ss.customer_key END)                                          AS new_customers,
    CAST(SUM(CASE WHEN coc.order_count > 1 THEN 1 ELSE 0 END) AS DECIMAL(12,2))
        / NULLIF(COUNT(DISTINCT ss.customer_key), 0) * 100                                  AS repeat_purchase_rate_pct,
    SUM(ss.sales_amount) / NULLIF(COUNT(DISTINCT ss.order_id), 0)                            AS average_order_value
FROM scoped_sales ss
JOIN first_order fo ON fo.customer_key = ss.customer_key
JOIN customer_order_counts coc ON coc.customer_key = ss.customer_key;


/* -------------------------------------------------------------------------------------
   CHART: New vs Returning Customers Over Time (stacked area, trailing 12 months)
   ------------------------------------------------------------------------------------- */
WITH first_order AS (
    SELECT fs.customer_key, MIN(dd.full_date) AS first_order_date
    FROM gold.fact_sales fs
    JOIN gold.dim_date dd ON dd.date_key = fs.date_key
    GROUP BY fs.customer_key
)
SELECT
    dd.year_num, dd.month_num, dd.month_name,
    COUNT(DISTINCT CASE WHEN fo.first_order_date = dd.full_date THEN fs.customer_key END) AS new_customers,
    COUNT(DISTINCT CASE WHEN fo.first_order_date < dd.full_date THEN fs.customer_key END)  AS returning_customers
FROM gold.fact_sales fs
JOIN gold.dim_date dd ON dd.date_key = fs.date_key
JOIN first_order fo   ON fo.customer_key = fs.customer_key
WHERE dd.full_date >= DATEADD(MONTH, -11, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1))
  AND dd.full_date <  DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1))
GROUP BY dd.year_num, dd.month_num, dd.month_name
ORDER BY dd.year_num, dd.month_num;


/* -------------------------------------------------------------------------------------
   CHART: Revenue by Segment
   ------------------------------------------------------------------------------------- */
SELECT
    dc.customer_segment,
    SUM(fs.sales_amount) AS segment_sales
FROM gold.fact_sales fs
JOIN gold.dim_customers dc ON dc.customer_key = fs.customer_key
JOIN gold.dim_date dd      ON dd.date_key     = fs.date_key
WHERE dd.full_date BETWEEN @period_start AND @period_end
GROUP BY dc.customer_segment
ORDER BY segment_sales DESC;


/* -------------------------------------------------------------------------------------
   CHART: Revenue by Age Band × Gender
   ------------------------------------------------------------------------------------- */
SELECT
    dc.age_band,
    dc.gender,
    SUM(fs.sales_amount) AS revenue
FROM gold.fact_sales fs
JOIN gold.dim_customers dc ON dc.customer_key = fs.customer_key
JOIN gold.dim_date dd      ON dd.date_key     = fs.date_key
WHERE dd.full_date BETWEEN @period_start AND @period_end
  AND dc.age_band IS NOT NULL
  AND dc.gender IS NOT NULL
GROUP BY dc.age_band, dc.gender
ORDER BY dc.age_band, dc.gender;


/* -------------------------------------------------------------------------------------
   CHART: Top 20 Customers by Lifetime Value (all-time, not scoped to the date filter —
   LTV is inherently cumulative)
   ------------------------------------------------------------------------------------- */
SELECT TOP 20
    dc.customer_name,
    dc.customer_segment,
    SUM(fs.sales_amount) AS lifetime_value
FROM gold.fact_sales fs
JOIN gold.dim_customers dc ON dc.customer_key = fs.customer_key
WHERE (@segment_filter IS NULL OR dc.customer_segment = @segment_filter)
GROUP BY dc.customer_name, dc.customer_segment
ORDER BY lifetime_value DESC;


/* -------------------------------------------------------------------------------------
   CHART: Return Rate by Segment
   ------------------------------------------------------------------------------------- */
SELECT
    dc.customer_segment,
    CAST(SUM(fr.return_quantity) AS DECIMAL(12,2)) / NULLIF(SUM(fs.quantity), 0) * 100 AS return_rate_pct
FROM gold.fact_sales fs
JOIN gold.dim_customers dc ON dc.customer_key = fs.customer_key
JOIN gold.dim_date dd      ON dd.date_key     = fs.date_key
LEFT JOIN gold.fact_returns fr ON fr.sales_key = fs.sales_key
WHERE dd.full_date BETWEEN @period_start AND @period_end
GROUP BY dc.customer_segment
ORDER BY return_rate_pct DESC;
