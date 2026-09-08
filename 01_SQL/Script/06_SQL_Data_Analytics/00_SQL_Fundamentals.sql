-- STRUCTURE QUERY LANGUEAGE (SQL) 
-- SQL Commands
-- 1. DDL = Define database schema in DBMS
-- CREATE / DROP / ALTER / TRUNCATE

-- 2. DML = manipulate data in the DB
-- INSERT / UPDATE / DELETE

-- 3. DCL = deals with access rights and data control on the data present in the db 
-- GRANT / REVOKE 

-- 4. TCL = deals with the transaction happening in the DB
-- COMMIT / ROLLBACK

-- 5. DQL = retrieve data from the DB using SQL queries
-- SELECT
--------------------------------------------------------------------------------------------------
-- 1. Create database
CREATE DATABASE Sample_DB;

-- 2. Use the database 
USE Sample_DB;

-- 3. Create table
IF OBJECT_ID('customer','U') IS NOT NULL 
 DROP TABLE Customer
GO

CREATE TABLE  Customer
(
Customerid INT IDENTITY(1,1) PRIMARY KEY,
Customernumber INT NOT NULL UNIQUE
 CHECK(Customernumber >0),
lastname VARCHAR(30) NOT NULL,
firstname VARCHAR(30) NOT NULL,
areacode INT default 71000,
address VARCHAR(50),
country VARCHAR(50) default 'Malaysia'
)
GO

--------------------------------------------------------------------------------------------------------

-- now check the constraint add wrong values to identify whether constraints working or not
INSERT INTO Customer VALUES (-1,'Fang Yang',NULL,default,'airoli',default);
-- this statement will show error becuase 
-- -1 value should be in check customernumber > 0 and -1 is small than that
-- firstname should not be NULL 
--------------------------------------------------------------------------------------------------------
-- failed INSERT may consume customerid =1 
-- Reset Identity so next successful record starts from 1 

DBCC CHECKIDENT ('Customer', RESEED, 0);
GO

--Insert correct record 
INSERT INTO Customer VALUES (101,'Fang Yang','Sham',default,'airoli',default);
----------------------------------------------------------------------------------------------------------
-- 4. Insert values into table
insert into customer values (102,'Fang Ting','Shyam',418999,'Mumbai',default),
(103,'Mei Mei','Tan',default,'Thane','Thailand'),
(104,'ALbert','John',default,'New York',default);
----------------------------------------------------------------------------------------------------
-- 5. display all records
SELECT * from Customer;

-- 5. display particular columns
SELECT Customernumber,firstname,lastname,country
FROM Customer;
-----------------------------------------------------------------------------------------------------
-- 6. Add a new column to table 
ALTER TABLE Customer
ADD  phonenumber VARCHAR(20);
-----------------------------------------------------------------------------------------------------
-- 7. Add values to newly added column / update table 
-- UPDATE Customer
-- SET phonenumber='8686868686'
-- WHERE Customerid IN (1,3,4);

-- UPDATE Customer
-- SET phonenumber = '9797878797'
-- WHERE Customerid IN (2,5);
-------------------------------------------------------------------------------------------------------

-- 8. Delete a Column 
ALTER TABLE customer
DROP cOLUMN phonenumber;

SELECT * FROM Customer;
-------------------------------------------------------------------------------------------------------
-- 9. Delete a record from table -- 'if not put where will delete all record'
DELETE 
FROM Customer
WHERE Country = 'Thailand';
-------------------------------------------------------------------------------------------------------
-- 10. Delete table
DROP TABLE Customer;

--------------------------------------------------------------------------------------------------------
-- 11 change data type 
ALTER TABLE Customer
ALTER COLUMN phonenumber VARCHAR(10);

-- *****************************************************************************************************

IF OBJECT_ID('customer','U') IS NOT NULL 
 DROP TABLE Customer
GO

CREATE TABLE  Customer
(
CustomerID Int NOT NULL PRIMARY KEY,
CustomerFirstName VARCHAR(30) NOT NULL,
CustomerLastName VARCHAR(30) NOT NULL,
CustomerAddress VARCHAR(50) NOT NULL,
CustomerSuburb VARCHAR(50) NOT NULL,
CustomerCity VARCHAR(50) NOT NULL,
CustomerPostCode CHAR(4) NULL,
CustomerPhoneNumber CHAR(12) NULL
);
GO

