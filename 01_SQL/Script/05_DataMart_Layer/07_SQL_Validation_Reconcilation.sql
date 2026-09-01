/* ============================================================
   1. ROW COUNT VALIDATION
============================================================ */

SELECT
'gold.fact_sales' As Table_Name,
COUNT(*) As row_Count
FROM gold.fact_sales

UNION ALL 

SELECT 'gold.fact_returns',
COUNT(*)
FROM gold.fact_returns

UNION ALL 

SELECT 'gold.dim_products',
COUNT(*) 
FROM gold.dim_products

UNION ALL 

SELECT
    'gold.dim_store',
    COUNT(*)
FROM gold.dim_stores

UNION ALL

SELECT
    'gold.dim_customer',
    COUNT(*)
FROM gold.dim_customers;

---------------------------------------------------------------
-- 2. Sales Reconciliation
------------------------------------------------------------------------

-- FACT Sales
SELECT 
SUM(Sales_amount) As Fact_total_sales
FROM gold.fact_sales;

-- 28392373.33

-- Product View Sales
SELECT 
SUM(total_sales) As Product_View_Sales
FROM gold.vw_product_performance;
-- 28392373.33

-- Store View Sales
SELECT 
SUM(total_sales) As store_view_sales
FROM gold.vw_store_performance;
-- 28392373.33

-- Customer view Sales
SELECT 
SUM(total_sales) As customer_view_sales
FROM gold.vw_customer_performance;
-- 28392373.33

-- Mart 
SELECT  
   SUM(total_sales) AS mart_sales
FROM mart.vw_sales_summary;
-- 28392373.33
--------------------------------------------------------------------------------------
-- 3. Profit Reconciliation
-- Profit = Sales - Cost

SELECT 
SUM(Sales_amount) as total_sales,
SUM(cost_amount) as total_cost,
SUM(profit_amount) as recorded_profit,
SUM(sales_amount) - SUM(cost_amount) as Calculated_Profit
FROM gold.fact_sales;
-- you want recorded profit = calculated profit

-- recorded_profit
-- 8764066.32
-- Calculated_Profit
-- 8764066.32

-----------------------------------------------------------------------------------------
-- 4. Profit Validation in product view 
SELECT 
SUM(total_sales) as total_sales,
SUM(total_cost) as total_cost,
SUM(total_profit) as recorded_profit,
SUM(total_sales) - SUM(total_cost) as Calculated_Profit
FROM gold.vw_product_performance;

-----------------------------------------------------------------------------------

-- 5. profit margin validation
-- profit margin% = total profit / total sales * 100 
SELECT
    SUM(total_profit) AS total_profit,
    SUM(total_sales) AS total_sales,

    SUM(total_profit) * 100.0
        / NULLIF(SUM(total_sales), 0) AS calculated_margin
FROM gold.vw_product_performance;

-----------------------------------------------------------------
-- 6. Quantity Reconciliation 

-- Fact
SELECT 
SUM(quantity) AS fact_quantity
FROM gold.fact_sales;
-- 96672

-- Product View
SELECT
    SUM(quantity_sold) AS product_quantity
FROM gold.vw_product_performance;
-- 96672

-- Store View
SELECT
    SUM(quantity_sold) AS store_quantity
FROM gold.vw_store_performance;
-- 96672

-- customer view 
SELECT
    SUM(quantity_purchased) AS customer_quantity
FROM gold.vw_customer_performance;
-- 96672

-- These should all match 
-----------------------------------------------------------------------------------------
-- 7. Order count vaildation 
SELECT
    COUNT(DISTINCT order_id) AS fact_orders
FROM gold.fact_sales;

SELECT
    SUM(total_orders) AS product_orders
FROM gold.vw_product_performance;

-------------------------------------------------------
-- 8. Validatae AOV
-- AOV = Total Sales / Total Orders
SELECT
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT order_id) AS total_orders,

    SUM(sales_amount) * 1.0
        / NULLIF(COUNT(DISTINCT order_id), 0) AS calculated_aov
FROM gold.fact_sales;

---------------------------------
-- 9. Check Duplicate Fact Sales
SELECT
    sales_key,
    COUNT(*) AS duplicate_count
FROM gold.fact_sales f

GROUP BY sales_key
HAVING COUNT(*) > 1;

---------------------------------------
-- 10. Check Duplicat Dimension keys
-- products
SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- Store
SELECT
    store_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_stores
GROUP BY store_key
HAVING COUNT(*) > 1;

-- Customer
SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-------------------------------------------
-- 11 . Check orphan product keys
SELECT
    COUNT(*) AS orphan_product_rows
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products dp
    ON fs.product_key = dp.product_key
WHERE dp.product_key IS NULL;

----------------------------------------
-- 12 validate sales growth 
SELECT 
    SUM(MonthlySales) AS growth_view_sales
FROM gold.vw_sales_growth;
-- compare with fact sales
SELECT
    SUM(sales_amount) AS fact_sales
FROM gold.fact_sales;

--------------------------------------
-- Validate product Ranking 
SELECT TOP 10
    product_name,
    total_sales,
    product_sales_rank
FROM gold.vw_product_performance
ORDER BY product_sales_rank;

------------------------------------------

-- 19. Check negative / invalid values
-- Negative Quantity 
SELECT COUNT(*) AS negative_quantity_rows
FROM gold.fact_sales
WHERE quantity < 0;

-- Negative Sales
SELECT COUNT(*) AS negative_sales_rows
FROM gold.fact_sales
WHERE sales_amount < 0;

-- Negative Cost 
SELECT COUNT(*) AS negative_cost_rows
FROM gold.fact_sales
WHERE cost_amount < 0;

-- 20 Final Executive Reconciliation 
SELECT
    SUM(fs.sales_amount) AS total_sales,
    SUM(fs.cost_amount) AS total_cost,
    SUM(fs.profit_amount) AS total_profit,
    SUM(fs.quantity) AS quantity_sold,
    COUNT(DISTINCT fs.order_id) AS total_orders,

    SUM(fs.profit_amount) * 100.0
        / NULLIF(SUM(fs.sales_amount), 0) AS profit_margin_pct,

    SUM(fs.sales_amount) * 1.0
        / NULLIF(COUNT(DISTINCT fs.order_id), 0) AS aov

FROM gold.fact_sales fs;