-- BRONZE DATA PROFILING
-- Before I clean the data, I need to understand what the data actually looks like,
-- what is wrong with it and what business rules the data should follow.

-- Step 1 - What exactly is DATA PROFILING?
-- Data Profiling means systematically examining the data to understand.
-- A. Structure
-- What columns Exist?
-- What are their data types?
-- What is the expected purpose of each column?

-- B. Completeness
-- Are important columns NULL?
-- Are there blank Values?

-- C. Uniqueness
-- Are primary key actually unique?
-- Are there duplicates?

-- D. Validity
-- Are values within acceptable ranges?
-- Eg. Quantity =-5, price =-100, discount = 500000

-- E. Consistency
-- Are values represented consistently?
-- Eg. Mumbai, mumbai, MUMBAI,    Mumbai

-- F. Accuracy 
-- Does the data make business sense?
-- Eg. Product Price = 500
-- Sales amount = 50000000000
-- quantity =1 
-- may be valid may not be valid but it nees investigation

-- G. Referential Integrity
-- Do relationships between tables actually work?
-- for eg. Sales.customer_id = customer.customer_id

-- H. Business Rule 
-- Does the data obey expected business logic
-- eg. Return date >= sale date
-- Return Quantity <= sales quantity

-- Step 2 : Dont profile all 7 tables randomly 
-- you should first understand the data model 
-- | Table     | Type          | Purpose               |
-- | --------- | ------------- | --------------------- |
-- | Customers | Dimension     | Customer information  |
-- | Products  | Dimension     | Product information   |
-- | Stores    | Dimension     | Store information     |
-- | Employee  | Dimension     | Employee information  |
-- | Sales     | Fact          | Sales transactions    |
-- | Returns   | Fact          | Returned transactions |
-- | Inventory | Fact/Snapshot | Stock information     |

-- Step 3: Profiling phase 1 - table level profiling
-- First ASk - What tables do I have and how much data is in each ?
SELECT 'customers' AS table_name, COUNT(*) AS record_count
FROM bronze.customers

UNION ALL

SELECT 'products', COUNT(*)
FROM bronze.products

UNION ALL

SELECT 'stores', COUNT(*)
FROM bronze.stores

UNION ALL

SELECT 'employee', COUNT(*)
FROM bronze.employee

UNION ALL

SELECT 'sales', COUNT(*)
FROM bronze.sales

UNION ALL

SELECT 'returns', COUNT(*)
FROM bronze.returns

UNION ALL

SELECT 'inventory', COUNT(*)
FROM bronze.inventory;

-- Step 4 : phase 2 - Understand the columns 

-- Before writing cleaninf queries, Create a Data Dictionary 
-- already created in excel refere excel sheet

-- Step 5 : phase 3 - Record Count
-- you have got 30k records each table 
-- But record count should be checked before and after every transformation 

SELECT COUNT(*) as total_records
FROM bronze.customers;
-- do this for all tables

-- Step 6 : Phase 4- NULL Profiling
-- Suppose customer has : customer_id, customer_name, email , Phone, city, state
-- DON'T JUST ASK: Does Customer_id have NULL?

-- Instead calculate : NULL count + NULL percentage
SELECT TOP 1* FROM 
bronze.customers;

SELECT 
COUNT(*) as total_records,
 SUM(CASE 
	 WHEN customer_id IS NULL THEN 1 
	 ELSE 0 
	 END) as customer_id_nulls,

SUM(CASE 
	 WHEN Customer_Name IS NULL THEN 1 
	 ELSE 0 
	 END) as customer_name_nulls,

SUM(CASE 
	 WHEN Gender IS NULL THEN 1 
	 ELSE 0 
	 END) as Gender,

SUM(CASE 
	 WHEN date_of_birth IS NULL THEN 1 
	 ELSE 0 
	 END) as date_of_birth,

SUM(CASE 
	 WHEN Email IS NULL THEN 1 
	 ELSE 0 
	 END) as email
FROM bronze.customers

-- Step 7: Blank String Profiling
-- WHERE email IS NULL
-- does not find space

-- so check both NULL and blank values 
SELECT COUNT(*) as blank_email_count 
FROM bronze.customers
WHERE Email IS NULL OR LTRIM(RTRIM(Email)) = '';

-- Step 8: Duplicate profiling
-- suppose primary keys are actullay unique

SELECT Customer_ID,
COUNT(*) as record_count
FROM bronze.customers
GROUP BY Customer_ID
HAVING COUNT(*) >1;

-- suppose you get
-- C001    2
-- C005    3
-- C100    2

-- you have duplicate keys
-- But don't immediately delete them 

-- first investigate
SELECT *
FROM bronze.customers
WHERE customer_id IN ('C001', 'C005', 'C100');

-- Case 1 - Exact duplicate
-- C001 | Amit | Mumbai | Maharashtra
-- C001 | Amit | Mumbai | Maharashtra
-- likely a duplicate records

-- Case 2 - Different information 
-- C001 | Amit | Mumbai | Maharashtra
-- C001 | Amit | Pune  | Maharashtra
/*
This could represent:

customer moved
source-system update
duplicate customer
incorrect source data

This requires a business decision.
*/

-- Duplicate profiling should be done at multiple levels
-- don't check the primary key 
-- For example, customers might have duplicate emails:
SELECT
    email,
    COUNT(*) AS cnt
FROM bronze.customers
WHERE email IS NOT NULL
GROUP BY email
HAVING COUNT(*) > 1;

