/* =====================================================================================
   RETAILMART GOLD LAYER
   KPI VIEW 02 — SALES GROWTH
   -------------------------------------------------------------------------------------
   Grain: One row per month
===================================================================================== */
-- SELECT * FROM gold.dim_date;

CREATE OR ALTER VIEW gold.vw_sales_growth
AS

WITH MonthlySales AS
(
    SELECT

        d.year_num AS SalesYear,

        d.month_num AS SalesMonth,

        d.month_name AS MonthName,

        d.quarter_name AS SalesQuarter,

        SUM(f.sales_amount) AS MonthlySales

    FROM gold.fact_sales f

    INNER JOIN gold.dim_date d
        ON f.date_key = d.date_key

    GROUP BY

        d.year_num,
        d.month_num,
        d.month_name,
        d.quarter_name
),

SalesWithPrevious AS
(
    SELECT

        SalesYear,

        SalesMonth,

        MonthName,

        SalesQuarter,

        MonthlySales,

        /* Previous Month Sales */

        LAG(MonthlySales) OVER
        (
            ORDER BY
                SalesYear,
                SalesMonth
        ) AS PreviousMonthSales,

        /* Previous Year Sales */

        LAG(MonthlySales, 12) OVER
        (
            ORDER BY
                SalesYear,
                SalesMonth
        ) AS PreviousYearSales

    FROM MonthlySales
)

SELECT

    SalesYear,

    SalesMonth,

    MonthName,

    CONCAT('Q', SalesQuarter) AS QuarterName,

    MonthlySales,

    PreviousMonthSales,

    /* =====================================================
       MoM Growth %
    ===================================================== */

    CAST
    (
        (MonthlySales - PreviousMonthSales) * 100.0
        / NULLIF(PreviousMonthSales, 0)
        AS DECIMAL(10,2)
    ) AS MoMGrowthPct,

    PreviousYearSales,

    /* =====================================================
       YoY Growth %
    ===================================================== */

    CAST
    (
        (MonthlySales - PreviousYearSales) * 100.0
        / NULLIF(PreviousYearSales, 0)
        AS DECIMAL(10,2)
    ) AS YoYGrowthPct

FROM SalesWithPrevious;

GO

SELECT *
FROM gold.vw_sales_growth
ORDER BY SalesYear, SalesMonth;

/*
/* =====================================================================================
   SALES PERIOD SUMMARY
===================================================================================== */

CREATE OR ALTER VIEW gold.vw_sales_period_summary
AS

SELECT

    /* Daily */

    CAST(sale_date AS DATE) AS SaleDate,

    /* Year */

    YEAR(sale_date) AS SalesYear,

    /* Month */

    MONTH(sale_date) AS SalesMonth,

    DATENAME(
        MONTH,
        sale_date
    ) AS MonthName,

    /* Quarter */

    DATEPART(
        QUARTER,
        sale_date
    ) AS SalesQuarter,

    /* Sales */

    SUM(sales_amount) AS TotalSales,

    /* Orders */

    COUNT(DISTINCT order_id) AS TotalOrders,

    /* Quantity */

    SUM(quantity) AS QuantitySold,

    /* Profit */

    SUM(profit_amount) AS TotalProfit

FROM gold.fact_sales

GROUP BY

    CAST(sale_date AS DATE),

    YEAR(sale_date),

    MONTH(sale_date),

    DATENAME(MONTH, sale_date),

    DATEPART(QUARTER, sale_date);

GO
*/