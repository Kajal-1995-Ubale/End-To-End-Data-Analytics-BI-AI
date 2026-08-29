-- Step1 - Our Retail Mart Database System 

/*                    RetailMart
                         |
        -----------------------------------
        |          |          |            |
     Customer    Product     Store        Date
        |          |          |            |
        -----------------------------------
                         |
                      Sales
                         |
              ---------------------
              |                   |
           Returns            Payments
*/
-- we will start with four tables - customer, product, store, date

-- Step 2 : understand the Grain
-- Customers
-- one row = one customer
-- Customer_ID | Customer_Name | Gender | City | State

-- Products
-- one row = one product
-- Product_ID | Product_Name | Category | Sub_Category | Unit_Price

-- Stores 
-- one row = one store
-- Store_ID | Store_Name | City | State | Region

-- Sales 
-- one row = one transaction line

-- Grain defines what one row represents in a table.

-- Step 3 :use Database
USE retailmart_analytics;

-- Step 4 : Inspect your schemas
SELECT *
FROM INFORMATION_SCHEMA.TABLES
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- Step 5 : Create Customer Tables
-- 1. Drop Existing bronze.sales
IF OBJECT_ID('bronze.customers','U') IS NOT NULL
	DROP TABLE bronze.customers;
GO

-- 2. create bronze customers
CREATE TABLE bronze.customers(
 Customer_ID INT ,
    Customer_Name VARCHAR(100),
    Gender VARCHAR(20),
    City VARCHAR(100),
    State VARCHAR(100),
    Registration_Date DATE
);

--3. Create bronze products
IF OBJECT_ID('bronze.products','U') IS NOT NULL
	DROP TABLE bronze.products;
GO
CREATE TABLE bronze.products
(
    Product_ID INT,
    Product_Name VARCHAR(100),
    Category VARCHAR(100),
    Sub_Category VARCHAR(100),
    Unit_Price DECIMAL(10,2)
);

-- 4. Create bronze Stores
IF OBJECT_ID('bronze.Stores','U') IS NOT NULL
	DROP TABLE bronze.Stores;
GO
CREATE TABLE bronze.Stores
(
    Store_ID INT  ,
    Store_Name VARCHAR(100),
    City VARCHAR(100),
    State VARCHAR(100),
    Region VARCHAR(50)
);

-- 5. Create bronze sales
IF OBJECT_ID('bronze.sales','U') IS NOT NULL
	DROP TABLE bronze.sales;
GO
CREATE TABLE bronze.sales
(
    Sales_ID INT,
    Order_ID VARCHAR(20),
    Order_Date DATE,
    Customer_ID INT,
    Product_ID INT,
    Store_ID INT,
    Quantity INT,
    Unit_Price DECIMAL(10,2),
    Discount DECIMAL(10,2),
    Sales_Amount DECIMAL(12,2)
);

-- Step 6: Insert some sample data

-- customers
INSERT INTO bronze.customers
(Customer_ID, Customer_Name, Gender, City, State, Registration_Date)
VALUES
(1, 'Amit Sharma', 'Male', 'Mumbai', 'Maharashtra', '2024-01-15'),
(2, 'Priya Patil', 'Female', 'Pune', 'Maharashtra', '2024-02-10'),
(3, 'Rahul Verma', 'Male', 'Delhi', 'Delhi', '2024-03-05'),
(4, 'Sneha Joshi', 'Female', 'Nashik', 'Maharashtra', '2024-03-18'),
(5, 'Neha Singh', 'Female', 'Bangalore', 'Karnataka', '2024-04-12'),
(6, 'Rohit Mehta', 'Male', 'Mumbai', 'Maharashtra', '2024-05-20'),
(7, 'Pooja Shah', 'Female', 'Ahmedabad', 'Gujarat', '2024-06-11'),
(8, 'Vikas Gupta', 'Male', 'Delhi', 'Delhi', '2024-07-09');

-- products
INSERT INTO bronze.products
(Product_ID, Product_Name, Category, Sub_Category, Unit_Price)
VALUES
(101, 'Laptop', 'Electronics', 'Computers', 55000),
(102, 'Mouse', 'Electronics', 'Accessories', 800),
(103, 'Keyboard', 'Electronics', 'Accessories', 1500),
(104, 'Office Chair', 'Furniture', 'Chairs', 7500),
(105, 'Desk', 'Furniture', 'Tables', 12000),
(106, 'Headphones', 'Electronics', 'Accessories', 2500),
(107, 'Backpack', 'Fashion', 'Bags', 1800),
(108, 'Shoes', 'Fashion', 'Footwear', 3500);