IF OBJECT_ID('Inventory','U') IS NOT NULL
DROP TABLE Inventory
GO

CREATE TABLE Inventory(
InventoryID INT NOT NULL PRIMARY KEY,
InventoryName VARCHAR(50) NOT NULL,
InventoryDescription VARCHAR(255)  NOT NULL
);
GO

IF OBJECT_ID('Employee','U') IS NOT NULL
DROP TABLE Employee
GO

CREATE TABLE Employee(
EmployeeID INT NOT NULL PRIMARY KEY,
EmployeeFirstName VARCHAR(50) NOT NULL,
EmployeeLastName VARCHAR(50) NOT NULL,
EmployeeExtension CHAR(4) NULL
);


IF OBJECT_ID('Sales','U') IS NOT NULL
DROP TABLE Sales
GO 

CREATE TABLE Sales(
SalesID INT NOT NULL PRIMARY KEY,
CustomerID INT NOT NULL References Customer(CustomerID),
InventoryID INT NOT NULL References Inventory(InventoryID),
EmployeeID INT NOT NULL References Employee(EmployeeID),
SaleDate DATE not null,
SaleQuantity INT NOT NULL,
SaleUnitPrice DECIMAL(10,2) NOT NULL
);
GO
--------------------------------------------------------------------------------------------------------
-- ************** INSERT VALUE INTO CREATED TABLES **************************************************
-- ### 1. Insert 45 Customers

