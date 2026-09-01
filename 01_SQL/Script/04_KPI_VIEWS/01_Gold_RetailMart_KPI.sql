/* =====================================================================================
   RETAILMART GOLD LAYER
   KPI VIEW 01 — OVERALL RETAILMART KPIs
   -------------------------------------------------------------------------------------
   Grain: One row for the entire RetailMart business
===================================================================================== */

CREATE OR ALTER VIEW gold.vw_retailmart_kpis
AS

WITH SalesKPIs AS
(
    SELECT

        -- Sales
        SUM(sales_amount) AS TotalSales,

        -- Orders
        COUNT(DISTINCT order_id) AS TotalOrders,

        -- Quantity
        SUM(quantity) AS QuantitySold,

        -- Cost
        SUM(cost_amount) AS TotalCost,

        -- Profit
        SUM(profit_amount) AS TotalProfit,

        -- Customers
        COUNT(DISTINCT customer_key) AS CustomerCount

    FROM gold.fact_sales
),

ReturnKPIs AS
(
    SELECT

        COUNT(DISTINCT order_id) AS ReturnedOrders

    FROM gold.fact_returns
),

InventoryKPIs AS
(
    SELECT

        SUM(available_quantity) AS AvailableInventory,

        SUM(
            CASE
                WHEN available_quantity = 0
                THEN 1
                ELSE 0
            END
        ) AS StockOutCount,

        COUNT(*) AS TotalInventoryRecords

    FROM gold.fact_inventory
)

SELECT

    /* =========================================================
       SALES
    ========================================================= */

    s.TotalSales,

    s.TotalOrders,

    s.QuantitySold,

    /* =========================================================
       COST
    ========================================================= */

    s.TotalCost,

    /* =========================================================
       PROFIT
    ========================================================= */

    s.TotalProfit,

    CAST(
        s.TotalProfit * 100.0
        / NULLIF(s.TotalSales, 0)
        AS DECIMAL(10,2)
    ) AS ProfitMarginPct,

    /* =========================================================
       AVERAGE ORDER VALUE
    ========================================================= */

    CAST(
        s.TotalSales * 1.0
        / NULLIF(s.TotalOrders, 0)
        AS DECIMAL(18,2)
    ) AS AOV,

    /* =========================================================
       CUSTOMER
    ========================================================= */

    s.CustomerCount,

    /* =========================================================
       RETURN RATE
    ========================================================= */

    CAST(
        r.ReturnedOrders * 100.0
        / NULLIF(s.TotalOrders, 0)
        AS DECIMAL(10,2)
    ) AS ReturnRatePct,

    /* =========================================================
       INVENTORY
    ========================================================= */

    i.AvailableInventory,

    CAST(
        i.StockOutCount * 100.0
        / NULLIF(i.TotalInventoryRecords, 0)
        AS DECIMAL(10,2)
    ) AS StockOutRatePct

FROM SalesKPIs s

CROSS JOIN ReturnKPIs r

CROSS JOIN InventoryKPIs i;

GO

SELECT *
FROM gold.vw_retailmart_kpis;