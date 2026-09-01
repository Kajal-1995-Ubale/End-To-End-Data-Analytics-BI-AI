/* =====================================================================================
   RETAILMART MART LAYER — PRODUCT SUMMARY
===================================================================================== */

CREATE OR ALTER VIEW mart.vw_product_summary
AS

SELECT
    product_key,
    product_id,
    product_name,
    category,
    subcategory,
    brand,

    total_sales,
    total_orders,
    quantity_sold,
    total_cost,
    total_profit,
    profit_margin_pct,
    aov,
    product_sales_rank

FROM gold.vw_product_performance;

GO