-- ```sql
INSERT INTO Customer
(CustomerID, CustomerFirstName, CustomerLastName, CustomerAddress,
 CustomerSuburb, CustomerCity, CustomerPostCode, CustomerPhoneNumber)
VALUES
(1, 'John', 'Smith', '10 Main Street', 'Richmond', 'Melbourne', '3000', '0412345678'),
(2, 'Sarah', 'Johnson', '25 Park Road', 'Carlton', 'Melbourne', '3053', '0423456789'),
(3, 'Michael', 'Brown', '18 King Street', 'Newtown', 'Sydney', '2042', '0434567890'),
(4, 'Emily', 'Davis', '42 George Street', 'Parramatta', 'Sydney', '2150', '0445678901'),
(5, 'Daniel', 'Wilson', '15 Queen Street', 'Fortitude', 'Brisbane', '4000', '0456789012'),
(6, 'Jessica', 'Taylor', '31 Albert Street', 'Southbank', 'Melbourne', '3006', '0467890123'),
(7, 'James', 'Anderson', '55 High Street', 'Clayton', 'Melbourne', '3168', '0478901234'),
(8, 'Emma', 'Thomas', '12 Station Road', 'Chatswood', 'Sydney', '2067', '0489012345'),
(9, 'William', 'Jackson', '76 Victoria Road', 'Ryde', 'Sydney', '2112', '0490123456'),
(10, 'Olivia', 'White', '20 Church Street', 'Toowong', 'Brisbane', '4066', '0401234567'),
(11, 'Robert', 'Harris', '33 Collins Street', 'Docklands', 'Melbourne', '3008', '0412345689'),
(12, 'Sophia', 'Martin', '44 Oxford Street', 'Bondi', 'Sydney', '2026', '0423456790'),
(13, 'David', 'Thompson', '17 King Road', 'Woolloongabba', 'Brisbane', '4102', '0434567891'),
(14, 'Ava', 'Garcia', '29 Beach Road', 'Brighton', 'Melbourne', '3186', '0445678902'),
(15, 'Joseph', 'Martinez', '63 Market Street', 'Richmond', 'Melbourne', '3121', '0456789013'),
(16, 'Mia', 'Robinson', '8 Chapel Street', 'Prahran', 'Melbourne', '3181', '0467890124'),
(17, 'Thomas', 'Clark', '19 Pitt Street', 'Sydney', 'Sydney', '2000', '0478901235'),
(18, 'Isabella', 'Rodriguez', '27 William Street', 'Perth', 'Perth', '6000', '0489012346'),
(19, 'Charles', 'Lewis', '35 Hay Street', 'East Perth', 'Perth', '6004', '0490123457'),
(20, 'Amelia', 'Lee', '11 Adelaide Street', 'Adelaide', 'Adelaide', '5000', '0401234568'),
(21, 'Christopher', 'Walker', '22 Grenfell Street', 'Adelaide', 'Adelaide', '5000', '0412345690'),
(22, 'Charlotte', 'Hall', '39 Rundle Road', 'Kent Town', 'Adelaide', '5067', '0423456791'),
(23, 'Matthew', 'Allen', '14 Queen Road', 'Hobart', 'Hobart', '7000', '0434567892'),
(24, 'Harper', 'Young', '51 Elizabeth Street', 'Hobart', 'Hobart', '7000', '0445678903'),
(25, 'Anthony', 'Hernandez', '73 North Road', 'Darwin', 'Darwin', '0800', '0456789014'),
(26, 'Evelyn', 'King', '16 Mitchell Street', 'Darwin', 'Darwin', '0800', '0467890125'),
(27, 'Mark', 'Wright', '28 Flinders Street', 'Townsville', 'Townsville', '4810', '0478901236'),
(28, 'Abigail', 'Lopez', '45 Walker Street', 'Cairns', 'Cairns', '4870', '0489012347'),
(29, 'Steven', 'Hill', '9 Lake Road', 'Geelong', 'Geelong', '3220', '0490123458'),
(30, 'Ella', 'Scott', '32 Moorabool Street', 'Geelong', 'Geelong', '3220', '0401234569'),
(31, 'Andrew', 'Green', '21 High Road', 'Ballarat', 'Ballarat', '3350', '0412345691'),
(32, 'Elizabeth', 'Adams', '37 Main Road', 'Bendigo', 'Bendigo', '3550', '0423456792'),
(33, 'Joshua', 'Baker', '48 Bridge Road', 'Richmond', 'Melbourne', '3121', '0434567893'),
(34, 'Sofia', 'Nelson', '13 Garden Road', 'St Kilda', 'Melbourne', '3182', '0445678904'),
(35, 'Ryan', 'Carter', '26 Beach Street', 'Fremantle', 'Perth', '6160', '0456789015'),
(36, 'Grace', 'Mitchell', '41 Queen Street', 'Fremantle', 'Perth', '6160', '0467890126'),
(37, 'Kevin', 'Perez', '58 Murray Street', 'Perth', 'Perth', '6000', '0478901237'),
(38, 'Chloe', 'Roberts', '62 George Street', 'Sydney', 'Sydney', '2000', '0489012348'),
(39, 'Brian', 'Turner', '74 King Street', 'Brisbane', 'Brisbane', '4000', '0490123459'),
(40, 'Lily', 'Phillips', '81 Queen Street', 'Brisbane', 'Brisbane', '4000', '0401234570'),
(41, 'Jason', 'Campbell', '92 Collins Street', 'Melbourne', 'Melbourne', '3000', '0412345692'),
(42, 'Zoey', 'Parker', '66 Crown Street', 'Wollongong', 'Wollongong', '2500', '0423456793'),
(43, 'Eric', 'Evans', '77 Hunter Street', 'Newcastle', 'Newcastle', '2300', '0434567894'),
(44, 'Hannah', 'Edwards', '88 Church Street', 'Canberra', 'Canberra', '2600', '0445678905'),
(45, 'Adam', 'Collins', '99 London Circuit', 'Canberra', 'Canberra', '2600', '0456789016');
-- ```

-- ### 2. Insert 45 Inventory Records

