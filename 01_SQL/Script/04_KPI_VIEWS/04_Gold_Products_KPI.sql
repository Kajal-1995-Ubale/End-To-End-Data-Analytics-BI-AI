/* =====================================================================================
   RETAILMART GOLD LAYER
   KPI VIEW 04 — PRODUCT KPIs
   -------------------------------------------------------------------------------------
   Grain: One row per product
===================================================================================== */

CREATE OR ALTER VIEW gold.vw_product_kpis
AS

WITH ProductSales AS
(
    SELECT

        product_key,

        SUM(quantity) AS QuantitySold,

        SUM(sales_amount) AS TotalSales,

        SUM(cost_amount) AS TotalCost,

        SUM(profit_amount) AS TotalProfit,

        COUNT(DISTINCT order_id) AS TotalOrders

    FROM gold.fact_sales

    GROUP BY

        product_key
),

ProductRanking AS
(
    SELECT

        p.product_key,

        p.product_name,

        p.category,

        ISNULL(ps.QuantitySold, 0) AS QuantitySold,

        ISNULL(ps.TotalSales, 0) AS TotalSales,

        ISNULL(ps.TotalCost, 0) AS TotalCost,

        ISNULL(ps.TotalProfit, 0) AS TotalProfit,

        ISNULL(ps.TotalOrders, 0) AS TotalOrders,

        /* Sales Rank */

        RANK() OVER
        (
            ORDER BY
                ISNULL(ps.TotalSales, 0) DESC
        ) AS SalesRank,

        /* Profit Rank */

        RANK() OVER
        (
            ORDER BY
                ISNULL(ps.TotalProfit, 0) DESC
        ) AS ProfitRank,

        /* Bottom Sales Rank */

        RANK() OVER
        (
            ORDER BY
                ISNULL(ps.TotalSales, 0) ASC
        ) AS BottomSalesRank

    FROM gold.dim_products p

    LEFT JOIN ProductSales ps

        ON p.product_key = ps.product_key
)

SELECT

    product_key,

    product_name,

    category,

    QuantitySold,

    TotalOrders,

    TotalSales,

    TotalCost,

    TotalProfit,

    /* Profit Margin */

    CAST(

        TotalProfit * 100.0
        / NULLIF(TotalSales, 0)

        AS DECIMAL(10,2)

    ) AS ProfitMarginPct,

    SalesRank,

    ProfitRank,

    BottomSalesRank,

    /* Top Product Flag */

    CASE

        WHEN SalesRank <= 10

        THEN 'Top Product'

        ELSE 'Other'

    END AS ProductPerformance,

    /* Bottom Product Flag */

    CASE

        WHEN BottomSalesRank <= 10

        THEN 'Bottom Product'

        ELSE 'Other'

    END AS BottomProductFlag

FROM ProductRanking;

GO