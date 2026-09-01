/* =====================================================================================
   RETAILMART GOLD LAYER — CUSTOMER PERFORMANCE
   -------------------------------------------------------------------------------------
   Purpose:
       Provides customer-level performance metrics for Tableau / BI reporting.

   Grain:
       One row per customer.

   Dependencies:
       gold.fact_sales
       gold.dim_customer

   KPIs:
       - Total Sales
       - Total Orders
       - Quantity Purchased
       - Total Cost
       - Total Profit
       - Profit Margin %
       - AOV
       - First Purchase Date
       - Last Purchase Date
       - Customer Sales Rank
===================================================================================== */

CREATE OR ALTER VIEW gold.vw_customer_performance
AS

WITH customer_sales AS
(
    SELECT
        fs.customer_key,

        /* Sales */
        SUM(fs.sales_amount) AS total_sales,

        /* Orders */
        COUNT(DISTINCT fs.order_id) AS total_orders,

        /* Quantity */
        SUM(fs.quantity) AS quantity_purchased,

        /* Cost */
        SUM(fs.cost_amount) AS total_cost,

        /* Profit */
        SUM(fs.profit_amount) AS total_profit,

        /* Purchase Dates */
        MIN(d.full_date) AS first_purchase_date,
        MAX(d.full_date) AS last_purchase_date

    FROM gold.fact_sales AS fs

    INNER JOIN gold.dim_date AS d
        ON fs.date_key = d.date_key

    GROUP BY
        fs.customer_key
),

customer_metrics AS
(
    SELECT
        cs.customer_key,
        cs.total_sales,
        cs.total_orders,
        cs.quantity_purchased,
        cs.total_cost,
        cs.total_profit,
        cs.first_purchase_date,
        cs.last_purchase_date,

        /* Profit Margin % */
        CASE
            WHEN cs.total_sales = 0 THEN 0
            ELSE
                (cs.total_profit * 100.0)
                / cs.total_sales
        END AS profit_margin_pct,

        /* Average Order Value */
        CASE
            WHEN cs.total_orders = 0 THEN 0
            ELSE
                cs.total_sales * 1.0
                / cs.total_orders
        END AS aov

    FROM customer_sales AS cs
)

SELECT
    cm.customer_key,

    /* Customer Information */
    dc.customer_id,
    dc.customer_name,
    dc.city,
    dc.state,

    /* Performance Metrics */
    cm.total_sales,
    cm.total_orders,
    cm.quantity_purchased,
    cm.total_cost,
    cm.total_profit,
    cm.profit_margin_pct,
    cm.aov,

    /* Purchase Dates */
    cm.first_purchase_date,
    cm.last_purchase_date,

    /* Customer Rank */
    RANK() OVER
    (
        ORDER BY cm.total_sales DESC
    ) AS customer_sales_rank

FROM customer_metrics AS cm

INNER JOIN gold.dim_customers AS dc
    ON cm.customer_key = dc.customer_key;

GO

SELECT *
FROM gold.vw_customer_performance
ORDER BY customer_sales_rank;

-- top 10 customers
SELECT TOP 10
    customer_name,
    city,
    state,
    total_sales,
    total_orders,
    quantity_purchased,
    total_profit,
    profit_margin_pct,
    aov,
    first_purchase_date,
    last_purchase_date,
    customer_sales_rank
FROM gold.vw_customer_performance
ORDER BY customer_sales_rank;

-- validate the sales
SELECT
    SUM(total_sales) AS customer_view_sales
FROM gold.vw_customer_performance;

SELECT
    SUM(sales_amount) AS fact_sales_total
FROM gold.fact_sales;