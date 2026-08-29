-- SQL FILTERING

-- 1. AND - means all conditions must be true 
-- Returns true only of both the condition are TRUE
-- Find transactions where sales are between ₹5,000 and ₹10,000 and quantity is greater than 2
SELECT * 
FROM bronze.sales
WHERE Sales_Amount>=5000
AND Sales_Amount<=10000
AND Quantity>2;

-- 2. OR - means at least one condition must be true. 
SELECT * 
FROM bronze.customers
WHERE City='Mumbai'
OR City = 'Pune';

-- 3. IN - IN is used when I want to filter a column against multiple specific values. 
SELECT * 
FROM bronze.customers
WHERE City IN ('Mumbai','Pune');

-- 4. BETWEEN - It is used to filter a range
SELECT * 
FROM bronze.sales
WHERE Sales_Amount BETWEEN 5000 AND 10000;

-- 5. LIKE - It is used for pattern Matching
SELECT * 
FROM bronze.customers
WHERE Customer_Name LIKE 'A%';

-- 6. IS NULL - NULL means the value is missing/unknown
-- you cannot correctly write
SELECT * 
FROM bronze.customers
WHERE City = NULL;
-- Instead
SELECT * 
FROM bronze.customers
WHERE City IS NULL;

-- 7. IS NOT NULL - Find records where a value exists
SELECT * 
FROM bronze.customers
WHERE City IS NOT NULL;

-----------------------------------------------
-- TASK

-- 1. Basic Filtering
-- Find transaction where sales are greater than 5000
SELECT * 
FROM bronze.sales
WHERE Sales_Amount >5000;

-- 2. Find customers who purchased between 5000 and 10000
-- purchase amount is in sales table, we need to connect with customers
SELECT c.Customer_ID,
c.Customer_Name,
s.Sales_ID,
s.Sales_Amount
FROM bronze.customers c
JOIN bronze.sales s
ON c.Customer_ID = s.Customer_ID
WHERE s.Sales_Amount BETWEEN 5000 AND 10000;

-- 3. Customers from selected Cities
SELECT Customer_Name,City 
FROM bronze.customers
Where City IN ('mumbai','pune','Delhi');

--4. Transactions from a specific range
SELECT Sales_ID,Sales_Amount
FROM bronze.sales
WHERE Sales_Amount BETWEEN 2000 AND 5000;

--5 . customer names beginning with A
SELECT * 
FROM bronze.customers
WHERE Customer_Name LIKE 'A%';

-- 6. Missing email addresses / CIty
SELECT * 
FROM bronze.customers
WHERE City IS NULL;

-- 7. Customers having an email /city
SELECT * 
FROM bronze.customers
WHERE City IS NOT NULL;
