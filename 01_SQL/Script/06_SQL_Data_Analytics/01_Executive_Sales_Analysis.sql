/*
--------------------------------------------------------------------
Business Question 1 — What is the overall business performance?
--------------------------------------------------------------------

Management wants the basic executive numbers:

Total Sales
Total Orders
Quantity Sold
Total Cost
Total Profit
Profit Margin %
Average Order Value*/

SELECT 
SUM(sales_amount) as total_sales,
COUNT(DISTINCT order_id) as total_orders,
SUM(quantity) as Quantity_sold,
SUM(cost_amount) as total_cost,
SUM(profit_amount) as total_profit,
ROUND(SUM(profit_amount)*100.0/NULLIF(SUM(sales_amount),0),2) as Profit_margin_per,
ROUND(SUM(sales_amount) * 1.0 / NULLIF(COUNT(DISTINCT order_id), 0),2) AS average_order_value
FROM gold.fact_sales;

--------------------------------------------------------------
-- Business Question 2 — How are sales performing month by month?
----------------------------------------------------------------------------
-- Management wants to understand the sales trend.

SELECT d.year_num,
d.month_num,
d.month_name,
SUM(fs.sales_amount) As total_sales,
SUM(fs.quantity) as quantity_sold,
COUNT(DISTINCT order_id) as total_orders,
SUM(fs.profit_amount) as total_profit
FROM gold.fact_sales fs
INNER JOIN gold.dim_date d
ON fs.date_key = d.date_key
GROUP BY d.year_num,
		d.month_num,
		d.month_name
ORDER BY d.year_num,d.month_num;

---------------------------------------------------------------------------------------------------
-- Business Question 3 — What is the Month-over-Month sales growth?
---------------------------------------------------------------------
WITH monthlysales As(
SELECT d.year_num,
d.month_num,
d.month_name,
SUM(fs.sales_amount) As total_sales

FROM gold.fact_sales fs
INNER JOIN gold.dim_date d
ON fs.date_key = d.date_key
GROUP BY d.year_num,
		d.month_num,
		d.month_name
),
sales_growth As (
SELECT year_num,
month_num,
month_name,
total_sales,
LAG(total_sales) OVER (ORDER BY year_num, month_num) AS previous_month_sales

FROM monthlysales

)
SELECT year_num,
month_num,
total_sales,
previous_month_sales,
total_sales-previous_month_sales as sales_change,
ROUND((total_sales - previous_month_sales)*100.0/NULLIF(previous_month_sales,0),2) As mom_growth
from sales_growth

-----------------------------------------------------------------------------------------------------------
-- Business Question 4 - Which month has the highest Sales?
-----------------------------------------------------------------------

/* ============================================================
   Q4 — BEST SALES MONTH
============================================================ */

WITH monthly_sales AS
(
    SELECT
        d.year_num,
        d.month_num,
        d.month_name,
        SUM(fs.sales_amount) AS total_sales

    FROM gold.fact_sales fs

    INNER JOIN gold.dim_date d
        ON fs.date_key = d.date_key

    GROUP BY
        d.year_num,
        d.month_num,
        d.month_name
),

ranked_months AS
(
    SELECT
        *,
        RANK() OVER
        (
            ORDER BY total_sales DESC
        ) AS sales_rank

    FROM monthly_sales
)

SELECT
    year_num,
    month_num,
    month_name,
    total_sales,
    sales_rank

FROM ranked_months

WHERE sales_rank = 1;

-----------------------------------------------------------------
-- Which month had the lowest sales?
--------------------------------------------
/* ============================================================
   Q5 — WORST SALES MONTH
============================================================ */

WITH monthly_sales AS
(
    SELECT
        d.year_num,
        d.month_num,
        d.month_name,
        SUM(fs.sales_amount) AS total_sales

    FROM gold.fact_sales fs

    INNER JOIN gold.dim_date d
        ON fs.date_key = d.date_key

    GROUP BY
        d.year_num,
        d.month_num,
        d.month_name
)

SELECT TOP 1
    year_num,
    month_num,
    month_name,
    total_sales

FROM monthly_sales

ORDER BY total_sales ASC;

-----------------------------------------------------------------------
-- Business Question 6 — Which states generate the most sales

/* ============================================================
   Q6 — SALES BY STATE
============================================================ */

SELECT
    ds.state,

    SUM(fs.sales_amount) AS total_sales,

    COUNT(DISTINCT fs.order_id) AS total_orders,

    SUM(fs.quantity) AS quantity_sold,

    SUM(fs.profit_amount) AS total_profit

FROM gold.fact_sales fs

INNER JOIN gold.dim_stores ds
    ON fs.store_key = ds.store_key

GROUP BY
    ds.state

ORDER BY
    total_sales DESC;

-------------------------------------------------------
-- Business Question 7 — What percentage of total sales does each state contribute?
/* ============================================================
   Q7 — STATE SALES CONTRIBUTION %
============================================================ */

WITH state_sales AS
(
    SELECT
        ds.state,
        SUM(fs.sales_amount) AS total_sales

    FROM gold.fact_sales fs

    INNER JOIN gold.dim_stores ds
        ON fs.store_key = ds.store_key

    GROUP BY
        ds.state
)

SELECT
    state,
    total_sales,

    ROUND(
        total_sales * 100.0
        / SUM(total_sales) OVER (),
        2
    ) AS sales_contribution_pct

FROM state_sales

ORDER BY
    total_sales DESC;