-- Step 8 : phase 7 - Distince Value profiling 
-- for categorical fields: 
SELECT DISTINCT state
FROM bronze.customers
ORDER BY state;
-- suppose you find: 
/* Maharashtra
maharashtra
MAHARASHTRA
Maharastra
 Maharashtra*/

-- now you have identifies a standardization issue.

-- FREQUENCY Profiling
-- Don't just use DISTINCT
-- USE frequency
SELECT
    state,
    COUNT(*) AS customer_count
FROM bronze.customers
GROUP BY state
ORDER BY customer_count DESC;

-- if you find 
-- Maharashtra      8,500
-- Maharastra           7
-- MAHARASHTRA          5

-- you know standardization is required

-- Step 9 : phase 8 - Data Type Profiling
-- now examine whether the data types make sense
-- for example 
/*
sales_amount → should be DECIMAL
quantity → should be INT
transaction_date → should be DATE
customer_id → VARCHAR

-- IF bronze has: 
sales_amount VARCHAR
quantity VARCHAR
transaction_date VARCHAR
--that's okay for raw ingestion.

--But Silver should convert them.
TRY_CAST(quantity AS INT)
TRY_CAST(sales_amount AS DECIMAL(12,2))
*/

-- INVALID DATA TYPE PROFILING
SELECT *
FROM bronze.sales
WHERE TRY_CAST(quantity AS INT) IS NULL
  AND quantity IS NOT NULL;
-- suppose you find: 
/*quantity
--------
5
10
N/A
abc
five*/

-- now you know exactly what need investigation 

-- Step 10 - Phase 9 - Range Validation 
-- This is where you start applying business logic
SELECT *
FROM bronze.sales
WHERE TRY_CAST(sales_amount AS DECIMAL(12,2)) < 0;

-- Product price validation 
-- suppose : cost, price
-- Business rule : price>=cost
-- you could profile
SELECT *
FROM bronze.products
WHERE TRY_CAST(selling_price AS DECIMAL(12,2))
    < TRY_CAST(unit_cost AS DECIMAL(12,2));

/*
If 200 products violate this, investigate.

It could be:

genuine discount pricing
incorrect cost
incorrect price
clearance product

Again:

Profiling identifies the issue. Business rules decide the treatment.
*/

-- Step 11: Phase 10 - DATE profiling
-- Date are extremely important
SELECT DISTINCT order_date
FROM bronze.sales
ORDER BY order_date;
-- look for:
-- 2024-05-23
-- 23-05-2024
-- 05/23/2024
-- 2024/05/23

-- also check impossible dates
SELECT *
FROM bronze.sales
WHERE TRY_CONVERT(DATE, order_date) IS NULL
  AND order_date IS NOT NULL;
-- you might find
--31-02-2024
--abc
--N/A

-- Step 12- Phase 11 - Future DATE Profiling
/*
Suppose your dataset ends in 2025.

You shouldn't have a sale in 2035.

You can check:

SELECT *
FROM bronze.sales
WHERE TRY_CONVERT(DATE, transaction_date) > GETDATE();

Depending on your dataset's business timeline, you may instead compare against a known maximum allowed date.
*/

-- Step 13 - Phase 12 - Referential Integrity 
-- This is one of the most important parts of your RetailMart profiling.

-- You have relationships.

-- For example:

-- sales.customer_id
--       ↓
-- customers.customer_id

-- Find sales records whose customer doesn't exist:

SELECT s.customer_id
FROM bronze.sales s
LEFT JOIN bronze.customers c
    ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Suppose:

-- 2,000 sales records
-- have no matching customer.That's a major data-quality issue.

-- do the same for products
-- Sales--> store
-- Inventory -->products
-- Inventory --> stores
-- Employee --> stores

-- Step 14: phase 13 : Business Rule profiling
/*
This is where your project starts looking professional.

-- Sales rules

-- Potential rules:

transaction_id must exist
customer_id must exist
product_id must exist
store_id must exist
quantity > 0
sales_amount >= 0
transaction_date should be valid

-- Returns
-- Potential rules:

return_id must exist
transaction_id should exist
product_id should exist
return_date >= sale_date
return_quantity > 0
return_quantity <= sold_quantity

-- Inventory
product_id must exist
store_id must exist
quantity >= 0

-- Products
product_id must exist
product_name must exist
price >= 0
cost >= 0

-- Stores
store_id must exist
store_name must exist
state should be valid
*/

/*
Returns — A Very Important Cross-Table Check

This is an excellent interview scenario.

Suppose:

Sales

transaction_id = T100
product_id = P001
quantity = 3

Returns:

return_id = R001
transaction_id = T100
product_id = P001
return_quantity = 5

That's suspicious.

You sold:

3

but returned:

5

So you can identify:

SELECT
    r.return_id,
    r.transaction_id,
    r.product_id,
    r.return_quantity,
    s.quantity AS sold_quantity
FROM bronze.returns r
JOIN bronze.sales s
    ON r.transaction_id = s.transaction_id
   AND r.product_id = s.product_id
WHERE r.return_quantity > s.quantity;

That's real business-data profiling, not just SQL syntax practice.
*/

