-- this file is specially responsible for raw sales table
/*
Think:

"How do I create and initially load the sales source data into Bronze?"

It will eventually contain:

1. Drop existing bronze.sales
2. Create bronze.sales
3. Load sales data
4. Verify loaded data
*/

-- 1. Drop Existing bronze.sales
IF OBJECT_ID('bronze.sales','U') IS NOT NULL
	DROP TABLE bronze.sales;
GO

-- 2. create bronze sales
CREATE TABLE bronze.sales
(
    order_id        INT,
    customer_id     INT,
    product_id      INT,
    store_id        INT,
    employee_id     INT,
    order_date      DATE,
    quantity        INT,
    unit_price      DECIMAL(18,2),
    discount_amount DECIMAL(18,2)
);
GO

-- NOTICE
-- No primary key yet
-- WHY?
-- Because Bronze is supposed to represent source data as received and source data many contain duplicates or quality issues
-- we will handle the business rules later.

-- 3. LOAD Data
INSERT INTO bronze.sales
(
    order_id,
    customer_id,
    product_id,
    store_id,
    employee_id,
    order_date,
    quantity,
    unit_price,
    discount_amount
)
VALUES
(1001, 501, 101, 10, 201, '2026-08-01', 2, 500.00, 50.00),
(1001, 501, 102, 10, 201, '2026-08-01', 1, 800.00, 0.00),
(1002, 502, 101, 11, 202, '2026-08-02', 3, 500.00, 100.00),
(1003, 501, 103, 10, 203, '2026-08-03', 1, 1200.00, 200.00);
GO

-- currently for learning I am not loading 30k data 

-- 4. Verify Data
SELECT * 
from bronze.sales;

-- 5. Basic Data Check
SELECT
    MIN(order_date) AS min_order_date,
    MAX(order_date) AS max_order_date,
    SUM(quantity) AS total_quantity
FROM bronze.sales;

-----------------------------------------------------------------
-- PRACTICE QUESTIONS
-----------------------------------------------------------------
-- Display all sales
SELECT * 
FROM bronze.sales;
-- AI correctness
-- Avoid using *, Fine for exploration
-- Why because if tomorrow the table changes, your query automatically returns those columns.


-- Display order_id, product_id, quantity, unit_price
SELECT order_id,product_id,quantity,unit_price
FROM bronze.sales;

-- calculate gross sales
SELECT order_id,
product_id,
quantity,
unit_price,
quantity * unit_price as gross_sales
FROM bronze.sales;

-- calculate net sales
SELECT order_id,
product_id,
quantity,
unit_price,
quantity * unit_price as gross_sales,
(quantity * unit_price)-discount_amount as net_sales
FROM bronze.sales;

-- total gross sales
SELECT 
SUM(quantity * unit_price) as total_gross_sales
FROM bronze.sales;

-- total net sales
SELECT 
SUM((quantity * unit_price)-discount_amount) as total_net_sales
FROM bronze.sales;

-- Find number of rows
SELECT count(*) 
FROM bronze.sales;

-- Find unique number of rows 
SELECT count(DISTINCT order_id) 
FROM bronze.sales;

-- Find total Quantity sold
SELECT SUM(quantity) as total_quantity_sold
FROM bronze.sales;

-- Explain the grain of bronze.sales
SELECT * 
FROM bronze.sales;
-- one row = one product line per records

--------------------------------------------
-- AI - USE CASE 
/* PROMPT -  "Review this SQL query as a Senior Data Analyst. Check correctness, aggregation logic, grain issues, NULL handling, performance, and readability. Do not rewrite it immediately; first explain what is wrong and why */
