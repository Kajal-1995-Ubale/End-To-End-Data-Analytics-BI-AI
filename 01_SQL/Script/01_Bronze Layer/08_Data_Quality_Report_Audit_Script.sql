/* =====================================================================================
   RETAILMART BRONZE LAYER — DATA QUALITY AUDIT SCRIPT
   =====================================================================================
   Purpose : Profile the raw Bronze-layer tables and produce a single result set in the
             same shape as the Data Quality Report workbook:
                 Table | Column | Check | Issue_Count | Total_Rows | Issue_Pct | Severity | Silver_Action
   Engine  : Microsoft SQL Server (T-SQL). Uses TRY_CAST / TRY_CONVERT, so no functions
             beyond SQL Server 2012+ are required.
   Author  : Kajal — RetailMart Enterprise Analytics Platform, Phase 3 (Data Cleaning)
   =====================================================================================
*/

/* =====================================================================================
   DATA QUALITY AUDIT (all checks, one result set)
   Each block returns exactly one row: Table, Column, Check, Issue_Count, Total_Rows,
   Issue_Pct, Severity, Silver_Action — mirroring the Excel Data Quality Report tab.
   ===================================================================================== */

   WITH
        tot_customers  AS (SELECT COUNT(*) AS n FROM bronze.customers),
        tot_employees  AS (SELECT COUNT(*) AS n FROM bronze.employee),
        tot_stores     AS (SELECT COUNT(*) AS n FROM bronze.stores),
        tot_products   AS (SELECT COUNT(*) AS n FROM bronze.products),
        tot_inventory  AS (SELECT COUNT(*) AS n FROM bronze.inventory),
        tot_sales      AS (SELECT COUNT(*) AS n FROM bronze.sales),
        tot_returns    AS (SELECT COUNT(*) AS n FROM bronze.returns)
        /* ============================== CUSTOMERS ============================== */
        SELECT 'Customers' AS [TABLE],'Customer_ID' AS [COLUMN], 'Duplicate Primary key' As [CHECK],
        (SELECT COUNT(*) FROM bronze.customers) - (SELECT COUNT(DISTINCT customer_ID) FROM bronze.customers) As Issue_Count,
        (SELECT n FROM tot_customers) As Total_Rows,
        CAST(((SELECT COUNT(*) FROM bronze.customers) - (SELECT COUNT(DISTINCT customer_ID) FROM bronze.customers)) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers) As ISSUE_PCT,
        'High' AS Severity,
        'Deduplicate on customer_id, keep most recent registration_date, log removed rows to quarantine' AS Silver_Action
        UNION ALL
        SELECT 'customers', 'email', 'Missing value',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'Medium', 'Flag NULL; do not block load, route to Customer Data Steward for backfill'
        FROM bronze.customers WHERE email IS NULL OR LTRIM(RTRIM(email)) = ''

        UNION ALL
        SELECT 'customers', 'email', 'Invalid format (missing @ / domain)',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'Medium', 'Reject malformed emails to quarantine table; do not attempt auto-correction'
        FROM bronze.customers
        WHERE email IS NOT NULL AND LTRIM(RTRIM(email)) <> ''
          AND (email NOT LIKE '%_@__%.__%' OR email LIKE '% %')

        UNION ALL
        SELECT 'customers', 'phone_number', 'Missing value',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'Low', 'Flag NULL, allow load (non-critical for core sales KPIs)'
        FROM bronze.customers WHERE phone_number IS NULL OR LTRIM(RTRIM(phone_number)) = ''

        UNION ALL
        SELECT 'customers', 'phone_number', 'Invalid length / inconsistent format',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'Medium', 'Strip non-numeric characters, standardize to 10-digit numeric string; quarantine if still invalid'
        FROM bronze.customers
        WHERE phone_number IS NOT NULL AND LTRIM(RTRIM(phone_number)) <> ''
          AND (
                LEN(TRANSLATE(phone_number, '0123456789', '          ')) <> 0     -- contains non-digit characters
                OR LEN(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(phone_number,'-',''),' ',''),'(',''),')',''),'+',''),'.','')) <> 10  -- not 10 digits once formatting is stripped
              )

        UNION ALL
        SELECT 'customers', 'gender', 'Inconsistent categorical values',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'Low', 'Standardize via mapping table (trim, upper-case compare) to Male / Female / Other'
        FROM bronze.customers WHERE gender NOT IN ('Male', 'Female', 'Other')

        UNION ALL
        SELECT 'customers', 'date_of_birth', 'Inconsistent date format',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'Medium', 'Standardize all date formats to YYYY-MM-DD using multi-format parser; quarantine unparseable values'
        FROM bronze.customers
        WHERE date_of_birth IS NOT NULL AND TRY_CONVERT(DATE, date_of_birth, 23) IS NULL

        UNION ALL
        SELECT 'customers', 'date_of_birth', 'Outlier — implausible age (<10 or >100)',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'High', 'Flag for manual review; exclude from active-customer KPIs until corrected'
        FROM bronze.customers
        WHERE TRY_CAST(date_of_birth AS DATE) IS NOT NULL
          AND (DATEDIFF(YEAR, TRY_CAST(date_of_birth AS DATE), '2026-08-29') > 100
               OR DATEDIFF(YEAR, TRY_CAST(date_of_birth AS DATE), '2026-08-29') < 10)

        UNION ALL
        SELECT 'customers', 'registration_date', 'Inconsistent date format',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'Medium', 'Standardize to YYYY-MM-DD using multi-format parser'
        FROM bronze.customers
        WHERE registration_date IS NOT NULL AND TRY_CONVERT(DATE, registration_date, 23) IS NULL

        UNION ALL
        SELECT 'customers', 'registration_date', 'Future-dated value',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'High', 'Reject rows with registration_date > current load date; route to exception queue'
        FROM bronze.customers
        WHERE TRY_CAST(registration_date AS DATE) > '2026-08-29'

        UNION ALL
        SELECT 'customers', 'customer_status', 'Inconsistent casing / whitespace',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'Low', 'Trim whitespace, standardize casing (Title Case) via mapping table'
        FROM bronze.customers WHERE customer_status NOT IN ('Active', 'Inactive')

        UNION ALL
        SELECT 'customers', 'customer_name', 'Leading/trailing whitespace',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'Low', 'Trim whitespace; standardize to Title Case'
        FROM bronze.customers WHERE customer_name <> LTRIM(RTRIM(customer_name))

        UNION ALL
        SELECT 'customers', 'state', 'Inconsistent format — abbreviation vs full name',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'Low', 'Standardize all state values to full state name via lookup table'
        FROM bronze.customers WHERE state IS NOT NULL AND LEN(state) <= 2

        UNION ALL
        SELECT 'customers', 'state', 'Missing value',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'Low', 'Flag NULL; infer from city where possible, else route to steward'
        FROM bronze.customers WHERE state IS NULL OR LTRIM(RTRIM(state)) = ''

        UNION ALL
        SELECT 'customers', 'city', 'Missing value',
               COUNT(*), (SELECT n FROM tot_customers),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_customers),
               'Low', 'Flag NULL, allow load'
        FROM bronze.customers WHERE city IS NULL OR LTRIM(RTRIM(city)) = ''

        /* ============================== EMPLOYEES ============================== */
        UNION ALL
        SELECT 'employees', 'employee_id', 'Duplicate primary key',
               (SELECT COUNT(*) FROM bronze.employee) - (SELECT COUNT(DISTINCT employee_id) FROM bronze.employee),
               (SELECT n FROM tot_employees),
               CAST(((SELECT COUNT(*) FROM bronze.employee) - (SELECT COUNT(DISTINCT employee_id) FROM bronze.employee)) AS DECIMAL(10,4)) / (SELECT n FROM tot_employees),
               'High', 'Deduplicate on employee_id, keep latest joining_date, log removed rows'

        UNION ALL
        SELECT 'employees', 'salary', 'Missing value',
               COUNT(*), (SELECT n FROM tot_employees),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_employees),
               'Medium', 'Flag NULL; exclude from payroll aggregation until backfilled'
        FROM bronze.employee WHERE salary IS NULL OR LTRIM(RTRIM(salary)) = ''

        UNION ALL
        SELECT 'employees', 'salary', 'Negative value',
               COUNT(*), (SELECT n FROM tot_employees),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_employees),
               'High', 'Reject negative salary to quarantine; requires HR correction before load'
        FROM bronze.employee WHERE TRY_CAST(salary AS DECIMAL(12,2)) < 0

        UNION ALL
        SELECT 'employees', 'salary', 'Extreme outlier (>4 std dev above mean)',
               COUNT(*), (SELECT n FROM tot_employees),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_employees),
               'Medium', 'Flag for HR/Finance review; exclude from average-salary KPIs pending confirmation'
        FROM bronze.employee
        WHERE TRY_CAST(salary AS DECIMAL(12,2)) > (
            SELECT AVG(TRY_CAST(salary AS DECIMAL(12,2))) + 4 * STDEV(TRY_CAST(salary AS DECIMAL(12,2)))
            FROM bronze.employee WHERE TRY_CAST(salary AS DECIMAL(12,2)) > 0)

        UNION ALL
        SELECT 'employees', 'joining_date', 'Missing value',
               COUNT(*), (SELECT n FROM tot_employees),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_employees),
               'Low', 'Flag NULL, allow load'
        FROM bronze.employee WHERE joining_date IS NULL OR LTRIM(RTRIM(joining_date)) = ''

        UNION ALL
        SELECT 'employees', 'joining_date', 'Inconsistent date format',
               COUNT(*), (SELECT n FROM tot_employees),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_employees),
               'Medium', 'Standardize to YYYY-MM-DD using multi-format parser'
        FROM bronze.employee WHERE joining_date IS NOT NULL AND TRY_CONVERT(DATE, joining_date, 23) IS NULL

        UNION ALL
        SELECT 'employees', 'department', 'Missing value',
               COUNT(*), (SELECT n FROM tot_employees),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_employees),
               'Low', 'Flag NULL; default to ''Unassigned'' pending HR update'
        FROM bronze.employee WHERE department IS NULL OR LTRIM(RTRIM(department)) = ''

        UNION ALL
        SELECT 'employees', 'employment_status', 'Inconsistent casing / formatting',
               COUNT(*), (SELECT n FROM tot_employees),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_employees),
               'Low', 'Trim, standardize casing via mapping table'
        FROM bronze.employee WHERE employment_status NOT IN ('Active', 'Inactive', 'Terminated', 'On Leave')

        UNION ALL
        SELECT 'employees', 'store_id', 'Orphan foreign key (store not found)',
               COUNT(*), (SELECT n FROM tot_employees),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_employees),
               'High', 'Reject to quarantine; investigate against Stores master before load'
        FROM bronze.employee e
        WHERE e.store_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM bronze.stores s WHERE s.store_id = e.store_id)

        UNION ALL
        SELECT 'employees', 'employee_name', 'Leading/trailing whitespace',
               COUNT(*), (SELECT n FROM tot_employees),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_employees),
               'Low', 'Trim whitespace, standardize to Title Case'
        FROM bronze.employee WHERE employee_name <> LTRIM(RTRIM(employee_name))

        /* ============================== STORES ============================== */
        UNION ALL
        SELECT 'stores', 'store_id', 'Duplicate primary key',
               (SELECT COUNT(*) FROM bronze.stores) - (SELECT COUNT(DISTINCT store_id) FROM bronze.stores),
               (SELECT n FROM tot_stores),
               CAST(((SELECT COUNT(*) FROM bronze.stores) - (SELECT COUNT(DISTINCT store_id) FROM bronze.stores)) AS DECIMAL(10,4)) / (SELECT n FROM tot_stores),
               'High', 'Deduplicate on store_id, keep most recent record, log removed rows'

        UNION ALL
        SELECT 'stores', 'manager_id', 'Missing value',
               COUNT(*), (SELECT n FROM tot_stores),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_stores),
               'Low', 'Flag NULL; allow load, does not block store-level KPIs'
        FROM bronze.stores WHERE manager_id IS NULL OR LTRIM(RTRIM(manager_id)) = ''

        UNION ALL
        SELECT 'stores', 'state', 'Inconsistent format — abbreviation vs full name',
               COUNT(*), (SELECT n FROM tot_stores),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_stores),
               'Low', 'Standardize all state values to full state name via lookup table'
        FROM bronze.stores WHERE state IS NOT NULL AND LEN(state) <= 2

        UNION ALL
        SELECT 'stores', 'square_feet', 'Negative / implausible value',
               COUNT(*), (SELECT n FROM tot_stores),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_stores),
               'Medium', 'Reject non-positive values to quarantine; requires Facilities correction'
        FROM bronze.stores WHERE TRY_CAST(square_feet AS INT) <= 0

        UNION ALL
        SELECT 'stores', 'store_status', 'Inconsistent casing',
               COUNT(*), (SELECT n FROM tot_stores),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_stores),
               'Low', 'Trim, standardize casing via mapping table'
        FROM bronze.stores WHERE store_status NOT IN ('Active', 'Closed', 'Renovating')

        UNION ALL
        SELECT 'stores', 'opening_date', 'Inconsistent date format',
               COUNT(*), (SELECT n FROM tot_stores),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_stores),
               'Medium', 'Standardize to YYYY-MM-DD using multi-format parser'
        FROM bronze.stores WHERE opening_date IS NOT NULL AND TRY_CONVERT(DATE, opening_date, 23) IS NULL

        /* ============================== PRODUCTS ============================== */
        UNION ALL
        SELECT 'products', 'product_id', 'Duplicate primary key',
               (SELECT COUNT(*) FROM bronze.products) - (SELECT COUNT(DISTINCT product_id) FROM bronze.products),
               (SELECT n FROM tot_products),
               CAST(((SELECT COUNT(*) FROM bronze.products) - (SELECT COUNT(DISTINCT product_id) FROM bronze.products)) AS DECIMAL(10,4)) / (SELECT n FROM tot_products),
               'High', 'Deduplicate on product_id, keep most recently launched record, log removed rows'

        UNION ALL
        SELECT 'products', 'brand', 'Missing value',
               COUNT(*), (SELECT n FROM tot_products),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_products),
               'Low', 'Flag NULL; default to ''Unbranded'' pending Merchandising update'
        FROM bronze.products WHERE brand IS NULL OR LTRIM(RTRIM(brand)) = ''

        UNION ALL
        SELECT 'products', 'category', 'Missing value',
               COUNT(*), (SELECT n FROM tot_products),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_products),
               'Medium', 'Flag NULL; exclude from category-level KPIs until corrected'
        FROM bronze.products WHERE category IS NULL OR LTRIM(RTRIM(category)) = ''

        UNION ALL
        SELECT 'products', 'launch_date', 'Missing value',
               COUNT(*), (SELECT n FROM tot_products),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_products),
               'Low', 'Flag NULL; expected for Inactive products, allow load'
        FROM bronze.products WHERE launch_date IS NULL OR LTRIM(RTRIM(launch_date)) = ''

        UNION ALL
        SELECT 'products', 'unit_cost / selling_price', 'Business rule violation — cost > selling price',
               COUNT(*), (SELECT n FROM tot_products),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_products),
               'High', 'Reject to quarantine; requires Pricing team correction before load'
        FROM bronze.products
        WHERE TRY_CAST(unit_cost AS DECIMAL(12,2)) > TRY_CAST(selling_price AS DECIMAL(12,2))

        UNION ALL
        SELECT 'products', 'selling_price', 'Negative value',
               COUNT(*), (SELECT n FROM tot_products),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_products),
               'High', 'Reject negative price to quarantine'
        FROM bronze.products WHERE TRY_CAST(selling_price AS DECIMAL(12,2)) < 0

        UNION ALL
        SELECT 'products', 'product_status', 'Inconsistent casing / whitespace',
               COUNT(*), (SELECT n FROM tot_products),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_products),
               'Low', 'Trim whitespace, standardize casing via mapping table'
        FROM bronze.products
        WHERE (product_status <> LTRIM(RTRIM(product_status))) OR (product_status NOT IN ('Active', 'Inactive'))

        UNION ALL
        SELECT 'products', 'product_name', 'Leading/trailing whitespace',
               COUNT(*), (SELECT n FROM tot_products),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_products),
               'Low', 'Trim whitespace'
        FROM bronze.products WHERE product_name <> LTRIM(RTRIM(product_name))

        /* ============================== INVENTORY ============================== */
        UNION ALL
        SELECT 'inventory', 'inventory_id', 'Duplicate primary key',
               (SELECT COUNT(*) FROM bronze.inventory) - (SELECT COUNT(DISTINCT inventory_id) FROM bronze.inventory),
               (SELECT n FROM tot_inventory),
               CAST(((SELECT COUNT(*) FROM bronze.inventory) - (SELECT COUNT(DISTINCT inventory_id) FROM bronze.inventory)) AS DECIMAL(10,4)) / (SELECT n FROM tot_inventory),
               'High', 'Deduplicate on inventory_id, keep latest snapshot_date, log removed rows'

        UNION ALL
        SELECT 'inventory', 'stock_quantity', 'Negative value',
               COUNT(*), (SELECT n FROM tot_inventory),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_inventory),
               'High', 'Reject negative stock to quarantine; investigate against warehouse system'
        FROM bronze.inventory WHERE TRY_CAST(stock_quantity AS INT) < 0

        UNION ALL
        SELECT 'inventory', 'reserved_quantity', 'Business rule violation — reserved > stock on hand',
               COUNT(*), (SELECT n FROM tot_inventory),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_inventory),
               'High', 'Reject to quarantine; reconcile against order-management system before load'
        FROM bronze.inventory WHERE TRY_CAST(reserved_quantity AS INT) > TRY_CAST(stock_quantity AS INT)

        UNION ALL
        SELECT 'inventory', 'available_quantity', 'Consistency violation — available != stock - reserved',
               COUNT(*), (SELECT n FROM tot_inventory),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_inventory),
               'High', 'Recalculate available_quantity as stock - reserved during Silver transformation'
        FROM bronze.inventory
        WHERE TRY_CAST(available_quantity AS INT) <> (TRY_CAST(stock_quantity AS INT) - TRY_CAST(reserved_quantity AS INT))

        UNION ALL
        SELECT 'inventory', 'product_id', 'Orphan foreign key (product not found)',
               COUNT(*), (SELECT n FROM tot_inventory),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_inventory),
               'High', 'Reject to quarantine; investigate against Products master before load'
        FROM bronze.inventory i
        WHERE i.product_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM bronze.products p WHERE p.product_id = i.product_id)

        UNION ALL
        SELECT 'inventory', 'store_id', 'Orphan foreign key (store not found)',
               COUNT(*), (SELECT n FROM tot_inventory),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_inventory),
               'High', 'Reject to quarantine; investigate against Stores master before load'
        FROM bronze.inventory i
        WHERE i.store_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM bronze.stores s WHERE s.store_id = i.store_id)

        UNION ALL
        SELECT 'inventory', 'inventory_status', 'Inconsistent / invalid categorical value',
               COUNT(*), (SELECT n FROM tot_inventory),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_inventory),
               'Low', 'Standardize via mapping table; flag ''N/A''/''unknown'' for review'
        FROM bronze.inventory WHERE inventory_status NOT IN ('In Stock', 'Low Stock', 'Overstock', 'Out of Stock')

        UNION ALL
        SELECT 'inventory', 'snapshot_date', 'Future-dated value',
               COUNT(*), (SELECT n FROM tot_inventory),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_inventory),
               'Medium', 'Reject rows with snapshot_date beyond current load date'
        FROM bronze.inventory WHERE TRY_CAST(snapshot_date AS DATE) > '2026-08-29'

        UNION ALL
        SELECT 'inventory', 'reorder_level', 'Missing value',
               COUNT(*), (SELECT n FROM tot_inventory),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_inventory),
               'Low', 'Flag NULL; default to category-average reorder level pending correction'
        FROM bronze.inventory WHERE reorder_level IS NULL OR LTRIM(RTRIM(reorder_level)) = ''

        /* ============================== SALES ============================== */
        UNION ALL
        SELECT 'sales', 'order_id (full row)', 'Duplicate transaction row',
               COUNT(*), (SELECT n FROM tot_sales),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_sales),
               'High', 'Deduplicate on full row match, keep single instance, log removed rows'
        FROM (
            SELECT ROW_NUMBER() OVER (
                PARTITION BY order_id, customer_id, product_id, store_id, employee_id, order_date,
                              quantity, unit_price, discount_amount, sales_amount, cost_amount, profit_amount
                ORDER BY (SELECT NULL)) AS rn
            FROM bronze.sales
        ) d WHERE rn > 1

        UNION ALL
        SELECT 'sales', 'unit_price', 'Missing value',
               COUNT(*), (SELECT n FROM tot_sales),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_sales),
               'Medium', 'Reject to quarantine; cannot derive sales_amount without unit_price'
        FROM bronze.sales WHERE unit_price IS NULL OR LTRIM(RTRIM(unit_price)) = ''

        UNION ALL
        SELECT 'sales', 'employee_id', 'Missing value',
               COUNT(*), (SELECT n FROM tot_sales),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_sales),
               'Low', 'Flag NULL; allow load, attribute to ''Unknown Employee'' for staffing KPIs'
        FROM bronze.sales WHERE employee_id IS NULL OR LTRIM(RTRIM(employee_id)) = ''

        UNION ALL
        SELECT 'sales', 'employee_id', 'Orphan foreign key (employee not found)',
               COUNT(*), (SELECT n FROM tot_sales),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_sales),
               'Medium', 'Flag for review; allow load but exclude from employee-performance KPIs'
        FROM bronze.sales s
        WHERE s.employee_id IS NOT NULL AND LTRIM(RTRIM(s.employee_id)) <> ''
          AND NOT EXISTS (SELECT 1 FROM bronze.employee e WHERE e.employee_id = s.employee_id)

        UNION ALL
        SELECT 'sales', 'quantity', 'Negative value',
               COUNT(*), (SELECT n FROM tot_sales),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_sales),
               'High', 'Reject negative quantity to quarantine; likely a return miscoded as a sale'
        FROM bronze.sales WHERE TRY_CAST(quantity AS INT) < 0

        UNION ALL
        SELECT 'sales', 'discount_amount', 'Business rule violation — discount > sales_amount',
               COUNT(*), (SELECT n FROM tot_sales),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_sales),
               'High', 'Reject to quarantine; requires source-system correction'
        FROM bronze.sales WHERE TRY_CAST(discount_amount AS DECIMAL(12,2)) > TRY_CAST(sales_amount AS DECIMAL(12,2))

        UNION ALL
        SELECT 'sales', 'sales_amount', 'Consistency violation — does not equal quantity x unit_price - discount',
               COUNT(*), (SELECT n FROM tot_sales),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_sales),
               'High', 'Recalculate sales_amount during Silver transformation; do not trust source-calculated value'
        FROM bronze.sales
        WHERE ABS(
            (TRY_CAST(quantity AS DECIMAL(12,2)) * TRY_CAST(unit_price AS DECIMAL(12,2)) - TRY_CAST(discount_amount AS DECIMAL(12,2)))
            - TRY_CAST(sales_amount AS DECIMAL(12,2))
          ) > 0.5

        UNION ALL
        SELECT 'sales', 'customer_id', 'Orphan foreign key (customer not found)',
               COUNT(*), (SELECT n FROM tot_sales),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_sales),
               'High', 'Reject to quarantine; investigate against Customers master before load'
        FROM bronze.sales s
        WHERE s.customer_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM bronze.customers c WHERE c.customer_id = s.customer_id)

        UNION ALL
        SELECT 'sales', 'product_id', 'Orphan foreign key (product not found)',
               COUNT(*), (SELECT n FROM tot_sales),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_sales),
               'High', 'Reject to quarantine; investigate against Products master before load'
        FROM bronze.sales s
        WHERE s.product_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM bronze.products p WHERE p.product_id = s.product_id)

        UNION ALL
        SELECT 'sales', 'store_id', 'Orphan foreign key (store not found)',
               COUNT(*), (SELECT n FROM tot_sales),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_sales),
               'High', 'Reject to quarantine; investigate against Stores master before load'
        FROM bronze.sales s
        WHERE s.store_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM bronze.stores st WHERE st.store_id = s.store_id)

        UNION ALL
        SELECT 'sales', 'order_date', 'Inconsistent date format',
               COUNT(*), (SELECT n FROM tot_sales),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_sales),
               'Medium', 'Standardize to YYYY-MM-DD using multi-format parser'
        FROM bronze.sales WHERE order_date IS NOT NULL AND TRY_CONVERT(DATE, order_date, 23) IS NULL

        UNION ALL
        SELECT 'sales', 'order_date', 'Future-dated value',
               COUNT(*), (SELECT n FROM tot_sales),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_sales),
               'High', 'Reject rows with order_date beyond current load date'
        FROM bronze.sales WHERE TRY_CAST(order_date AS DATE) > '2026-08-29'

        /* ============================== RETURNS ============================== */
        UNION ALL
        SELECT 'returns', 'return_id', 'Duplicate primary key',
               (SELECT COUNT(*) FROM bronze.returns) - (SELECT COUNT(DISTINCT return_id) FROM bronze.returns),
               (SELECT n FROM tot_returns),
               CAST(((SELECT COUNT(*) FROM bronze.returns) - (SELECT COUNT(DISTINCT return_id) FROM bronze.returns)) AS DECIMAL(10,4)) / (SELECT n FROM tot_returns),
               'High', 'Deduplicate on return_id, keep single instance, log removed rows'

        UNION ALL
        SELECT 'returns', 'refund_amount', 'Missing value',
               COUNT(*), (SELECT n FROM tot_returns),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_returns),
               'Medium', 'Flag NULL; exclude from refund KPIs until Finance confirms'
        FROM bronze.returns WHERE refund_amount IS NULL OR LTRIM(RTRIM(refund_amount)) = ''

        UNION ALL
        SELECT 'returns', 'refund_amount', 'Business rule violation — refund > return_amount',
               COUNT(*), (SELECT n FROM tot_returns),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_returns),
               'High', 'Reject to quarantine; requires Finance correction before load'
        FROM bronze.returns WHERE TRY_CAST(refund_amount AS DECIMAL(12,2)) > TRY_CAST(return_amount AS DECIMAL(12,2))

        UNION ALL
        SELECT 'returns', 'return_quantity', 'Negative value',
               COUNT(*), (SELECT n FROM tot_returns),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_returns),
               'High', 'Reject negative return_quantity to quarantine'
        FROM bronze.returns WHERE TRY_CAST(return_quantity AS INT) < 0

        UNION ALL
        SELECT 'returns', 'order_id', 'Orphan foreign key (order not found in Sales)',
               COUNT(*), (SELECT n FROM tot_returns),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_returns),
               'High', 'Reject to quarantine; investigate against Sales fact before load'
        FROM bronze.returns r
        WHERE r.order_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM bronze.sales s WHERE s.order_id = r.order_id)

        UNION ALL
        SELECT 'returns', 'customer_id', 'Orphan foreign key (customer not found)',
               COUNT(*), (SELECT n FROM tot_returns),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_returns),
               'High', 'Reject to quarantine; investigate against Customers master before load'
        FROM bronze.returns r
        WHERE r.customer_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM bronze.customers c WHERE c.customer_id = r.customer_id)

        UNION ALL
        SELECT 'returns', 'product_id', 'Orphan foreign key (product not found)',
               COUNT(*), (SELECT n FROM tot_returns),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_returns),
               'High', 'Reject to quarantine; investigate against Products master before load'
        FROM bronze.returns r
        WHERE r.product_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM bronze.products p WHERE p.product_id = r.product_id)

        UNION ALL
        SELECT 'returns', 'return_reason', 'Inconsistent casing / whitespace',
               COUNT(*), (SELECT n FROM tot_returns),
               CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_returns),
               'Low', 'Trim whitespace, standardize casing via mapping table'
        FROM bronze.returns WHERE return_reason <> LTRIM(RTRIM(return_reason))

        UNION ALL
SELECT 'returns', 'return_status', 'Inconsistent casing',
       COUNT(*), (SELECT n FROM tot_returns),
       CAST(COUNT(*) AS DECIMAL(10,4)) / (SELECT n FROM tot_returns),
       'Low', 'Trim, standardize casing via mapping table'
FROM bronze.returns WHERE return_status NOT IN ('Approved', 'Rejected', 'Pending')
    ORDER BY [Table], [Column], [Check];
    GO