/* =====================================================================================
   RETAILMART GOLD LAYER
   KPI VIEW 05 — STORE KPIs
   -------------------------------------------------------------------------------------
   Grain: One row per store
===================================================================================== */

CREATE OR ALTER VIEW gold.vw_store_kpis
AS

WITH StoreSales AS
(
    SELECT

        store_key,

        COUNT(DISTINCT order_id) AS TotalOrders,

        SUM(quantity) AS QuantitySold,

        SUM(sales_amount) AS StoreSales,

        SUM(cost_amount) AS StoreCost,

        SUM(profit_amount) AS StoreProfit,

        COUNT(DISTINCT customer_key) AS CustomerCount

    FROM gold.fact_sales

    GROUP BY

        store_key
),

StoreRanking AS
(
    SELECT

        s.store_id,

        s.store_name,

        s.city,

        s.state,

        ISNULL(ss.TotalOrders, 0) AS TotalOrders,

        ISNULL(ss.QuantitySold, 0) AS QuantitySold,

        ISNULL(ss.StoreSales, 0) AS StoreSales,

        ISNULL(ss.StoreCost, 0) AS StoreCost,

        ISNULL(ss.StoreProfit, 0) AS StoreProfit,

        ISNULL(ss.CustomerCount, 0) AS CustomerCount,

        /* Sales Ranking */

        RANK() OVER
        (
            ORDER BY
                ISNULL(ss.StoreSales, 0) DESC
        ) AS SalesRank,

        /* Profit Ranking */

        RANK() OVER
        (
            ORDER BY
                ISNULL(ss.StoreProfit, 0) DESC
        ) AS ProfitRank,

        /* Bottom Ranking */

        RANK() OVER
        (
            ORDER BY
                ISNULL(ss.StoreSales, 0) ASC
        ) AS BottomSalesRank

    FROM gold.dim_stores s

    LEFT JOIN StoreSales ss

        ON s.store_key = ss.store_key
)

SELECT

    store_id,

    store_name,

    city,

    state,

    TotalOrders,

    QuantitySold,

    CustomerCount,

    StoreSales,

    StoreCost,

    StoreProfit,

    /* Profit Margin */

    CAST(

        StoreProfit * 100.0
        / NULLIF(StoreSales, 0)

        AS DECIMAL(10,2)

    ) AS ProfitMarginPct,

    /* Sales per Store */

    StoreSales AS SalesPerStore,

    SalesRank,

    ProfitRank,

    BottomSalesRank,

    /* Top Store */

    CASE

        WHEN SalesRank = 1

        THEN 'Top Performing Store'

        ELSE 'Other'

    END AS StorePerformance,

    /* Bottom Store */

    CASE

        WHEN BottomSalesRank = 1

        THEN 'Bottom Performing Store'

        ELSE 'Other'

    END AS BottomStorePerformance

FROM StoreRanking;

GO