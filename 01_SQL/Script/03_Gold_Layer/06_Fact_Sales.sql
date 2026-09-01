/* =====================================================================================
   RETAILMART GOLD LAYER — 06. FACT_SALES
   -----------------------------------------------------------------------------------
   Run 00_Setup through 04_Dim_Employees.sql first.
   Grain: one row per silver.sales row (one order). Source: silver.sales, joined to
   dim_customers, dim_products, dim_stores, dim_employees, dim_date.
   employee_key falls back to the Unknown member (-1) when silver.sales.employee_id
   is NULL (orphan employee, already flagged in Silver) — see 04_Dim_Employees.sql.
   ===================================================================================== */

IF OBJECT_ID('gold.fact_sales','U') IS NOT NULL DROP TABLE gold.fact_sales;
GO
/*
CREATE TABLE gold.fact_sales (
    sales_key            INT             IDENTITY(1,1) PRIMARY KEY,
    order_id                INT             NOT NULL,
    date_key                   INT             NULL,       -- FK to gold.dim_date (order_date); NULL if date unknown
    customer_key                  INT             NOT NULL,   -- FK to gold.dim_customers
    product_key                      INT             NOT NULL,   -- FK to gold.dim_products
    store_key                           INT             NOT NULL,   -- FK to gold.dim_stores
    employee_key                            INT             NOT NULL,   -- FK to gold.dim_employees (-1 = Unknown)
    quantity                                    INT             NOT NULL,
    unit_price                                     DECIMAL(12,2)   NOT NULL,
    discount_amount                                   DECIMAL(12,2)   NOT NULL,
    sales_amount                                         DECIMAL(12,2)   NOT NULL,
    cost_amount                                             DECIMAL(12,2)   NULL,
    profit_amount                                              DECIMAL(12,2)   NULL,
    profit_margin_pct                                             DECIMAL(12,2)    NULL,   -- profit_amount / sales_amount * 100
    gold_load_dt                                                     DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_fact_sales_date     FOREIGN KEY (date_key)     REFERENCES gold.dim_date(date_key),
    CONSTRAINT fk_fact_sales_customer FOREIGN KEY (customer_key) REFERENCES gold.dim_customers(customer_key),
    CONSTRAINT fk_fact_sales_product  FOREIGN KEY (product_key)  REFERENCES gold.dim_products(product_key),
    CONSTRAINT fk_fact_sales_store    FOREIGN KEY (store_key)    REFERENCES gold.dim_stores(store_key),
    CONSTRAINT fk_fact_sales_employee FOREIGN KEY (employee_key) REFERENCES gold.dim_employees(employee_key)
);
GO*/
ALTER TABLE gold.fact_sales
ALTER COLUMN profit_margin_pct DECIMAL(10,2) NULL;
GO

CREATE TABLE gold.fact_sales (
    sales_key          INT IDENTITY(1,1) PRIMARY KEY,
    order_id           INT NOT NULL,
    date_key           INT NULL,
    customer_key       INT NOT NULL,
    product_key        INT NOT NULL,
    store_key          INT NOT NULL,
    employee_key       INT NOT NULL,
    quantity           INT NOT NULL,
    unit_price         DECIMAL(12,2) NOT NULL,
    discount_amount    DECIMAL(12,2) NOT NULL,
    sales_amount       DECIMAL(12,2) NOT NULL,
    cost_amount        DECIMAL(12,2) NULL,
    profit_amount      DECIMAL(12,2) NULL,
    profit_margin_pct  DECIMAL(10,2) NULL,
    gold_load_dt       DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT fk_fact_sales_date
        FOREIGN KEY (date_key)
        REFERENCES gold.dim_date(date_key),

    CONSTRAINT fk_fact_sales_customer
        FOREIGN KEY (customer_key)
        REFERENCES gold.dim_customers(customer_key),

    CONSTRAINT fk_fact_sales_product
        FOREIGN KEY (product_key)
        REFERENCES gold.dim_products(product_key),

    CONSTRAINT fk_fact_sales_store
        FOREIGN KEY (store_key)
        REFERENCES gold.dim_stores(store_key),

    CONSTRAINT fk_fact_sales_employee
        FOREIGN KEY (employee_key)
        REFERENCES gold.dim_employees(employee_key)
);
GO
/*
INSERT INTO gold.fact_sales (order_id, date_key, customer_key, product_key, store_key,
    employee_key, quantity, unit_price, discount_amount, sales_amount, cost_amount,
    profit_amount, profit_margin_pct)
SELECT
    s.order_id,
    -- CASE WHEN s.order_date IS NULL THEN NULL ELSE CAST(CONVERT(VARCHAR(8), s.order_date, 112) AS INT) END,
    s.customer_id,
    s.product_id,
    s.store_id,
    ISNULL(s.employee_id, -1),
    s.quantity, s.unit_price, s.discount_amount, s.sales_amount, s.cost_amount,
    s.profit_amount,
    CASE WHEN s.sales_amount IS NULL OR s.sales_amount = 0 OR s.profit_amount IS NULL THEN NULL
         ELSE ROUND(s.profit_amount / s.sales_amount * 100, 2) END
FROM silver.sales s;
GO
*/

