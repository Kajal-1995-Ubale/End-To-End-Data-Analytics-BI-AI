CREATE OR ALTER VIEW gold.vw_sales_growth
AS
WITH daily_sales AS
(
    SELECT
        fs.date_key,
        d.full_date,
        d.year_num,
        d.month_num,
        d.month_name,

        SUM(fs.sales_amount) AS total_sales

    FROM gold.fact_sales fs

    INNER JOIN gold.dim_date d
        ON fs.date_key = d.date_key

    GROUP BY
        fs.date_key,
        d.full_date,
        d.year_num,
        d.month_num,
        d.month_name
),

sales_with_previous AS
(
    SELECT
        date_key,
        full_date,
        year_num,
        month_num,
        month_name,
        total_sales,

        LAG(total_sales) OVER
        (
            ORDER BY full_date
        ) AS previous_day_sales

    FROM daily_sales
)

SELECT
    date_key,
    full_date,
    year_num,
    month_num,
    month_name,
    total_sales,
    previous_day_sales,

    total_sales - previous_day_sales AS sales_growth,

    CASE
        WHEN previous_day_sales IS NULL
             OR previous_day_sales = 0
        THEN NULL

        ELSE
            ((total_sales - previous_day_sales)
            * 100.0 / previous_day_sales)
    END AS sales_growth_pct

FROM sales_with_previous;
GO

SELECT *
FROM gold.vw_sales_growth
--ORDER BY full_date;

/*
value compare
SELECT
    SUM(monthlysales) as total_sales
FROM gold.vw_sales_growth;


SELECT
    SUM(sales_amount) AS total_sales
FROM gold.fact_sales;


*


/
