/* =====================================================================================
   RETAILMART MART LAYER — STORE SUMMARY
===================================================================================== */

CREATE OR ALTER VIEW mart.vw_store_summary
AS

SELECT
    store_key,
    store_id,
    store_name,
    city,
    state,

    total_sales,
    total_orders,
    quantity_sold,
    total_cost,
    total_profit,
    profit_margin_pct,
    aov,
    store_sales_rank

FROM gold.vw_store_performance;

GO