/* =====================================================================================
   RETAILMART GOLD LAYER — PRODUCT PERFORMANCE
   -------------------------------------------------------------------------------------
   Purpose:
       Provides product-level performance metrics for Tableau / BI reporting.

   Grain:
       One row per product.

   Dependencies:
       gold.fact_sales
       gold.dim_product

   KPIs:
       - Total Sales
       - Total Orders
       - Quantity Sold
       - Total Cost
       - Total Profit
       - Profit Margin %
       - AOV
       - Product Rank
===================================================================================== */

CREATE OR ALTER VIEW gold.vw_product_performance
AS

WITH product_sales AS
(
    SELECT
        fs.product_key,

        /* Sales Metrics */
        SUM(fs.sales_amount) AS total_sales,

        /* Order Metrics */
        COUNT(DISTINCT fs.order_id) AS total_orders,

        /* Quantity Metrics */
        SUM(fs.quantity) AS quantity_sold,

        /* Cost */
        SUM(fs.cost_amount) AS total_cost,

        /* Profit */
        SUM(fs.profit_amount) AS total_profit

    FROM gold.fact_sales AS fs

    GROUP BY
        fs.product_key
),

product_metrics AS
(
    SELECT
        ps.product_key,
        ps.total_sales,
        ps.total_orders,
        ps.quantity_sold,
        ps.total_cost,
        ps.total_profit,

        /* Profit Margin % */
        CASE
            WHEN ps.total_sales = 0 THEN 0
            ELSE
                (ps.total_profit * 100.0)
                / ps.total_sales
        END AS profit_margin_pct,

        /* Average Order Value */
        CASE
            WHEN ps.total_orders = 0 THEN 0
            ELSE
                ps.total_sales * 1.0
                / ps.total_orders
        END AS aov

    FROM product_sales AS ps
)

SELECT
    pm.product_key,

    /* Product Information */
    dp.product_id,
    dp.product_name,
    dp.category,
    dp.subcategory,
    dp.brand,

    /* Performance Metrics */
    pm.total_sales,
    pm.total_orders,
    pm.quantity_sold,
    pm.total_cost,
    pm.total_profit,
    pm.profit_margin_pct,
    pm.aov,

    /* Product Rank */
    RANK() OVER
    (
        ORDER BY pm.total_sales DESC
    ) AS product_sales_rank

FROM product_metrics AS pm

INNER JOIN gold.dim_products AS dp
    ON pm.product_key = dp.product_key;

GO

SELECT *
FROM gold.vw_product_performance
ORDER BY product_sales_rank;

-- top 1o products
SELECT TOP 10
    product_name,
    category,
    total_sales,
    total_orders,
    quantity_sold,
    total_profit,
    profit_margin_pct,
    aov,
    product_sales_rank
FROM gold.vw_product_performance
ORDER BY product_sales_rank;

-- total sales compare with facts

SELECT
    SUM(total_sales) AS product_view_sales
FROM gold.vw_product_performance;

SELECT
    SUM(sales_amount) AS fact_sales_total
FROM gold.fact_sales;

-- top 
SELECT TOP 5 *
FROM gold.fact_sales;

SELECT TOP 5 *
FROM gold.dim_products;