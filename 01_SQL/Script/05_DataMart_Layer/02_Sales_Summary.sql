/* =====================================================================================
   RETAILMART MART LAYER — SALES SUMMARY
   -------------------------------------------------------------------------------------
   Purpose:
       Tableau-ready sales summary.

   Grain:
       One row per Date + Store + Product.
===================================================================================== */

CREATE OR ALTER VIEW mart.vw_sales_summary
AS

SELECT
    fs.date_key,
    d.full_date,

    fs.store_key,
    ds.store_id,
    ds.store_name,
    ds.city,
    ds.state,

    fs.product_key,
    dp.product_id,
    dp.product_name,
    dp.category,
    dp.subcategory,
    dp.brand,

    SUM(fs.quantity) AS quantity_sold,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    SUM(fs.sales_amount) AS total_sales,
    SUM(fs.cost_amount) AS total_cost,
    SUM(fs.profit_amount) AS total_profit,

    CASE
        WHEN SUM(fs.sales_amount) = 0 THEN 0
        ELSE
            SUM(fs.profit_amount) * 100.0
            / SUM(fs.sales_amount)
    END AS profit_margin_pct

FROM gold.fact_sales fs

INNER JOIN gold.dim_date d
    ON fs.date_key = d.date_key

INNER JOIN gold.dim_stores ds
    ON fs.store_key = ds.store_key

INNER JOIN gold.dim_products dp
    ON fs.product_key = dp.product_key

GROUP BY
    fs.date_key,
    d.full_date,
    fs.store_key,
    ds.store_id,
    ds.store_name,
    ds.city,
    ds.state,
    fs.product_key,
    dp.product_id,
    dp.product_name,
    dp.category,
    dp.subcategory,
    dp.brand;

GO

SELECT TOP 100 *
FROM mart.vw_sales_summary
ORDER BY full_date;