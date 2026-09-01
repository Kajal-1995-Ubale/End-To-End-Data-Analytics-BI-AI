/* =========================================================
   1. OVERALL KPIs
========================================================= */

SELECT *
FROM gold.vw_retailmart_kpis;


/* =========================================================
   2. SALES GROWTH
========================================================= */

SELECT *
FROM gold.vw_sales_growth
ORDER BY SalesYear, SalesMonth;


/* =========================================================
   3. CUSTOMER KPIs
========================================================= */

SELECT

    COUNT(*) AS TotalCustomers,

    SUM(IsActiveCustomer) AS ActiveCustomers,

    SUM(IsNewCustomer) AS NewCustomers,

    SUM(IsRepeatCustomer) AS RepeatCustomers,

    CAST(
        SUM(IsRepeatCustomer) * 100.0
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS RepeatCustomerPct

FROM gold.vw_customer_kpis;


/* =========================================================
   4. PRODUCT KPIs
========================================================= */

SELECT TOP 10 *

FROM gold.vw_product_kpis

ORDER BY TotalSales DESC;


/* =========================================================
   5. STORE KPIs
========================================================= */

SELECT *

FROM gold.vw_store_kpis

ORDER BY StoreSales DESC;