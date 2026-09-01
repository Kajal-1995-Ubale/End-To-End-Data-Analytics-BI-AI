/* =====================================================================================
   RETAILMART MART LAYER — CUSTOMER SUMMARY
===================================================================================== */

CREATE OR ALTER VIEW mart.vw_customer_summary
AS

SELECT
    customer_key,
    customer_id,
    customer_name,
    city,
    state,

    total_sales,
    total_orders,
    quantity_purchased,
    total_cost,
    total_profit,
    profit_margin_pct,
    aov,

    first_purchase_date,
    last_purchase_date,

    customer_sales_rank

FROM gold.vw_customer_performance;

GO