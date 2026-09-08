/* =====================================================================================
   DASHBOARD 2 — PRODUCT PERFORMANCE
   -----------------------------------------------------------------------------------
   Every query below answers one KPI card or chart on the Product Performance dashboard.
   Source: gold.fact_sales, gold.fact_inventory, gold.dim_products, gold.dim_date.
   Engine: Microsoft SQL Server (T-SQL).

   Set @category_filter to a category name to reproduce the dashboard's Category
   filter / "click a treemap tile" behavior; leave NULL for "All categories."
   ===================================================================================== */

DECLARE @period_start    DATE        = DATEFROMPARTS(YEAR(GETDATE()), 1, 1);   -- YTD example
DECLARE @period_end      DATE        = CAST(GETDATE() AS DATE);
DECLARE @category_filter VARCHAR(100) = NULL;


/* -------------------------------------------------------------------------------------
   KPI CARDS: Revenue (selected scope), Units Sold, Return Rate %
   ------------------------------------------------------------------------------------- */
SELECT
    SUM(fs.sales_amount)                                                              AS revenue,
    SUM(fs.quantity)                                                                  AS units_sold,
    CAST(SUM(fr.return_quantity) AS DECIMAL(12,2)) / NULLIF(SUM(fs.quantity), 0) * 100 AS return_rate_pct
FROM gold.fact_sales fs
JOIN gold.dim_products dp ON dp.product_key = fs.product_key
JOIN gold.dim_date dd     ON dd.date_key    = fs.date_key
LEFT JOIN gold.fact_returns fr ON fr.sales_key = fs.sales_key
WHERE dd.full_date BETWEEN @period_start AND @period_end
  AND (@category_filter IS NULL OR dp.category = @category_filter);


/* -------------------------------------------------------------------------------------
   KPI CARD: SKUs Below Reorder %  (share of product-store rows currently below reorder)
   ------------------------------------------------------------------------------------- */
SELECT
    CAST(SUM(CASE WHEN fi.is_below_reorder = 1 THEN 1 ELSE 0 END) AS DECIMAL(12,2))
        / NULLIF(COUNT(*), 0) * 100 AS pct_skus_below_reorder
FROM gold.fact_inventory fi
JOIN gold.dim_products dp ON dp.product_key = fi.product_key
WHERE (@category_filter IS NULL OR dp.category = @category_filter);


/* -------------------------------------------------------------------------------------
   CHART: Category Treemap — size = sales, color = margin %
   ------------------------------------------------------------------------------------- */
SELECT
    dp.category,
    SUM(fs.sales_amount)                                          AS category_sales,
    SUM(fs.profit_amount) / NULLIF(SUM(fs.sales_amount), 0) * 100 AS category_margin_pct
FROM gold.fact_sales fs
JOIN gold.dim_products dp ON dp.product_key = fs.product_key
JOIN gold.dim_date dd     ON dd.date_key    = fs.date_key
WHERE dd.full_date BETWEEN @period_start AND @period_end
GROUP BY dp.category
ORDER BY category_sales DESC;


/* -------------------------------------------------------------------------------------
   CHART: Top N Products by Sales
   ------------------------------------------------------------------------------------- */
SELECT TOP 8
    dp.product_name,
    dp.category,
    SUM(fs.sales_amount) AS product_sales
FROM gold.fact_sales fs
JOIN gold.dim_products dp ON dp.product_key = fs.product_key
JOIN gold.dim_date dd     ON dd.date_key    = fs.date_key
WHERE dd.full_date BETWEEN @period_start AND @period_end
  AND (@category_filter IS NULL OR dp.category = @category_filter)
GROUP BY dp.product_name, dp.category
ORDER BY product_sales DESC;


/* -------------------------------------------------------------------------------------
   CHART: Bottom N Products by Margin
   (realized margin from actual sales, weighted — not the list-price margin_pct on
   dim_products, since actuals reflect discounts already applied)
   ------------------------------------------------------------------------------------- */
SELECT TOP 8
    dp.product_name,
    dp.category,
    SUM(fs.sales_amount)                                          AS product_sales,
    SUM(fs.profit_amount) / NULLIF(SUM(fs.sales_amount), 0) * 100 AS realized_margin_pct
FROM gold.fact_sales fs
JOIN gold.dim_products dp ON dp.product_key = fs.product_key
JOIN gold.dim_date dd     ON dd.date_key    = fs.date_key
WHERE dd.full_date BETWEEN @period_start AND @period_end
  AND (@category_filter IS NULL OR dp.category = @category_filter)
GROUP BY dp.product_name, dp.category
HAVING SUM(fs.sales_amount) > 0
ORDER BY realized_margin_pct ASC;


/* -------------------------------------------------------------------------------------
   CHART: Which SKUs need reordering now? (sorted by shortfall)
   ------------------------------------------------------------------------------------- */
SELECT TOP 8
    dp.product_name,
    dp.category,
    fi.stock_quantity,
    fi.reorder_level,
    fi.reorder_level - fi.stock_quantity AS shortfall
FROM gold.fact_inventory fi
JOIN gold.dim_products dp ON dp.product_key = fi.product_key
WHERE fi.is_below_reorder = 1
  AND (@category_filter IS NULL OR dp.category = @category_filter)
ORDER BY shortfall DESC;
