/* =====================================================================================
   RETAILMART GOLD LAYER — RETURN ANALYSIS
   -------------------------------------------------------------------------------------
   Purpose:
       Provides return-level performance metrics for Tableau / BI reporting.

   Grain:
       One row per product + store combination having returns.

   Dependencies:
       gold.fact_returns
       gold.dim_product
       gold.dim_store

   KPIs:
       - Total Returns
       - Returned Quantity
       - Return Amount
       - Return Rate %
       - Product Return Rank
===================================================================================== */

CREATE OR ALTER VIEW gold.vw_return_analysis
AS

WITH return_summary AS
(
    SELECT
        fr.product_key,
        fr.store_key,

        /* Return Count */
        COUNT(DISTINCT fr.return_id) AS total_returns,

        /* Returned Quantity */
        SUM(fr.return_quantity) AS returned_quantity,

        /* Return Amount */
        SUM(fr.return_amount) AS return_amount

    FROM gold.fact_returns AS fr

    GROUP BY
        fr.product_key,
        fr.store_key
),

sales_summary AS
(
    SELECT
        fs.product_key,
        fs.store_key,

        /* Sales Quantity */
        SUM(fs.quantity) AS sold_quantity,

        /* Sales Amount */
        SUM(fs.sales_amount) AS sales_amount

    FROM gold.fact_sales AS fs

    GROUP BY
        fs.product_key,
        fs.store_key
),

return_metrics AS
(
    SELECT
        rs.product_key,
        rs.store_key,

        rs.total_returns,
        rs.returned_quantity,
        rs.return_amount,

        ss.sold_quantity,
        ss.sales_amount,

        /* Return Rate % */
        CASE
            WHEN ss.sold_quantity = 0
                 OR ss.sold_quantity IS NULL
            THEN 0

            ELSE
                (rs.returned_quantity * 100.0)
                / ss.sold_quantity
        END AS return_rate_pct

    FROM return_summary AS rs

    LEFT JOIN sales_summary AS ss
        ON rs.product_key = ss.product_key
        AND rs.store_key = ss.store_key
)

SELECT
    rm.product_key,
    rm.store_key,

    /* Product Information */
    dp.product_id,
    dp.product_name,
    dp.category,

    /* Store Information */
    ds.store_id,
    ds.store_name,
    ds.city,
    ds.state,

    /* Return Metrics */
    rm.total_returns,
    rm.returned_quantity,
    rm.return_amount,

    /* Sales Metrics */
    rm.sold_quantity,
    rm.sales_amount,

    /* Return Rate */
    rm.return_rate_pct,

    /* Return Rank */
    RANK() OVER
    (
        ORDER BY rm.returned_quantity DESC
    ) AS product_return_rank

FROM return_metrics AS rm

INNER JOIN gold.dim_products AS dp
    ON rm.product_key = dp.product_key

INNER JOIN gold.dim_stores AS ds
    ON rm.store_key = ds.store_key;

GO

SELECT *
FROM gold.vw_return_analysis
ORDER BY product_return_rank;

-- top 10 products
SELECT TOP 10
    product_name,
    category,
    returned_quantity,
    return_amount,
    sold_quantity,
    return_rate_pct,
    product_return_rank
FROM gold.vw_return_analysis
ORDER BY returned_quantity DESC;