INSERT INTO gold.fact_sales
(
    order_id,
    date_key,
    customer_key,
    product_key,
    store_key,
    employee_key,
    quantity,
    unit_price,
    discount_amount,
    sales_amount,
    cost_amount,
    profit_amount,
    profit_margin_pct
)
SELECT
    s.order_id,

    CAST(CONVERT(VARCHAR(8), s.order_date, 112) AS INT) AS date_key,

    ISNULL(c.customer_key, -1) AS customer_key,
    ISNULL(p.product_key, -1) AS product_key,
    ISNULL(st.store_key, -1) AS store_key,
    ISNULL(e.employee_key, -1) AS employee_key,

    s.quantity,
    s.unit_price,
    s.discount_amount,
    s.sales_amount,
    s.cost_amount,
    s.profit_amount,

    CASE
        WHEN s.sales_amount IS NULL
          OR s.sales_amount = 0
          OR s.profit_amount IS NULL
        THEN NULL

        ELSE CAST(
            ROUND(
                (
                    CAST(s.profit_amount AS DECIMAL(38,10))
                    * 100.0
                )
                /
                NULLIF(
                    CAST(s.sales_amount AS DECIMAL(38,10)),
                    0
                ),
                2
            )
            AS DECIMAL(10,2)
        )
    END AS profit_margin_pct

FROM silver.sales s

LEFT JOIN gold.dim_customers c
    ON s.customer_id = c.customer_id

LEFT JOIN gold.dim_products p
    ON s.product_id = p.product_id

LEFT JOIN gold.dim_stores st
    ON s.store_id = st.store_id

LEFT JOIN gold.dim_employees e
    ON s.employee_id = e.employee_id;
GO

/* -------------------------------------------------------------------------------------
   Validation
   ------------------------------------------------------------------------------------- */
-- No duplicate natural keys
SELECT COUNT(*) - COUNT(DISTINCT order_id) AS dup_count FROM gold.fact_sales;

-- Referential integrity
SELECT COUNT(*) AS orphans_vs_date     FROM gold.fact_sales f WHERE f.date_key IS NOT NULL AND NOT EXISTS (SELECT 1 FROM gold.dim_date d WHERE d.date_key = f.date_key);
SELECT COUNT(*) AS orphans_vs_customer FROM gold.fact_sales f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_customers c WHERE c.customer_key = f.customer_key);
SELECT COUNT(*) AS orphans_vs_product  FROM gold.fact_sales f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_products p WHERE p.product_key = f.product_key);
SELECT COUNT(*) AS orphans_vs_store    FROM gold.fact_sales f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_stores s WHERE s.store_key = f.store_key);
SELECT COUNT(*) AS orphans_vs_employee FROM gold.fact_sales f WHERE NOT EXISTS (SELECT 1 FROM gold.dim_employees e WHERE e.employee_key = f.employee_key);

-- Row counts
SELECT
    (SELECT COUNT(*) FROM silver.sales)     AS silver_rows,
    (SELECT COUNT(*) FROM gold.fact_sales)  AS gold_rows;