-- ```sql
INSERT INTO Inventory
(InventoryID, InventoryName, InventoryDescription)
VALUES
(1, 'Laptop', 'Business laptop computer'),
(2, 'Desktop Computer', 'Standard desktop computer'),
(3, 'Monitor', '24 inch LED monitor'),
(4, 'Keyboard', 'USB standard keyboard'),
(5, 'Mouse', 'Wireless optical mouse'),
(6, 'Printer', 'Color inkjet printer'),
(7, 'Scanner', 'Flatbed document scanner'),
(8, 'Tablet', '10 inch Android tablet'),
(9, 'Smartphone', '5G smartphone'),
(10, 'Headphones', 'Wireless headphones'),
(11, 'Webcam', 'HD USB webcam'),
(12, 'Microphone', 'USB condenser microphone'),
(13, 'Router', 'Wireless network router'),
(14, 'Switch', '24 port network switch'),
(15, 'Hard Drive', '1TB external hard drive'),
(16, 'SSD', '512GB solid state drive'),
(17, 'USB Cable', 'USB-C charging cable'),
(18, 'HDMI Cable', 'High speed HDMI cable'),
(19, 'Power Bank', '20000mAh portable power bank'),
(20, 'Laptop Bag', 'Water resistant laptop bag'),
(21, 'Office Chair', 'Ergonomic office chair'),
(22, 'Desk', 'Modern office workstation desk'),
(23, 'Desk Lamp', 'LED adjustable desk lamp'),
(24, 'UPS', '650VA backup power supply'),
(25, 'Projector', 'Full HD office projector'),
(26, 'Projector Screen', 'Portable projector screen'),
(27, 'Speakers', 'Bluetooth desktop speakers'),
(28, 'Smart Watch', 'Fitness smart watch'),
(29, 'Keyboard Mechanical', 'Mechanical gaming keyboard'),
(30, 'Gaming Mouse', 'High precision gaming mouse'),
(31, 'Gaming Monitor', '27 inch gaming monitor'),
(32, 'Graphics Card', 'Dedicated graphics card'),
(33, 'RAM 16GB', '16GB DDR4 memory module'),
(34, 'RAM 32GB', '32GB DDR4 memory module'),
(35, 'Motherboard', 'ATX desktop motherboard'),
(36, 'Processor', 'Multi core desktop processor'),
(37, 'Cooling Fan', 'CPU cooling fan'),
(38, 'Power Supply', '650W computer power supply'),
(39, 'Computer Case', 'Mid tower computer case'),
(40, 'USB Hub', '7 port USB hub'),
(41, 'Memory Card', '128GB microSD memory card'),
(42, 'Card Reader', 'USB memory card reader'),
(43, 'Bluetooth Adapter', 'USB Bluetooth adapter'),
(44, 'WiFi Adapter', 'USB wireless network adapter'),
(45, 'External DVD Drive', 'USB external DVD drive');
-- ```

-- ### 3. Insert 45 Employees

-- ```sql
INSERT INTO Employee
(EmployeeID, EmployeeFirstName, EmployeeLastName, EmployeeExtension)
VALUES
(1, 'James', 'Smith', '1001'),
(2, 'Mary', 'Johnson', '1002'),
(3, 'Robert', 'Brown', '1003'),
(4, 'Patricia', 'Davis', '1004'),
(5, 'John', 'Wilson', '1005'),
(6, 'Jennifer', 'Taylor', '1006'),
(7, 'Michael', 'Anderson', '1007'),
(8, 'Linda', 'Thomas', '1008'),
(9, 'William', 'Jackson', '1009'),
(10, 'Elizabeth', 'White', '1010'),
(11, 'David', 'Harris', '1011'),
(12, 'Barbara', 'Martin', '1012'),
(13, 'Richard', 'Thompson', '1013'),
(14, 'Susan', 'Garcia', '1014'),
(15, 'Joseph', 'Martinez', '1015'),
(16, 'Jessica', 'Robinson', '1016'),
(17, 'Thomas', 'Clark', '1017'),
(18, 'Sarah', 'Rodriguez', '1018'),
(19, 'Charles', 'Lewis', '1019'),
(20, 'Karen', 'Lee', '1020'),
(21, 'Christopher', 'Walker', '1021'),
(22, 'Nancy', 'Hall', '1022'),
(23, 'Daniel', 'Allen', '1023'),
(24, 'Lisa', 'Young', '1024'),
(25, 'Matthew', 'Hernandez', '1025'),
(26, 'Betty', 'King', '1026'),
(27, 'Anthony', 'Wright', '1027'),
(28, 'Margaret', 'Lopez', '1028'),
(29, 'Mark', 'Hill', '1029'),
(30, 'Sandra', 'Scott', '1030'),
(31, 'Donald', 'Green', '1031'),
(32, 'Ashley', 'Adams', '1032'),
(33, 'Steven', 'Baker', '1033'),
(34, 'Kimberly', 'Nelson', '1034'),
(35, 'Paul', 'Carter', '1035'),
(36, 'Donna', 'Mitchell', '1036'),
(37, 'Andrew', 'Perez', '1037'),
(38, 'Carol', 'Roberts', '1038'),
(39, 'Joshua', 'Turner', '1039'),
(40, 'Michelle', 'Phillips', '1040'),
(41, 'Kenneth', 'Campbell', '1041'),
(42, 'Emily', 'Parker', '1042'),
(43, 'Kevin', 'Evans', '1043'),
(44, 'Amanda', 'Edwards', '1044'),
(45, 'Brian', 'Collins', '1045');
-- ```

