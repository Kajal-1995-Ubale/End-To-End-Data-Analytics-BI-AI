/* =====================================================================================
   RETAILMART MART LAYER — RETURN SUMMARY
===================================================================================== */

CREATE OR ALTER VIEW mart.vw_return_summary
AS

SELECT
    product_key,
    store_key,

    product_id,
    product_name,
    category,

    store_id,
    store_name,
    city,
    state,

    total_returns,
    returned_quantity,
    return_amount,

    sold_quantity,
    sales_amount,

    return_rate_pct,
    product_return_rank

FROM gold.vw_return_analysis;

GO