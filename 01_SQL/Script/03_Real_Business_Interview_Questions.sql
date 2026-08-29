-- LEVEL 1 - BASIC
-- Q1. Display all customers
USE retailmart_analytics;

SELECT * 
FROM bronze.customers;

-- Q2. Dsiplay Only customer_id, customer name and state
SELECT Customer_ID,Customer_Name,State
FROM bronze.customers;

-- Q3. Display all unique states.
SELECT DISTINCT State
FROM bronze.customers;

-- Q4. Display all unique product categories
SELECT DISTINCT Category
FROM bronze.products;

-- Q5. Display all stores located in maharashtra
SELECT * 
FROM bronze.Stores
WHERE State='Maharashtra';

-- LEVEL 2 - Filtering
-- Q6. Find products where price is greater than 5000
SELECT * 
FROM bronze.products
WHERE Unit_Price > 5000;

-- Q7. Find products where price is between ₹1,000 and ₹10,000.
SELECT * 
FROM bronze.products
WHERE Unit_Price BETWEEN 1500 AND 10000;

--Q8. Find customers from maharashtra and Delhi 
SELECT *
FROM bronze.customers
WHERE State IN ('Maharashtra','Delhi');

-- Q9. Find Electronics products costing more than ₹2,000.
SELECT * 
FROM bronze.products
WHERE Category='Electronics' AND Unit_Price>2000;

-- Q10. Find customers whose name starts with p
SELECT *
FROM bronze.customers
WHERE Customer_Name LIKE 'p%';

-- LEVEL 3 : SORTING

-- Q11. Display products from highest price to lowest price
SELECT * 
FROM bronze.products
ORDER BY Unit_Price DESC;

-- Q12. Display the three most expensive products.
SELECT TOP 3 Product_Name
FROM bronze.products
ORDER BY Unit_Price DESC;

-- Q13. Display customers alphabetically by name.
SELECT *
FROM bronze.customers
ORDER BY Customer_Name ASC;

-- Q14. Display stores sorted by region and then city.
SELECT *
FROM bronze.Stores
ORDER BY Region, City;

-- LEVEL 4- Retail Business Questions
-- Q15. Management Asks : Which products are priced above 10000
SELECT Product_Name, Unit_Price
FROM bronze.products
WHERE Unit_Price>10000;

-- Q16: Business Asks: Give me all customers registered after April 1,2024
SELECT Customer_Name,Registration_Date 
FROM bronze.customers
WHERE Registration_Date >= '2024-04-01';

-- Q17: The regional manager Asks: show me all stores in the west region 
SELECT * 
FROM bronze.Stores
WHERE Region = 'West';

-- Q18 : The product manager ask: Which products belong to the Electronics category and cost less than ₹3,000?
SELECT Product_Name, Unit_Price
FROM bronze.products
WHERE Category='Electronics' AND Unit_Price<3000;

-- Q19. Managment ask : Give me the five highest-value transactions.
SELECT TOP 5*
FROM bronze.sales
ORDER BY Sales_Amount DESC;

-- Q20: Business ask: Which customers are from maharashtra, but exclude mumbai?
SELECT * 
FROM bronze.customers
WHERE State='Maharashtra' AND City<>'Mumbai';

----------------------------------------------------------------------------------------------------
-- SENIOR ANALYST THINKING EXERCISE
----------------------------------------------------------------------------------------------------
-- Busines Says
-- Sales performance in maharashtra seems to be declining. Give me the data
-- As a Senior Analyst, you should ask:

-- WHAT DOES "Sales" Mean?
-- Gross Sales / Net Sales / Sales Amount / After Return / After Discounts

-- WHAT DOES "declining" Mean?
-- Month-over-month / year-over-year / Last 3 months

-- WHAT LEVEL?
-- State / Stores / Products / Categroy

-- WHAT Period? 
-- Current month / Quarter /Year

-----------------------------------------------------
-- INTERVIEW QUESTIONS
------------------------------------------------------
-- Q1.What is SQL?
-- SQL Stands for structured Query Language.
-- It is used to interact with relational databases to retrieve, Filter, transform, aggregate and manipulate data.
-- In my Retailmart Project, I use SQL to extract data from the bronze and silver layers, 
-- perform data validation and transformations, create business logic and prepare data fot the Gold and Mart Layers
-- Which are then consumed by Tableau for Reporting and analytics.

-- What do you use SQL for?
-- I primarilu use SQL for data extraction, joins, data cleaning, aggregations, KPI calcualtions, 
-- validation, reconciliation and performance optimization 

-- Q2. Difference between WHERE and HAVING Clause?
-- WHERE Filters individual rows before aggregation,
-- whereas HAVING Filters aggregated groups after GROUP BY
-- For example, if I want to filter transaction where sales amount is greater than 10000 I would use WHERE.
-- If I want ot find stores whose total sales exceeds 1 lakh , I would use GROUP BY With HAVING

-- Can we use WHERE with GROUP BY?
-- YES, WHERE filters the rows before they groyped, while HAVING filters the groups after aggregation

SELECT Store_ID,
SUM(Sales_Amount) as total_sales
FROM bronze.sales
WHERE Order_Date >='2024-01-10'
GROUP BY Store_ID
HAVING SUM(Sales_Amount) > 100000;

--  Q3. Difference between WHERE and ON?
-- ON defines the joins between two tables,whereas
-- WHERE Filter the result based on condition
-- For example , In Retailmart, I would use ON to match sales with customers using customer_id
-- WHERE to filter transactions based on sales amount or date

-- Q4. Difference between DISTINCT and GROUP BY?
-- DISTINCT is used to return unique combinations of selected columns
-- GROUP BY groups records based on one or more columns and is generally used with aggregated functions such as SUM, COUNT and AVG.
-- If I only need a unique list of states I would use DISTINCT
-- If I need the number of customers bys state, I would use GROUP BY

-- Q5. Difference between IN and BETWEEN Operators
-- IN is used when I want to filer against a list of specific values
-- BETWEEN is used to filter within a range.
-- For example, I would use IN to find customers from selected states 
-- BETWEEN to find sales within a particular amount or date range

-- Q6. Difference between LIKE 'A%' and LIKE '%A'?
-- A% means the value start with A
-- %A means the value ends with A
-- % sign represents zero or more characters

-- Q7. Difference between ASC and DESC?
-- ASC sorts the results in Ascending order and it is by default 
-- DESC sorts the results in Descending order 
-- For Example, If management asks for the highest value sales transactions, I would use ORDER BY sales amount DESC;

-- Q8. Why Should SELECT * generally be avoided?
-- I genearlly avoid SELECT * in production queries because it retrieves columns that may not be required,
-- Increase data transfer and processing
-- can make queries less readable
-- can create downstream issues if the table structure changes
-- I prefer explicitly selecting the required columns 

-- Q9. What is primary key?
-- A primary key is a column or combination of columns that uniquely identifies each records in a table.
-- It must be unique and cannot contain NULL values.

-- Q10. Would you always create a primary key in bronze?
-- Not necassarily
-- Bronze is generally designed to preserve raw source data so I avoid constraints that could reject incoming source records
-- I apply stronger data quality and strutural rules as data moves into silver and gold

-- Q11. What is grain?
-- Grain defines what one row represents