-- ### 4. Insert 45 Sales Records

-- The Sales records reference the IDs from all three parent tables.

-- ```sql
INSERT INTO Sales
(SalesID, CustomerID, InventoryID, EmployeeID,
 SaleDate, SaleQuantity, SaleUnitPrice)
VALUES
(1, 1, 1, 1, '2024-01-05', 1, 1200.00),
(2, 2, 3, 2, '2024-01-07', 2, 250.00),
(3, 3, 5, 3, '2024-01-10', 3, 45.00),
(4, 4, 8, 4, '2024-01-12', 1, 450.00),
(5, 5, 9, 5, '2024-01-15', 2, 750.00),
(6, 6, 10, 6, '2024-01-18', 1, 180.00),
(7, 7, 2, 7, '2024-01-20', 1, 900.00),
(8, 8, 4, 8, '2024-01-22', 2, 75.00),
(9, 9, 6, 9, '2024-01-25', 1, 320.00),
(10, 10, 11, 10, '2024-01-28', 3, 95.00),

(11, 11, 12, 11, '2024-02-02', 1, 150.00),
(12, 12, 13, 12, '2024-02-05', 2, 130.00),
(13, 13, 15, 13, '2024-02-08', 1, 110.00),
(14, 14, 16, 14, '2024-02-10', 2, 85.00),
(15, 15, 18, 15, '2024-02-12', 3, 35.00),
(16, 16, 20, 16, '2024-02-15', 1, 90.00),
(17, 17, 21, 17, '2024-02-18', 1, 480.00),
(18, 18, 22, 18, '2024-02-20', 2, 350.00),
(19, 19, 25, 19, '2024-02-22', 1, 850.00),
(20, 20, 27, 20, '2024-02-25', 2, 120.00),

(21, 21, 28, 21, '2024-03-01', 1, 300.00),
(22, 22, 29, 22, '2024-03-04', 1, 140.00),
(23, 23, 30, 23, '2024-03-07', 2, 110.00),
(24, 24, 31, 24, '2024-03-10', 1, 550.00),
(25, 25, 32, 25, '2024-03-12', 1, 700.00),
(26, 26, 33, 26, '2024-03-15', 2, 80.00),
(27, 27, 34, 27, '2024-03-18', 1, 150.00),
(28, 28, 35, 28, '2024-03-20', 1, 300.00),
(29, 29, 36, 29, '2024-03-22', 1, 450.00),
(30, 30, 37, 30, '2024-03-25', 2, 60.00),

(31, 31, 38, 31, '2024-04-02', 1, 95.00),
(32, 32, 39, 32, '2024-04-05', 1, 125.00),
(33, 33, 40, 33, '2024-04-08', 2, 45.00),
(34, 34, 41, 34, '2024-04-10', 3, 35.00),
(35, 35, 42, 35, '2024-04-12', 1, 30.00),
(36, 36, 43, 36, '2024-04-15', 2, 25.00),
(37, 37, 44, 37, '2024-04-18', 1, 40.00),
(38, 38, 45, 38, '2024-04-20', 1, 75.00),
(39, 39, 1, 39, '2024-04-22', 1, 1200.00),
(40, 40, 3, 40, '2024-04-25', 2, 250.00),

(41, 41, 5, 41, '2024-05-02', 1, 45.00),
(42, 42, 9, 42, '2024-05-05', 1, 750.00),
(43, 43, 16, 43, '2024-05-08', 2, 85.00),
(44, 44, 25, 44, '2024-05-10', 1, 850.00),
(45, 45, 31, 45, '2024-05-12', 1, 550.00);
-- ```
-- ### 5. Verify the Record Counts
--```sql

SELECT 'Customer' AS TableName, COUNT(*) AS RecordCount
FROM Customer
UNION ALL
SELECT 'Inventory', COUNT(*)
FROM Inventory
UNION ALL
SELECT 'Employee', COUNT(*)
FROM Employee
UNION ALL
SELECT 'Sales', COUNT(*)
FROM Sales;


-- Verify the Foreign Keys

SELECT *
FROM Sales
WHERE CustomerID NOT IN (SELECT CustomerID FROM Customer)
   OR InventoryID NOT IN (SELECT InventoryID FROM Inventory)
   OR EmployeeID NOT IN (SELECT EmployeeID FROM Employee);

-- This confirms that every `Sales` record has a valid **Customer, Inventory, and Employee**.

----------------------------------------------------------------------------------------------------------------------------
-- 4. Check what table inside

SELECT * 
FROM INFORMATION_SCHEMA.TABLES;

-------------------------------------------------------------------------------------------------------------------------------
-- 5. View Specific Row 

-- View top 2 records from customer 
SELECT TOP 2* 
FROM Customer;

-- view top 40% records from customer 
SELECT TOP 40 percent * 
FROM Customer;

-----------------------------------------------------------------------------------------------------------------------------
-- 6. View specific columns
-- Retrieve customer first name, last name  from customer and order by ASC 

SELECT CustomerFirstName, CustomerLastName
FROM Customer
ORDER BY CustomerLastName;

-- order by based on column number without typing column name 

SELECT CustomerFirstName, CustomerLastName
FROM Customer
ORDER BY 1 DESC;
-- Refer column number from SELECT query following column name 

-- distinct - only show unique values 
SELECT DISTINCT CustomerLastName 
FROM Customer
ORDER BY CustomerLastName;
--------------------------------------------------------------------------------------------------
-- 7. Save table to another table -- temporary table
-- into file_name : save result in another table (BASE TABLE) 
SELECT DISTINCT CustomerLastName into temp
FROM Customer
ORDER BY CustomerLastName;

SELECT * from temp;

---------------------------------------------------------------------------------------------------
-- 8. LIKE (Search Something) 
-- Underscore sign (_) : is only specific for one character only
-- (percent sign) % represents zero, one, or multiple characters

SELECT * 
FROM Customer
WHERE CustomerFirstName LIKE '_r%';

-----------------------------------------------------------------------------------------------------
-- 9 IN (Search something) 
-- Search multiple items
SELECT * 
FROM Customer
WHERE CustomerFirstName IN ('Grace', 'Eric', 'Brian');

----------------------------------------------------------------------------------------------------------
-- 10 NOT Equal (<>) 

SELECT * 
FROM Customer
WHERE CustomerFirstName <> 'Grace';

-----------------------------------------------------------------------------------------------------------

-- 11. Check Null Values
SELECT * FROM Customer
WHERE CustomerLastName IS NULL;

-- 12. Is NOT NULL
SELECT * FROM Customer
WHERE CustomerLastName IS NOT NULL;

-- 13. BETWEEN 
SELECT * 
FROM Sales
WHERE SaleUnitPrice BETWEEN 5 and 80; -- not include 5 and 10 
-------------------------------------------------------------------------
-- 14. COUNT
-- return the number of rows in a table 
-- As means aliasing temporary giving name to a column /Table 
SELECT COUNT(*) as Total_customer,
CustomerFirstName
FROM Customer
WHERE CustomerFirstName LIKE 'B%'
GROUP BY CustomerFirstName;
---------------------------------------------------------------------
-- 16. sum 
SELECT Sales.EmployeeID,
EmployeeFirstName,
EmployeeLastName,
COUNT(*) AS Number_of_order,
SUM(SaleQuantity) As total_Quantity
FROM Sales,Employee
WHERE Sales.EmployeeID = Employee.EmployeeID
GROUP BY Sales.EmployeeID , EmployeeFirstName, EmployeeLastName;

-----------------------------------------------------------------------------
-- 17. Count month 
SELECT MONTH(SaleDate) as month_name,
COUNT(*) As Numberofsales,
SUM(SaleQuantity) * SUM(SaleUnitPrice) as total_amount
FROM Sales
GROUP BY MONTH(SaleDate);
------------------------------------------------------------------------
-- 18. max 

SELECT * from Sales;

SELECT * FROM Employee;

SELECT EmployeeID,
SUM(SaleQuantity)*SUM(SaleUnitPrice) as total_Sales
FROM Sales
GROUP BY EmployeeID
Order By total_Sales DESC;

-- if you want ALL employees tied for highest sales
WITH EmployeeSales AS (
SELECT EmployeeID,
SUM(SaleQuantity)*SUM(SaleUnitPrice) as total_Sales
FROM Sales
GROUP BY EmployeeID
)
SELECT * 
FROM EmployeeSales
WHERE total_Sales = (SELECT MAX(total_Sales) FROM EmployeeSales);

--------------------------------------------------------------------------------
--- 19.min 

WITH EmployeeSales AS (
SELECT EmployeeID,
SUM(SaleQuantity)*SUM(SaleUnitPrice) as total_Sales
FROM Sales
GROUP BY EmployeeID
)
SELECT * 
FROM EmployeeSales
WHERE total_Sales = (SELECT MIN(total_Sales) FROM EmployeeSales);
-------------------------------------------------------------------------
-- 20. average
WITH EmployeeSales AS (
SELECT
SUM(SaleQuantity)*SUM(SaleUnitPrice) as total_Sales
FROM Sales
)
SELECT * 
FROM EmployeeSales
WHERE total_Sales = (SELECT AVG(total_Sales) FROM EmployeeSales);
-------------------------------------------------------------------------------------------
-- 21. Having
-- Retreive the total sales of customer

SELECT C.CustomerFirstName,
C.CustomerLastName,
SUM(S.SaleQuantity) * SUM(S.SaleUnitPrice) AS Total_sales
FROM Sales S
INNER JOIN Customer C
ON S.CustomerID = C.CustomerID
GROUP BY C.CustomerFirstName,
C.CustomerLastName, C.CustomerID
HAVING C.CustomerID = 10
-----------------------------------------------------------------------------------------
-- 22. Change Data type temporary for use 
-- CAST & CONVERT - Both are use to change data type  into another data type 
-- for Example - '100' - 100 
-- 1. CAST - Converts a value from one data type to another 
SELECT CAST('100' AS INT) As Numbervalue;
-- NOW SQL treats 100 as an integer
SELECT CAST (1250.45 AS DECIMAL(10,2)) As Amount;

SELECT EmployeeID,
CAST(SUM(SaleQuantity * SaleUnitPrice) AS DECIMAL(10,2)) AS Total_Sales
FROM Sales
GROUP BY EmployeeID;

-- 2. CONVERT - Also changes one data type into another
-- CAST(expression AS data_type) 
-- CONVERT (data_type,expression) 
SELECT CONVERT(INT,'100') As Numbervalue;
SELECT CONVERT(VARCHAR(10), GETDATE(),103) As FormattedDate;

-- CAST 
SELECT CAST('ABC' AS INT);
-- Error becuase ABC cannot become an integer

-- TRY_CAST
SELECT TRY_CAST('ABD' AS INT);
-- Result will be NULL (instead of throwing an error) 
-----------------------------------------------------------------------------
-- 23 . CASE STATEMENT 
-- First Calculate sales for each transaction 
SELECT SalesID,
EmployeeID,
SaleQuantity,
SaleUnitPrice,
SaleQuantity *  SaleUnitPrice As total_sales,
CASE 
WHEN SaleQuantity*SaleUnitPrice>=1000 THEN 'High Sales'
WHEN SaleQuantity*SaleUnitPrice>=500 THEN 'Medium Sales'
ELSE 'Low Sales'
END AS Category
FROM Sales;

-- CASE With Employee Sales
SELECT EmployeeID,
SUM(SaleQuantity*SaleUnitPrice) As total_sales,
CASE 
WHEN SUM(SaleQuantity*SaleUnitPrice) >=1000
THEN 'Top Performer'
WHEN SUM(SaleQuantity*SaleUnitPrice)>=500
THEN 'Good Performer'
ELSE 'Needs Improvement'
END As Performance_Category
FROM Sales
GROUP BY EmployeeID
ORDER BY total_sales DESC;
-------------------------------------------------------------------------------




