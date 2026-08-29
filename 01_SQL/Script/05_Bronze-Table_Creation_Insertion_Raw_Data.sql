-- Bronze Table creation and Bulk Inserting the data through Excel 

-- What is Bronze?
-- Bronze should contain the data as received from the source.
-- Don't perform business transformation here
-- keep the source system data as it is 

-- we have 7 CSV files which comes from different data source systems
-- Extract all Data into Bronze layer


-- Table 1 : Create Customer Tables
-- 1. Drop Existing bronze.customers
IF OBJECT_ID('bronze.customers','U') IS NOT NULL
	DROP TABLE bronze.customers;
GO

-- 2. create bronze customers
CREATE TABLE bronze.customers(
    Customer_ID INT ,
    Customer_Name VARCHAR(100),
    Gender VARCHAR(20),
    date_of_birth DATE,
    Email VARCHAR(200),
    Phone_number VARCHAR(200),
    City VARCHAR(100),
    State VARCHAR(100),
    Customer_Segment VARCHAR(35),
    Registration_Date DATE,
    Cusotmer_Status VARCHAR(20)
);

SELECT * FROM bronze.customers;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.customers;
BULK INSERT bronze.customers
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\customers.csv'
WITH (
FIRSTROW=2,
FIELDTERMINATOR =',',
TABLOCK
);
-----------------------------------------------------------------------------------------
-- Table 2 : Create Employee Tables
-- 1. Drop Existing bronze.employee
IF OBJECT_ID('bronze.employee','U') IS NOT NULL
	DROP TABLE bronze.employee;
GO

-- 2. create bronze employee
CREATE TABLE bronze.employee(
    employee_id INT,
    employee_name VARCHAR(100),
    department VARCHAR(100),
    job_title VARCHAR(100),
    store_id INT,
    manager_id INT,
    joining_date DATE,
    employment_status VARCHAR(30),
    city VARCHAR(60),
    salary DECIMAL(10,2)

);

SELECT * FROM bronze.employee;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.employee;
BULK INSERT bronze.employee
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\employees.csv'
WITH (
FIRSTROW=2,
FIELDTERMINATOR =',',
TABLOCK
);

------------------------------------------------------------------------------------------------
-- Table 3 : Create inventory Tables
-- 1. Drop Existing bronze.inventory
IF OBJECT_ID('bronze.inventory','U') IS NOT NULL
	DROP TABLE bronze.inventory;
GO

-- 2. create bronze inventory
CREATE TABLE bronze.inventory(
    inventory_id INT,
    product_id INT,
    store_id INT,
    warehouse_id INT,
    snapshot_date	DATE,
    stock_quantity	INT,
    reserved_quantity INT,
    available_quantity INT,
    reorder_level INT,
    inventory_status VARCHAR(30)

);

SELECT * FROM bronze.inventory;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.inventory;
BULK INSERT bronze.inventory
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\inventory.csv'
WITH (
FIRSTROW=2,
FIELDTERMINATOR =',',
TABLOCK
);

------------------------------------------------------------------------------------------------------
-- Table 4 : Create products Tables
-- 1. Drop Existing bronze.products
IF OBJECT_ID('bronze.products','U') IS NOT NULL
	DROP TABLE bronze.products;
GO

-- 2. create bronze products
CREATE TABLE bronze.products(
  product_id INT,
  product_name	VARCHAR(100),
  category VARCHAR(80),
  subcategory	VARCHAR(80),
  brand	VARCHAR(100),
  unit_cost DECIMAL(10,2),
  selling_price	DECIMAL(10,2),
  supplier_id INT,
  product_status VARCHAR(20),
  launch_date DATE

);

SELECT * FROM bronze.products;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.products;
BULK INSERT bronze.products
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\products.csv'
WITH (
FIRSTROW=2,
FIELDTERMINATOR =',',
TABLOCK
);

--------------------------------------------------------------------------------------------------
-- Table 5 : Create returns Tables
-- 1. Drop Existing bronze.returns
IF OBJECT_ID('bronze.returns','U') IS NOT NULL
	DROP TABLE bronze.returns;
GO

-- 2. create bronze returns
CREATE TABLE bronze.returns(
return_id INT,
order_id INT,
customer_id	INT,
product_id	INT,
store_id INT,
return_date DATE,
return_quantity	INT,
return_amount DECIMAL(10,2),
return_reason VARCHAR(100),
return_status VARCHAR(100),
refund_amount DECIMAL(10,2)

);

SELECT * FROM bronze.returns;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.returns;
BULK INSERT bronze.returns
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\returns.csv'
WITH (
FIRSTROW=2,
FIELDTERMINATOR =',',
TABLOCK
);
---------------------------------------------------------------------------------------------------
-- Table 6 : Create sales Tables
-- 1. Drop Existing bronze.sales
IF OBJECT_ID('bronze.sales','U') IS NOT NULL
	DROP TABLE bronze.sales;
GO

-- 2. create bronze sales
CREATE TABLE bronze.sales(
order_id INT,
customer_id INT,
product_id	INT,
store_id INT,
employee_id	 INT,
order_date	DATE,
quantity INT,
unit_price	DECIMAL(10,2),
discount_amount DECIMAL(10,2),
sales_amount DECIMAL(10,2),
cost_amount DECIMAL(10,2),
profit_amount DECIMAL(10,2)
);

SELECT * FROM bronze.sales;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.sales;
BULK INSERT bronze.sales
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\sales.csv'
WITH (
FIRSTROW=2,
FIELDTERMINATOR =',',
TABLOCK
);

----------------------------------------------------------------------------------------------------
-- Table 7 : Create sales stores
-- 1. Drop Existing bronze.stores
IF OBJECT_ID('bronze.stores','U') IS NOT NULL
	DROP TABLE bronze.stores;
GO

-- 2. create bronze stores
CREATE TABLE bronze.stores(
store_id INT,
store_name VARCHAR(100),
city VARCHAR(100),
state VARCHAR(100),
region	VARCHAR(100),
store_type VARCHAR(100),
opening_date DATE,
manager_id INT,
store_status VARCHAR(100),
square_feet INT
);

SELECT * FROM bronze.stores;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.stores;
BULK INSERT bronze.stores
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\stores.csv'
WITH (
FIRSTROW=2,
FIELDTERMINATOR =',',
TABLOCK
);