-- stores
INSERT INTO bronze.Stores
(Store_ID, Store_Name, City, State, Region)
VALUES
(1, 'Mumbai Central', 'Mumbai', 'Maharashtra', 'West'),
(2, 'Pune Camp', 'Pune', 'Maharashtra', 'West'),
(3, 'Delhi Central', 'Delhi', 'Delhi', 'North'),
(4, 'Nashik Store', 'Nashik', 'Maharashtra', 'West'),
(5, 'Bangalore Central', 'Bangalore', 'Karnataka', 'South');

-- Sales
INSERT INTO bronze.sales
(Sales_ID, Order_ID, Order_Date, Customer_ID, Product_ID,
 Store_ID, Quantity, Unit_Price, Discount, Sales_Amount)
VALUES
(1, 'ORD001', '2024-01-10', 1, 101, 1, 1, 55000, 2000, 53000),
(2, 'ORD002', '2024-01-15', 2, 102, 2, 2, 800, 100, 1500),
(3, 'ORD003', '2024-02-05', 3, 104, 3, 1, 7500, 500, 7000),
(4, 'ORD004', '2024-02-20', 4, 106, 4, 2, 2500, 200, 4800),
(5, 'ORD005', '2024-03-10', 5, 108, 5, 1, 3500, 300, 3200),
(6, 'ORD006', '2024-03-15', 6, 101, 1, 1, 55000, 5000, 50000),
(7, 'ORD007', '2024-04-01', 7, 107, 2, 2, 1800, 100, 3500),
(8, 'ORD008', '2024-04-12', 8, 105, 3, 1, 12000, 1000, 11000),
(9, 'ORD009', '2024-05-05', 1, 103, 1, 2, 1500, 100, 2900),
(10, 'ORD010', '2024-05-20', 2, 101, 2, 1, 55000, 3000, 52000);

-- Step 7 : First Query - SELECT 
SELECT * From bronze.customers;
--INTERVIEW QUESTION 
-- Why Should we avoid SELECT * in Production queries?
-- It retrieves unneccessary columns, increases data transfer, can affect performance, make queries less maintainable and can cause issues when the table structure change.

-- Step 8 : Column Aliases
SELECT 
Customer_Name AS Customer, 
State AS Customer_State
FROM bronze.customers;

-- Step 9 : DISTINCT 
-- Which State have Retailmart Customers?
SELECT DISTINCT State
FROM bronze.customers;

-- which product categories exist?
SELECT DISTINCT Category
FROM bronze.products;

-- which region have stores?
SELECT DISTINCT Region
FROM bronze.Stores;

-- STep 10 : WHERE
-- Find customers from maharashtra
SELECT *
FROM bronze.customers
WHERE State = 'Maharashtra';

-- Find products costing more than 5000 
SELECT Product_Name,Unit_Price
FROM bronze.products
WHERE Unit_Price >5000;

-- Step 11 : Comparison Operators =,<>,!=,>,<,>=,<=
SELECT Product_Name,Unit_Price
FROM bronze.products
WHERE Unit_Price >=5000;

-- Step 12: AND
-- Find Electronic Products Costing more than 2000
SELECT *
FROM bronze.products
WHERE Category='Electronics' AND Unit_Price>2000;

-- Step 13 : OR
-- Find customers from Delhi or maharashtra
SELECT Customer_Name,State
FROM bronze.customers
WHERE State='Maharashtra' OR State = 'Delhi';

-- Step 14: Insead of OR, we can use IN operators
SELECT Customer_Name,State
FROM bronze.customers
WHERE State IN ('Maharashtra','Delhi');

-- Step 15 : BETWEEN 
-- Find product price BETWEEEN 1000 AND 10000
SELECT *
FROM bronze.products
WHERE Unit_Price BETWEEN 1000 AND 10000;

-- Step 16 : LIKE 
-- Find customers whose names start with A
SELECT *
FROM bronze.customers
WHERE Customer_Name LIKE 'A%';
/*
'A%'     → starts with A
'%a'     → ends with a
'%mit%'  → contains mit
'_mit%'  → one character + mit
*/

-- Step 17 : ORDER BY
-- Show products from highest price to lowest
SELECT 
Product_ID,
Product_Name,
Unit_Price
FROM bronze.products
ORDER BY Unit_Price DESC;
-- ORDER BY Unit_Price ASC;
-- ASC is by defaulte

-- Multiple Sort Columns
SELECT * 
FROM bronze.customers
ORDER BY State ASC, Customer_Name ASC;

-- Step 18 : TOP
-- Find the 5 most Expensive products
SELECT TOP 5*
FROM bronze.products
ORDER BY Unit_Price DESC;

-- Step 19: SQL EXECUTION ORDER
/*
FROM
JOIN
WHERE
GROUP BY
HAVING
SELECT
DISTINCT
ORDER BY
TOP/OFFSET
*/
