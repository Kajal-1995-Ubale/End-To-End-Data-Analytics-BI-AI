/* =====================================================================================
   RETAILMART GOLD LAYER — STORE PERFORMANCE
   -------------------------------------------------------------------------------------
   Purpose:
       Provides store-level performance metrics for Tableau / BI reporting.

   Grain:
       One row per store.

   Dependencies:
       gold.fact_sales
       gold.dim_store

   KPIs:
       - Total Sales
       - Total Orders
       - Quantity Sold
       - Total Cost
       - Total Profit
       - Profit Margin %
       - AOV
       - Store Sales Rank
===================================================================================== */

CREATE OR ALTER VIEW gold.vw_store_performance
AS

WITH store_sales AS
(
    SELECT
        fs.store_key,

        /* Sales */
        SUM(fs.sales_amount) AS total_sales,

        /* Orders */
        COUNT(DISTINCT fs.order_id) AS total_orders,

        /* Quantity */
        SUM(fs.quantity) AS quantity_sold,

        /* Cost */
        SUM(fs.cost_amount) AS total_cost,

        /* Profit */
        SUM(fs.profit_amount) AS total_profit

    FROM gold.fact_sales AS fs

    GROUP BY
        fs.store_key
),

store_metrics AS
(
    SELECT
        ss.store_key,
        ss.total_sales,
        ss.total_orders,
        ss.quantity_sold,
        ss.total_cost,
        ss.total_profit,

        /* Profit Margin % */
        CASE
            WHEN ss.total_sales = 0 THEN 0
            ELSE
                (ss.total_profit * 100.0)
                / ss.total_sales
        END AS profit_margin_pct,

        /* Average Order Value */
        CASE
            WHEN ss.total_orders = 0 THEN 0
            ELSE
                ss.total_sales * 1.0
                / ss.total_orders
        END AS aov

    FROM store_sales AS ss
)

SELECT
    sm.store_key,

    /* Store Information */
    ds.store_id,
    ds.store_name,
    ds.city,
    ds.state,

    /* Performance Metrics */
    sm.total_sales,
    sm.total_orders,
    sm.quantity_sold,
    sm.total_cost,
    sm.total_profit,
    sm.profit_margin_pct,
    sm.aov,

    /* Store Rank */
    RANK() OVER
    (
        ORDER BY sm.total_sales DESC
    ) AS store_sales_rank

FROM store_metrics AS sm

INNER JOIN gold.dim_stores AS ds
    ON sm.store_key = ds.store_key;

GO

SELECT *
FROM gold.vw_store_performance
ORDER BY store_sales_rank;

-- top 10 stores
SELECT TOP 10
    store_name,
    city,
    state,
    total_sales,
    total_orders,
    quantity_sold,
    total_profit,
    profit_margin_pct,
    aov,
    store_sales_rank
FROM gold.vw_store_performance
ORDER BY store_sales_rank;

-- validate sales
SELECT
    SUM(total_sales) AS store_view_sales
FROM gold.vw_store_performance;

-- fact validate sales
SELECT
    SUM(sales_amount) AS fact_sales_total
FROM gold.fact_sales;