-- Step 15: phase 14 - orphan returns
/*
Yes — that is actually the better approach for your RetailMart project, because it teaches you the real Data Analyst / Data Warehouse flow instead of practicing on messy raw data.

Think of your layers like this:

Bronze → Silver → Gold → Tableau
 Raw       Clean     Business
Data      Data       Data
🥉 Bronze Layer — Don't clean it

Bronze should represent the raw/source data as received.

Example:

Bronze.transactions
--------------------------------
transaction_id
transaction_date
customer_id
sales_amount
quantity

You may have:

NULLs
duplicate records
inconsistent dates
invalid values
extra spaces
incorrect data types
duplicate transactions

Don't modify Bronze directly.

🥈 Silver Layer — Clean & standardize

This is where you perform data-quality transformations.

For example:

SELECT
    transaction_id,
    CAST(transaction_date AS DATE) AS transaction_date,
    customer_id,
    quantity,
    sales_amount
FROM bronze.transactions
WHERE transaction_id IS NOT NULL;

You might also handle:

✓ NULL handling
✓ Duplicate removal
✓ Data type conversion
✓ Date standardization
✓ Trim spaces
✓ Invalid records
✓ Standardizing categorical values
✓ Basic data validation

So yes — create your Silver tables and practice your SQL on Silver.

🥇 Gold Layer — Business-ready data

Gold is where you create datasets specifically useful for reporting/analytics.

For example:

gold.monthly_sales
gold.store_sales
gold.product_sales
gold.customer_sales

Example:

SELECT
    store_id,
    SUM(sales_amount) AS total_sales
FROM silver.transactions
GROUP BY store_id;

This is closer to what Tableau would consume.

⭐ But here's an important point for your Day 5

Don't completely skip Bronze.

Since you're preparing for Data Analyst / BI interviews, I recommend this flow:

Step 1 — Bronze

Understand the raw data.

Ask:

"What problems exist in my source data?"

Step 2 — Silver

Write SQL transformations to clean it.

Ask:

"How do I make this data reliable?"

Step 3 — Practice SQL

Use Silver data for your normal SQL practice:

WHERE
AND
OR
IN
BETWEEN
LIKE
IS NULL
JOIN
GROUP BY
HAVING
Window Functions
CTEs
etc.
Step 4 — Gold

Create business-level datasets/KPIs.

Step 5 — Tableau

Connect Tableau to Gold/business-ready tables.

🔥 For your RetailMart project

I'd structure it like this:

RetailMart
│
├── 01_SQL
│   ├── Queries
│   │   ├── Day_01_Select.sql
│   │   ├── Day_02_Filtering.sql
│   │   ├── Day_03_Aggregations.sql
│   │   ├── Day_04_GroupBy.sql
│   │   └── Day_05_Filtering.sql
│   │
│   ├── Bronze
│   │   └── transactions
│   │
│   ├── Silver
│   │   └── transactions_clean
│   │
│   └── Gold
│       ├── store_sales
│       ├── product_sales
│       └── monthly_sales
│
├── 02_Tableau
├── 03_Python
└── 04_Excel
One thing I would change in your current approach:

Don't create Silver just for the sake of practicing SQL.

First inspect Bronze and identify the actual data-quality problems. Then create Silver transformations to solve those problems.

That gives you a real project story for interviews:

"I received raw transactional data in the Bronze layer. I profiled the data, identified data-quality issues, and created a cleaned Silver layer by handling nulls, duplicates, inconsistent data types and invalid records. I then created business-ready Gold datasets for Tableau reporting."

That sounds much stronger than:

"I practiced SQL queries on a table."

Your Day 5 flow should therefore be:

Bronze → Profile → Silver cleaning → Practice filtering on Silver → Gold later

And your ₹5,000–₹10,000 customer scenario should be executed against the cleaned Silver tables.

If you want, we can 
make your RetailMart Bronze → Silver layer properly from scratch, including 
which columns to clean, 
what SQL transformations to write, and 
the Silver table creation script before continuing Day 5.

Make the RetailMart Bronze → Silver layer properly from scratch

Absolutely. Let's build the RetailMart Bronze → Silver layer like a real production-style data project, but keep it simple enough for you to understand and explain in interviews.

The key principle:

Bronze = raw data exactly as received → Silver = cleaned, standardized, validated data → Gold = business-ready analytics.

For now, we'll build Bronze → Silver only. Then your Day 5 filtering practice will happen on the Silver layer.

🏪 RetailMart — Bronze → Silver Architecture

We'll use this structure:

                 SOURCE CSV / EXCEL
                        │
                        ▼
                 🥉 BRONZE LAYER
                 Raw tables
                        │
                 Data Profiling
                        │
                        ▼
                 🥈 SILVER LAYER
              Cleaned & standardized
                        │
                        ▼
                 🥇 GOLD LAYER
             Business / KPI tables
                        │
                        ▼
                    TABLEAU

For our project, let's start with these tables:

Bronze
├── customers
├── products
├── stores
└── transactions

Silver
├── customers_clean
├── products_clean
├── stores_clean
└── transactions_clean
🥉 STEP 1 — Bronze Layer
What is Bronze?

Bronze should contain the data as received from the source.

Don't perform business transformations here.

For example, suppose your raw customer file looks like:

customer_id	customer_name	city	state	email
C001	Kajal Ubale	Mumbai	Maharashtra	kajal@gmail.com
C002	Amit	Pune	Maharashtra	amit@gmail.com
C003	NULL	Thane	Maharashtra	NULL
C004	Sneha	Mumbai	Maharashtra	sneha@gmail.com

Notice:

extra spaces
NULL customer name
NULL email

That's okay in Bronze.

🧱 STEP 2 — Create Bronze Schema

If you're using SQL Server:

CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO

Now you have:

bronze
silver
gold
🥉 STEP 3 — Bronze Tables
Customers
CREATE TABLE bronze.customers
(
    customer_id     VARCHAR(20),
    customer_name   VARCHAR(100),
    city            VARCHAR(100),
    state           VARCHAR(100),
    email           VARCHAR(150)
);

Notice that we're not aggressively enforcing constraints here.

Bronze is meant to preserve the source data.

Products
CREATE TABLE bronze.products
(
    product_id      VARCHAR(20),
    product_name    VARCHAR(150),
    category        VARCHAR(100),
    subcategory     VARCHAR(100),
    cost            DECIMAL(12,2),
    price           DECIMAL(12,2)
);
Stores
CREATE TABLE bronze.stores
(
    store_id        VARCHAR(20),
    store_name      VARCHAR(150),
    city            VARCHAR(100),
    state           VARCHAR(100),
    region          VARCHAR(50)
);
Transactions
CREATE TABLE bronze.transactions
(
    transaction_id   VARCHAR(30),
    transaction_date VARCHAR(30),
    customer_id      VARCHAR(20),
    store_id         VARCHAR(20),
    product_id       VARCHAR(20),
    quantity         VARCHAR(20),
    sales_amount     VARCHAR(30),
    discount_amount  VARCHAR(30)
);
Why are some transaction columns VARCHAR?

Because raw files often contain messy values.

For example:

quantity
--------
2
5
NULL
"3 "
N/A

and:

transaction_date
----------------
2024-05-23
23-05-2024
05/23/2024

We don't want the Bronze ingestion process to fail just because one source value is malformed.

🔍 STEP 4 — Profile the Bronze Data

This step is very important.

Before cleaning anything, inspect the data.

You should be able to say in an interview:

"I first performed data profiling on the Bronze layer to identify nulls, duplicates, invalid values, inconsistent formats and data-quality issues."

Check total records
SELECT COUNT(*) AS total_records
FROM bronze.transactions;
Check NULLs
SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN transaction_id IS NULL THEN 1 ELSE 0 END) AS null_transaction_id,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN store_id IS NULL THEN 1 ELSE 0 END) AS null_store_id,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id
FROM bronze.transactions;
🔁 STEP 5 — Check Duplicates

For transaction IDs:

SELECT
    transaction_id,
    COUNT(*) AS duplicate_count
FROM bronze.transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1;

If you get:

T001    2
T015    3

you have duplicate transaction IDs.

💰 STEP 6 — Check Invalid Sales Amounts
SELECT *
FROM bronze.transactions
WHERE TRY_CAST(sales_amount AS DECIMAL(12,2)) < 0;

Depending on your business rules, negative sales might be invalid—or they might represent returns.

Don't automatically delete them.

That's an important real-world lesson.

You first need to understand the business meaning.

📅 STEP 7 — Check Invalid Dates
SELECT
    transaction_date
FROM bronze.transactions
WHERE TRY_CONVERT(DATE, transaction_date, 23) IS NULL;

If your raw data contains multiple formats, we'll standardize them in Silver.

🥈 STEP 8 — Create Silver Customers

Now we start cleaning.

CREATE TABLE silver.customers_clean
(
    customer_id     VARCHAR(20),
    customer_name   VARCHAR(100),
    city            VARCHAR(100),
    state           VARCHAR(100),
    email           VARCHAR(150)
);

Load cleaned data:

INSERT INTO silver.customers_clean
(
    customer_id,
    customer_name,
    city,
    state,
    email
)
SELECT
    TRIM(customer_id),
    TRIM(customer_name),
    TRIM(city),
    TRIM(state),
    NULLIF(TRIM(email), '')
FROM bronze.customers
WHERE NULLIF(TRIM(customer_id), '') IS NOT NULL;
What did we do?
TRIM()
    ↓
Removed unnecessary spaces

NULLIF()
    ↓
Converted blank values to NULL

WHERE
    ↓
Removed records without customer_id
🥈 STEP 9 — Silver Products
CREATE TABLE silver.products_clean
(
    product_id      VARCHAR(20),
    product_name    VARCHAR(150),
    category        VARCHAR(100),
    subcategory     VARCHAR(100),
    cost            DECIMAL(12,2),
    price           DECIMAL(12,2)
);

Load:

INSERT INTO silver.products_clean
(
    product_id,
    product_name,
    category,
    subcategory,
    cost,
    price
)
SELECT
    TRIM(product_id),
    TRIM(product_name),
    TRIM(category),
    TRIM(subcategory),
    TRY_CAST(cost AS DECIMAL(12,2)),
    TRY_CAST(price AS DECIMAL(12,2))
FROM bronze.products
WHERE NULLIF(TRIM(product_id), '') IS NOT NULL;
🥈 STEP 10 — Silver Stores
CREATE TABLE silver.stores_clean
(
    store_id        VARCHAR(20),
    store_name      VARCHAR(150),
    city            VARCHAR(100),
    state           VARCHAR(100),
    region          VARCHAR(50)
);

Load:

INSERT INTO silver.stores_clean
(
    store_id,
    store_name,
    city,
    state,
    region
)
SELECT
    TRIM(store_id),
    TRIM(store_name),
    TRIM(city),
    TRIM(state),
    TRIM(region)
FROM bronze.stores
WHERE NULLIF(TRIM(store_id), '') IS NOT NULL;
🥈 STEP 11 — Most Important: Silver Transactions

This is where most of your SQL learning will happen.

Create the table:

CREATE TABLE silver.transactions_clean
(
    transaction_id   VARCHAR(30),
    transaction_date DATE,
    customer_id      VARCHAR(20),
    store_id         VARCHAR(20),
    product_id       VARCHAR(20),
    quantity         INT,
    sales_amount     DECIMAL(12,2),
    discount_amount  DECIMAL(12,2)
);

Now transform Bronze → Silver:

INSERT INTO silver.transactions_clean
(
    transaction_id,
    transaction_date,
    customer_id,
    store_id,
    product_id,
    quantity,
    sales_amount,
    discount_amount
)
SELECT
    TRIM(transaction_id),

    TRY_CONVERT(DATE, TRIM(transaction_date)),

    TRIM(customer_id),
    TRIM(store_id),
    TRIM(product_id),

    TRY_CAST(quantity AS INT),

    TRY_CAST(sales_amount AS DECIMAL(12,2)),

    TRY_CAST(discount_amount AS DECIMAL(12,2))

FROM bronze.transactions

WHERE NULLIF(TRIM(transaction_id), '') IS NOT NULL;
⚠️ But Don't Stop Here

A good Silver layer doesn't just change data types.

We should validate the cleaned data.

For example:

Check invalid quantities
SELECT *
FROM silver.transactions_clean
WHERE quantity <= 0;
Check invalid sales
SELECT *
FROM silver.transactions_clean
WHERE sales_amount < 0;
Check missing customer IDs
SELECT *
FROM silver.transactions_clean
WHERE customer_id IS NULL;
Check duplicate transactions
SELECT
    transaction_id,
    COUNT(*) AS cnt
FROM silver.transactions_clean
GROUP BY transaction_id
HAVING COUNT(*) > 1;
🧠 One Important Correction About "Cleaning"

Don't blindly do this:

DELETE FROM bronze.transactions
WHERE ...

❌ Don't modify Bronze.

Instead:

Bronze
   ↓
Transformation
   ↓
Silver

Bronze remains your raw historical source.

🔥 Your Actual RetailMart Flow

Now your project becomes:

                    CSV / Excel
                        │
                        ▼
              ┌──────────────────┐
              │  BRONZE          │
              │                  │
              │ customers        │
              │ products         │
              │ stores           │
              │ transactions     │
              └────────┬─────────┘
                       │
                 Data Profiling
                       │
                       ▼
              ┌──────────────────┐
              │  SILVER          │
              │                  │
              │ customers_clean  │
              │ products_clean   │
              │ stores_clean     │
              │ transactions_clean
              └────────┬─────────┘
                       │
                 SQL Analysis
                       │
                       ▼
              ┌──────────────────┐
              │  GOLD            │
              │                  │
              │ Store Sales      │
              │ Product Sales    │
              │ Monthly Sales    │
              │ Customer Sales   │
              └────────┬─────────┘
                       │
                       ▼
                    Tableau
📌 And NOW Your Day 5 Practice

Once silver.transactions_clean exists, this becomes your practice table.

Your original Day 5 scenario:

Find customers who purchased between ₹5,000 and ₹10,000.

Start with:

SELECT
    customer_id,
    transaction_id,
    sales_amount
FROM silver.transactions_clean
WHERE sales_amount BETWEEN 5000 AND 10000;

Then we'll progressively make it harder:

BETWEEN
   ↓
AND
   ↓
OR
   ↓
IN
   ↓
LIKE
   ↓
IS NULL
   ↓
IS NOT NULL
   ↓
JOIN customers
   ↓
Real business scenarios
🎯 So your learning rule from now on:

Bronze = understand and profile

Silver = clean and validate

Silver = your primary SQL practice layer

Gold = create business KPIs

Tableau = visualize Gold/business-ready data

That's the flow I recommend for your RetailMart project and interview preparation.

Today 3:33 PM
Explain deeply how to profile the bronze data - I have source system tables uploaded into bronze schema with 30k records each table - Customer, inventory, sales, stores, employee, returns and products .. I want you to explain deeply how to do data profiling before moving to silver layer 

Absolutely. Since your Bronze schema already contains the 7 source-system tables with ~30K records each, this is the right time to pause and do proper data profiling before creating Silver.

For your RetailMart project, think of profiling as:

“Before I clean the data, I need to understand what the data actually looks like, what is wrong with it, and what business rules the data should follow.”

You should not start cleaning just because you see NULLs or duplicates. First identify the issues, measure them, determine their business meaning, and then decide the Silver transformation.

🏪 RetailMart — Bronze Data Profiling

Your current Bronze layer:

BRONZE
│
├── customers      ~30K
├── inventory      ~30K
├── sales          ~30K
├── stores         ~30K
├── employee       ~30K
├── returns        ~30K
└── products       ~30K

Your target:

BRONZE
   │
   │  ① Profile
   │  ② Identify issues
   │  ③ Define rules
   │  ④ Clean
   ▼
SILVER
1. What exactly is Data Profiling?

Data profiling means systematically examining the data to understand:

A. Structure

What columns exist?

What are their data types?

What is the expected purpose of each column?

B. Completeness

Are important columns NULL?

Are there blank values?

C. Uniqueness

Are primary keys actually unique?

Are there duplicates?

D. Validity

Are values within acceptable ranges?

Example:

quantity = -5
price = -100
discount = 500000
E. Consistency

Are values represented consistently?

Example:

Mumbai
mumbai
MUMBAI
 Mumbai
F. Accuracy

Does the data make business sense?

Example:

Product price = ₹500
Sales amount = ₹50,000,000
Quantity = 1

Maybe valid, maybe not—but it needs investigation.

G. Referential integrity

Do relationships between tables actually work?

For example:

sales.customer_id
       ↓
customers.customer_id

Does every sales customer actually exist in customers?

H. Business rules

Does the data obey expected business logic?

Example:

Return date >= Sale date
Return quantity <= Sale quantity
Inventory quantity >= 0
Employee store_id exists in stores
2. Don't Profile All 7 Tables Randomly

This is important.

You should first understand the data model.

For RetailMart, I'd classify them as:

Table	Type	Purpose
Customers	Dimension	Customer information
Products	Dimension	Product information
Stores	Dimension	Store information
Employee	Dimension	Employee information
Sales	Fact	Sales transactions
Returns	Fact	Returned transactions
Inventory	Fact/Snapshot	Stock information

So conceptually:

                 PRODUCTS
                    │
                    │
CUSTOMERS ─────── SALES ─────── STORES
                    │
                    │
                 RETURNS

STORES ───── EMPLOYEE

STORES ───── INVENTORY ───── PRODUCTS

This immediately tells you what relationships you should eventually validate.

3. Profiling Phase 1 — Table-Level Profiling

First ask:

What tables do I have and how much data is in each?

Run:

SELECT 'customers' AS table_name, COUNT(*) AS record_count
FROM bronze.customers

UNION ALL

SELECT 'products', COUNT(*)
FROM bronze.products

UNION ALL

SELECT 'stores', COUNT(*)
FROM bronze.stores

UNION ALL

SELECT 'employee', COUNT(*)
FROM bronze.employee

UNION ALL

SELECT 'sales', COUNT(*)
FROM bronze.sales

UNION ALL

SELECT 'returns', COUNT(*)
FROM bronze.returns

UNION ALL

SELECT 'inventory', COUNT(*)
FROM bronze.inventory;

You might get:

customers       30,000
products        30,000
stores          30,000
employee        30,000
sales           30,000
returns         30,000
inventory       30,000

But 30K in every table should make you curious.

It is not automatically wrong.

Ask:

Why does every table have exactly 30,000 records?

If these came from independent source-system extracts, exactly equal counts could be suspicious.

This is an example of why profiling isn't just "checking NULLs."

4. Phase 2 — Understand the Columns

Before writing cleaning queries, create a Data Dictionary.

For example:

Customers
Column	Expected Meaning	Expected Type	Key?
customer_id	Unique customer	VARCHAR	PK
customer_name	Customer name	VARCHAR	No
email	Customer email	VARCHAR	No
city	Customer city	VARCHAR	No
state	Customer state	VARCHAR	No

Do the same for all 7 tables.

You want to know:

Column
Data Type
Nullable?
Primary Key?
Foreign Key?
Business Meaning
Expected Values

This becomes extremely useful when building Silver.

5. Phase 3 — Record Count

You've already got approximately 30K records each.

But record count should be checked before and after every transformation.

For each Bronze table:

SELECT COUNT(*) AS total_records
FROM bronze.customers;

Do this for:

customers
products
stores
employee
sales
returns
inventory

Create a profiling document:

Table	Bronze Records
Customers	30,000
Products	30,000
Stores	30,000
Employee	30,000
Sales	30,000
Returns	30,000
Inventory	30,000
6. Phase 4 — NULL Profiling

This is one of the most important checks.

Suppose customers has:

customer_id
customer_name
email
phone
city
state

Don't just ask:

"Does customer_id have NULL?"

Instead calculate:

NULL count + NULL percentage
SELECT
    COUNT(*) AS total_records,

    SUM(CASE
        WHEN customer_id IS NULL THEN 1
        ELSE 0
    END) AS customer_id_nulls,

    SUM(CASE
        WHEN customer_name IS NULL THEN 1
        ELSE 0
    END) AS customer_name_nulls,

    SUM(CASE
        WHEN email IS NULL THEN 1
        ELSE 0
    END) AS email_nulls,

    SUM(CASE
        WHEN city IS NULL THEN 1
        ELSE 0
    END) AS city_nulls
FROM bronze.customers;

Then calculate percentage:

SELECT
    COUNT(*) AS total_records,

    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) AS null_count,

    CAST(
        100.0 * SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END)
        / COUNT(*)
        AS DECIMAL(5,2)
    ) AS null_percentage

FROM bronze.customers;

Suppose:

Total records = 30,000
Email NULL = 3,000

Then:

NULL % = 10%

That's much more useful than simply saying:

"Email has NULLs."

7. NULL Does NOT Always Mean Data Quality Error

This is a very important interview concept.

Suppose:

employee.middle_name

is NULL.

That's probably acceptable.

But:

sales.customer_id

is NULL.

That could be a serious problem.

So classify NULLs:

Critical NULL
Acceptable NULL
Business-dependent NULL

Example:

Column	NULL?	Severity
customer_id	Yes	🔴 Critical
customer_name	Yes	🟠 High
email	Yes	🟡 Medium
middle_name	Yes	🟢 Low
8. Phase 5 — Blank String Profiling

This is something beginners often miss.

This:

WHERE email IS NULL

doesn't find:

''
' '
'     '

So check both NULL and blank values.

SELECT COUNT(*) AS blank_email_count
FROM bronze.customers
WHERE email IS NULL
   OR LTRIM(RTRIM(email)) = '';

Better:

SELECT COUNT(*) AS missing_email_count
FROM bronze.customers
WHERE NULLIF(TRIM(email), '') IS NULL;

This is especially useful when your source is CSV/Excel.

9. Phase 6 — Duplicate Profiling

Now determine whether your supposed primary keys are actually unique.

For customers:

SELECT
    customer_id,
    COUNT(*) AS record_count
FROM bronze.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

If you get:

C001    2
C005    3
C100    2

you have duplicate keys.

But don't immediately delete them.

First investigate:

SELECT *
FROM bronze.customers
WHERE customer_id IN ('C001', 'C005', 'C100');

You might discover:

Case 1 — Exact duplicate
C001 | Amit | Mumbai | Maharashtra
C001 | Amit | Mumbai | Maharashtra

Likely duplicate record.

Case 2 — Different information
C001 | Amit | Mumbai | Maharashtra
C001 | Amit | Pune  | Maharashtra

This could represent:

customer moved
source-system update
duplicate customer
incorrect source data

This requires a business decision.

10. Duplicate Profiling Should Be Done at Multiple Levels

Don't only check the primary key.

For example, customers might have duplicate emails:

SELECT
    email,
    COUNT(*) AS cnt
FROM bronze.customers
WHERE email IS NOT NULL
GROUP BY email
HAVING COUNT(*) > 1;

You could also check:

customer_id
email
phone
customer_name + city

Different duplicate rules can reveal different problems.

11. Phase 7 — Distinct Value Profiling

For categorical fields:

SELECT DISTINCT state
FROM bronze.customers
ORDER BY state;

Suppose you find:

Maharashtra
maharashtra
MAHARASHTRA
Maharastra
 Maharashtra

Now you have identified a standardization issue.

Similarly:

SELECT DISTINCT category
FROM bronze.products;

Look for:

Electronics
electronics
ELECTRONICS
Electronic

This is exactly the kind of issue Silver should fix.

12. Frequency Profiling

Don't just use DISTINCT.

Use frequency.

SELECT
    state,
    COUNT(*) AS customer_count
FROM bronze.customers
GROUP BY state
ORDER BY customer_count DESC;

This tells you:

Maharashtra      8,500
Gujarat          5,200
Karnataka        4,800
...

If you find:

Maharashtra      8,500
Maharastra           7
MAHARASHTRA          5

you know standardization is required.

13. Phase 8 — Data Type Profiling

Now examine whether the data types make sense.

For example:

sales_amount → should be DECIMAL
quantity → should be INT
transaction_date → should be DATE
customer_id → VARCHAR

If Bronze has:

sales_amount VARCHAR
quantity VARCHAR
transaction_date VARCHAR

that's okay for raw ingestion.

But Silver should convert them.

For example:

TRY_CAST(quantity AS INT)

and:

TRY_CAST(sales_amount AS DECIMAL(12,2))
14. Invalid Data Type Profiling

Before converting:

SELECT *
FROM bronze.sales
WHERE TRY_CAST(quantity AS INT) IS NULL
  AND quantity IS NOT NULL;

Suppose you find:

quantity
--------
5
10
N/A
abc
five

Now you know exactly what needs investigation.

Similarly:

SELECT *
FROM bronze.sales
WHERE TRY_CAST(sales_amount AS DECIMAL(12,2)) IS NULL
  AND sales_amount IS NOT NULL;
15. Phase 9 — Range Validation

This is where you start applying business logic.

Sales
SELECT *
FROM bronze.sales
WHERE TRY_CAST(sales_amount AS DECIMAL(12,2)) < 0;

But remember:

Negative sales might represent returns.

So don't automatically classify them as invalid.

Quantity
SELECT *
FROM bronze.sales
WHERE TRY_CAST(quantity AS INT) <= 0;

Possible result:

quantity = -2
quantity = 0

Investigate.

16. Product Price Validation

Suppose:

cost
price

Business rule:

price >= cost

You could profile:

SELECT *
FROM bronze.products
WHERE TRY_CAST(price AS DECIMAL(12,2))
    < TRY_CAST(cost AS DECIMAL(12,2));

If 200 products violate this, investigate.

It could be:

genuine discount pricing
incorrect cost
incorrect price
clearance product

Again:

Profiling identifies the issue. Business rules decide the treatment.

17. Inventory Profiling

For inventory, check:

SELECT *
FROM bronze.inventory
WHERE TRY_CAST(quantity AS INT) < 0;

Negative inventory may be invalid.

Also check:

product_id
store_id
inventory_date
quantity

You should eventually validate:

product exists
store exists
quantity >= 0
18. Phase 10 — Date Profiling

Dates are extremely important.

First inspect:

SELECT DISTINCT transaction_date
FROM bronze.sales
ORDER BY transaction_date;

Look for:

2024-05-23
23-05-2024
05/23/2024
2024/05/23

Also check impossible dates.

For SQL Server:

SELECT *
FROM bronze.sales
WHERE TRY_CONVERT(DATE, transaction_date) IS NULL
  AND transaction_date IS NOT NULL;

You might find:

31-02-2024
abc
N/A

These should be investigated before Silver conversion.

19. Phase 11 — Future Date Profiling

Suppose your dataset ends in 2025.

You shouldn't have a sale in 2035.

You can check:

SELECT *
FROM bronze.sales
WHERE TRY_CONVERT(DATE, transaction_date) > GETDATE();

Depending on your dataset's business timeline, you may instead compare against a known maximum allowed date.

20. Phase 12 — Referential Integrity

This is one of the most important parts of your RetailMart profiling.

You have relationships.

For example:

sales.customer_id
       ↓
customers.customer_id

Find sales records whose customer doesn't exist:

SELECT s.customer_id
FROM bronze.sales s
LEFT JOIN bronze.customers c
    ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

Suppose:

2,000 sales records

have no matching customer.

That's a major data-quality issue.

21. Do the Same for Product
SELECT s.product_id
FROM bronze.sales s
LEFT JOIN bronze.products p
    ON s.product_id = p.product_id
WHERE p.product_id IS NULL;
22. Sales → Store
SELECT s.store_id
FROM bronze.sales s
LEFT JOIN bronze.stores st
    ON s.store_id = st.store_id
WHERE st.store_id IS NULL;
23. Inventory → Product
SELECT i.product_id
FROM bronze.inventory i
LEFT JOIN bronze.products p
    ON i.product_id = p.product_id
WHERE p.product_id IS NULL;
24. Inventory → Store
SELECT i.store_id
FROM bronze.inventory i
LEFT JOIN bronze.stores s
    ON i.store_id = s.store_id
WHERE s.store_id IS NULL;
25. Employee → Store
SELECT e.store_id
FROM bronze.employee e
LEFT JOIN bronze.stores s
    ON e.store_id = s.store_id
WHERE s.store_id IS NULL;

This gives you a complete referential-integrity profiling exercise.

26. Phase 13 — Business Rule Profiling

This is where your project starts looking professional.

Sales rules

Potential rules:

transaction_id must exist
customer_id must exist
product_id must exist
store_id must exist
quantity > 0
sales_amount >= 0
transaction_date should be valid
Returns

Potential rules:

return_id must exist
transaction_id should exist
product_id should exist
return_date >= sale_date
return_quantity > 0
return_quantity <= sold_quantity
Inventory
product_id must exist
store_id must exist
quantity >= 0
Products
product_id must exist
product_name must exist
price >= 0
cost >= 0
Stores
store_id must exist
store_name must exist
state should be valid
27. Returns — A Very Important Cross-Table Check

This is an excellent interview scenario.

Suppose:

Sales

transaction_id = T100
product_id = P001
quantity = 3

Returns:

return_id = R001
transaction_id = T100
product_id = P001
return_quantity = 5

That's suspicious.

You sold:

3

but returned:

5

So you can identify:

SELECT
    r.return_id,
    r.transaction_id,
    r.product_id,
    r.return_quantity,
    s.quantity AS sold_quantity
FROM bronze.returns r
JOIN bronze.sales s
    ON r.transaction_id = s.transaction_id
   AND r.product_id = s.product_id
WHERE r.return_quantity > s.quantity;

That's real business-data profiling, not just SQL syntax practice.

-- Step 15 - Phase 14 — Orphan Returns

Check whether every return corresponds to a sale.
*/
SELECT r.*
FROM bronze.returns r
LEFT JOIN bronze.sales s
    ON r.store_id = s.store_id
