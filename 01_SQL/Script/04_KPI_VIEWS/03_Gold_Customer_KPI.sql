/* =====================================================================================
   RETAILMART GOLD LAYER
   KPI VIEW 03 — CUSTOMER KPIs
   -------------------------------------------------------------------------------------
   Grain: One row per customer
===================================================================================== */
-- SELECT * FROM gold.fact_sales;
-- SELECT * FROM gold.dim_date;
-- SELECT * FROM gold.dim_customers;


CREATE OR ALTER VIEW gold.vw_customer_kpis
AS

WITH CustomerOrders AS
(
    SELECT

        c.customer_id,

        COUNT(DISTINCT order_id) AS TotalOrders,

        SUM(sales_amount) AS TotalCustomerSales,

        MIN(d.full_date) AS FirstPurchaseDate,

        MAX(d.full_date) AS LastPurchaseDate

    FROM gold.fact_sales f
    INNER JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key
    INNER JOIN gold.dim_date d
    ON f.date_key=d.date_key

    GROUP BY

        customer_id
)

SELECT

    c.customer_id,

    c.customer_name,

    c.customer_status,

    c.registration_date,

    /* =========================================================
       ORDER INFORMATION
    ========================================================= */

    ISNULL(co.TotalOrders, 0) AS TotalOrders,

    ISNULL(co.TotalCustomerSales, 0) AS TotalCustomerSales,

    co.FirstPurchaseDate,

    co.LastPurchaseDate,

    /* =========================================================
       ACTIVE CUSTOMER
    ========================================================= */

    CASE

        WHEN c.customer_status = 'Active'

        THEN 1

        ELSE 0

    END AS IsActiveCustomer,

    /* =========================================================
       NEW CUSTOMER
    ========================================================= */

    CASE

        WHEN co.FirstPurchaseDate IS NOT NULL

        AND co.FirstPurchaseDate =

            (
                SELECT MIN(d.full_date)
                FROM gold.fact_sales fs
                INNER JOIN gold.dim_date d
                ON fs.date_key = d.date_key
                WHERE fs.customer_key = c.customer_key
            )

        THEN 1

        ELSE 0

    END AS IsNewCustomer,

    /* =========================================================
       REPEAT CUSTOMER
    ========================================================= */

    CASE

        WHEN ISNULL(co.TotalOrders, 0) > 1

        THEN 1

        ELSE 0

    END AS IsRepeatCustomer

    
FROM gold.dim_customers c

LEFT JOIN CustomerOrders co

    ON c.customer_id = co.customer_id;

GO