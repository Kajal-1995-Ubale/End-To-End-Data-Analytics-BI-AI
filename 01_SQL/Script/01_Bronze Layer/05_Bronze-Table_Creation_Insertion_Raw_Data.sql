-- Bronze Table creation and Bulk Inserting the data through Excel 

-- What is Bronze?
-- Bronze should contain the data as received from the source.
-- Don't perform business transformation here
-- keep the source system data as it is 

-- we have 7 CSV files which comes from different data source systems
-- Extract all Data into Bronze layer

/*
I'm intentionally using VARCHAR for the Bronze fields.

Why?

Because Bronze's job is to capture the source data, not enforce the final business data types.

For example, if the source says:

manager_id = N/A

Bronze can store:

'N/A'

instead of failing the entire load.

Then Silver decides what to do with it.
*/
-- Table 1 : Create Customer Tables
-- 1. Drop Existing bronze.customers
IF OBJECT_ID('bronze.customers','U') IS NOT NULL
	DROP TABLE bronze.customers;
GO

-- 2. create bronze customers
CREATE TABLE bronze.customers(

    Customer_ID VARCHAR(50) ,
    Customer_Name VARCHAR(100),
    Gender VARCHAR(20),
    date_of_birth VARCHAR(50),
    Email VARCHAR(200),
    Phone_number VARCHAR(200),
    City VARCHAR(100),
    State VARCHAR(100),
    Customer_Segment VARCHAR(100),
    Registration_Date VARCHAR(50),
    Cusotmer_Status VARCHAR(20)
);

SELECT * FROM bronze.customers;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.customers;
BULK INSERT bronze.customers
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\customers.csv'
WITH (
 FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
-----------------------------------------------------------------------------------------
-- Table 2 : Create Employee Tables
-- 1. Drop Existing bronze.employee
DROP TABLE IF EXISTS bronze.employee;
GO
-- 2. Create employee table
CREATE TABLE bronze.employee
(
    employee_id        VARCHAR(50),
    employee_name      VARCHAR(100),
    department         VARCHAR(100),
    job_title          VARCHAR(100),
    store_id           VARCHAR(50),
    manager_id         VARCHAR(50),
    joining_date       VARCHAR(50),
    employment_status  VARCHAR(100),
    city               VARCHAR(60),
    salary             VARCHAR(50)
);
GO

SELECT * FROM bronze.employee;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.employee;
GO

BULK INSERT bronze.employee
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\employees.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

SELECT
    COLUMN_NAME,
    ORDINAL_POSITION,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'bronze'
  AND TABLE_NAME = 'employee'
ORDER BY ORDINAL_POSITION;

------------------------------------------------------------------------------------------------
-- Table 3 : Create inventory Tables
-- 1. Drop Existing bronze.inventory
IF OBJECT_ID('bronze.inventory','U') IS NOT NULL
	DROP TABLE bronze.inventory;
GO

-- 2. create bronze inventory
CREATE TABLE bronze.inventory(
    inventory_id VARCHAR(50),
    product_id VARCHAR(50),
    store_id VARCHAR(50),
    warehouse_id VARCHAR(50),
    snapshot_date	VARCHAR(50),
    stock_quantity	VARCHAR(50),
    reserved_quantity VARCHAR(50),
    available_quantity VARCHAR(50),
    reorder_level VARCHAR(50),
    inventory_status VARCHAR(30)

);

SELECT * FROM bronze.inventory;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.inventory;
BULK INSERT bronze.inventory
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\inventory.csv'
WITH (
FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
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
  product_id VARCHAR(50),
  product_name	VARCHAR(100),
  category VARCHAR(80),
  subcategory	VARCHAR(80),
  brand	VARCHAR(100),
  unit_cost VARCHAR(100),
  selling_price	VARCHAR(100),
  supplier_id VARCHAR(50),
  product_status VARCHAR(20),
  launch_date VARCHAR(50)

);

SELECT * FROM bronze.products;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.products;
BULK INSERT bronze.products
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\products.csv'
WITH (
FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
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
return_id VARCHAR(50),
order_id VARCHAR(50),
customer_id	VARCHAR(50),
product_id	VARCHAR(50),
store_id VARCHAR(50),
return_date VARCHAR(50),
return_quantity	VARCHAR(50),
return_amount VARCHAR(50),
return_reason VARCHAR(100),
return_status VARCHAR(100),
refund_amount VARCHAR(50)

);

SELECT * FROM bronze.returns;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.returns;
BULK INSERT bronze.returns
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\returns.csv'
WITH (
FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
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
order_id VARCHAR(50),
customer_id VARCHAR(50),
product_id	VARCHAR(50),
store_id VARCHAR(50),
employee_id	 VARCHAR(50),
order_date	VARCHAR(50),
quantity VARCHAR(50),
unit_price	VARCHAR(100),
discount_amount VARCHAR(100),
sales_amount VARCHAR(100),
cost_amount VARCHAR(100),
profit_amount VARCHAR(100)
);

SELECT * FROM bronze.sales;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.sales;
BULK INSERT bronze.sales
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\sales.csv'
WITH (
FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
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
store_id VARCHAR(50),
store_name VARCHAR(100),
city VARCHAR(100),
state VARCHAR(100),
region	VARCHAR(100),
store_type VARCHAR(100),
opening_date VARCHAR(50),
manager_id VARCHAR(50),
store_status VARCHAR(100),
square_feet VARCHAR(50)
);

SELECT * FROM bronze.stores;

-- 3. BULK INSERT DATA
TRUNCATE TABLE bronze.stores;
BULK INSERT bronze.stores
FROM 'D:\Data_Analyst_Bundle_Kit_By_Kajal\Retail_Mart_Project\Dataset\stores.csv'
WITH (
FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);