WHERE s.store_id IS NULL;

-- if records appear, investigate.

-- Step 16 - phase 15 - Employee profiling
--Check duplicate employee IDs:
SELECT
    employee_id,
    COUNT(*) AS cnt
FROM bronze.employee
GROUP BY employee_id
HAVING COUNT(*) > 1;

-- Step 17 - phase 16 - Outlier profiling
/*
This is slightly more advanced.

Suppose most sales are:

₹500
₹1,200
₹3,000
₹5,000
₹7,000

and suddenly:

₹5,00,00,000

Don't automatically delete it.

First investigate.

You can use:
*/
SELECT
    MIN(sales_amount) AS min_sales,
    MAX(sales_amount) AS max_sales,
    AVG(sales_amount) AS avg_sales
FROM bronze.sales;

--You can also inspect:

SELECT TOP 20
    sales_amount
FROM bronze.sales
ORDER BY sales_amount DESC;

-- This helps identify extreme values.

-----------------------------------------------------------
-- PREPARE A DATA QUALITY REPORTS
-- make an excel sheet like
/*
| Table     | Column         | Check     | Issue Count | Issue % | Severity | Silver Action     |
| --------- | -------------- | --------- | ----------: | ------: | -------- | ----------------- |
| Customers | customer_id    | NULL      |          12 |   0.04% | Critical | Reject            |
| Customers | email          | NULL      |       2,500 |   8.33% | Medium   | Keep NULL         |
| Customers | customer_id    | Duplicate |          35 |   0.12% | High     | Deduplicate       |
| Products  | price          | Negative  |           4 |   0.01% | High     | Investigate       |
| Sales     | customer_id    | Orphan    |         120 |   0.40% | High     | Reject/Quarantine |
| Sales     | quantity       | Invalid   |          17 |   0.06% | High     | Reject            |
| Returns   | transaction_id | Orphan    |          25 |   0.08% | High     | Investigate       |

*/

-- This becomes your bridge from bronze - silver
/*
⭐ The Most Important Concept

Don't think:

Bronze has bad data → Silver means clean everything.
----------------
Think:

BRONZE
   ↓
PROFILE
   ↓
IDENTIFY
   ↓
CLASSIFY
   ↓
DEFINE BUSINESS RULE
   ↓
TRANSFORM
   ↓
VALIDATE
   ↓
SILVER
---------------
For example:

Bronze
email = '   '
       ↓
Profile
blank value
       ↓
Rule
blank email → NULL
       ↓
Silver
email = NULL
--------------------
Another:

Bronze
quantity = 'abc'
       ↓
Profile
invalid numeric value
       ↓
Rule
invalid quantity → quarantine/reject
       ↓
Silver
quantity = NULL
-----------------------------
But:

Bronze
sales_amount = -500
       ↓
Profile
negative sales
       ↓
Business investigation
       ↓
Maybe it's a RETURN
       ↓
Don't blindly delete
*/