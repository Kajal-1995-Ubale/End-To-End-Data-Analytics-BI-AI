/* =====================================================================================
   RETAILMART SILVER LAYER — 00. SETUP: SCHEMAS, REFERENCE DATA & HELPER FUNCTIONS
   -----------------------------------------------------------------------------------
   Run this FIRST, before any of the per-table scripts (01_Stores.sql ... 07_Returns.sql).
   Everything downstream (fn_ParseFlexDate, fn_TitleCase, ref.state_lookup, the silver/
   quarantine schemas) depends on this having run.

   Follows on from: RetailMart_Bronze_Data_Quality_Audit.sql (the Bronze DQ report)
   Engine: Microsoft SQL Server (T-SQL). Assumes bronze.* tables already exist and are
   loaded.
   ===================================================================================== */


/* =====================================================================================
   TREATMENT DECISION MATRIX (reference — applies across all 7 table scripts)
   -----------------------------------------------------------------------------------
   Three treatment classes are used consistently across all 7 tables. Which class an
   issue gets follows the specific Silver_Action already defined in the Bronze DQ
   report for that check — NOT a blanket "High = reject" rule. Two checks are flagged
   High severity but are NOT full-row rejects, because the DQ report's own action for
   them says to recalculate, not discard (inventory.available_quantity, sales.sales_amount) —
   every table script honors that.

     REJECT     -> row is excluded from Silver entirely and written to quarantine.<table>
                   with a reason. Used for: duplicate keys (extra copies), business-rule
                   violations that make the row untrustworthy (cost > price, reserved >
                   stock, refund > return_amount, negative quantity/stock/price),
                   orphan foreign keys on a required relationship, future-dated
                   transactional dates.

     STANDARDIZE -> value is corrected in place (trim, casing, format, lookup mapping)
                   and the row is kept. Used for: whitespace, inconsistent casing,
                   state abbreviation vs. full name, inconsistent date formats that
                   the parser CAN resolve.

     FLAG (null + note) -> value is set to NULL (or recalculated) and the row is kept
                   with a note in dq_notes so downstream (Gold-layer / reporting) can
                   choose to exclude it from a specific KPI. Used for: missing
                   non-critical fields, values the parser could NOT resolve, outliers
                   that are suspicious but not disqualifying (salary outlier, DOB
                   outlier), soft-orphan employee_id on sales.

   One deliberate deviation from the Bronze report's literal wording: "invalid email
   format" was written there as "reject to quarantine," but email is not required for
   a customer record to be usable elsewhere in the model (sales, returns don't touch
   it). Rejecting an entire customer over one malformed email would destroy an
   otherwise-valid dimension row, so 03_Customers.sql treats it as FLAG (null the
   email, keep the customer) instead. This kind of judgment call is exactly what
   "decide treatment for each issue" means in practice — documented here rather than
   buried in a WHERE clause.
   ===================================================================================== */


/* =====================================================================================
   SCHEMAS
   ===================================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')     EXEC('CREATE SCHEMA silver');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'quarantine') EXEC('CREATE SCHEMA quarantine');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ref')        EXEC('CREATE SCHEMA ref');
GO

-- State abbreviation -> full name lookup, used to standardize the `state` column
-- wherever bronze data mixes "CA" and "California".
IF OBJECT_ID('ref.state_lookup', 'U') IS NOT NULL DROP TABLE ref.state_lookup;
CREATE TABLE ref.state_lookup (
    state_abbr VARCHAR(2)  NOT NULL PRIMARY KEY,
    state_name VARCHAR(30) NOT NULL
);
INSERT INTO ref.state_lookup (state_abbr, state_name) VALUES
('AL','Alabama'),('AK','Alaska'),('AZ','Arizona'),('AR','Arkansas'),('CA','California'),
('CO','Colorado'),('CT','Connecticut'),('DE','Delaware'),('FL','Florida'),('GA','Georgia'),
('HI','Hawaii'),('ID','Idaho'),('IL','Illinois'),('IN','Indiana'),('IA','Iowa'),
('KS','Kansas'),('KY','Kentucky'),('LA','Louisiana'),('ME','Maine'),('MD','Maryland'),
('MA','Massachusetts'),('MI','Michigan'),('MN','Minnesota'),('MS','Mississippi'),('MO','Missouri'),
('MT','Montana'),('NE','Nebraska'),('NV','Nevada'),('NH','New Hampshire'),('NJ','New Jersey'),
('NM','New Mexico'),('NY','New York'),('NC','North Carolina'),('ND','North Dakota'),('OH','Ohio'),
('OK','Oklahoma'),('OR','Oregon'),('PA','Pennsylvania'),('RI','Rhode Island'),('SC','South Carolina'),
('SD','South Dakota'),('TN','Tennessee'),('TX','Texas'),('UT','Utah'),('VT','Vermont'),
('VA','Virginia'),('WA','Washington'),('WV','West Virginia'),('WI','Wisconsin'),('WY','Wyoming'),
('DC','District of Columbia');
GO


/* =====================================================================================
   HELPER FUNCTIONS
   ===================================================================================== */

-- Multi-format date parser: tries the formats actually seen in the Bronze audit
-- (ISO, dd-mm-yyyy, mm/dd/yyyy, dd/mm/yyyy, mm-dd-yyyy) in that order and returns
-- the first successful parse, or NULL if none match.
-- CAVEAT: pure numeric day/month values <=12 are inherently ambiguous between
-- dd-mm and mm-dd formats. This function resolves the ambiguity by trying ISO first,
-- then the format known to be used by each source table (documented at each call
-- site in the relevant table script). For a real production pipeline, confirm the
-- exact format contract with each source system rather than guessing — this fallback
-- chain is a practical compromise for a portfolio/training exercise, not a substitute
-- for that.
IF OBJECT_ID('dbo.fn_ParseFlexDate', 'FN') IS NOT NULL DROP FUNCTION dbo.fn_ParseFlexDate;
GO
CREATE FUNCTION dbo.fn_ParseFlexDate (@raw VARCHAR(20))
RETURNS DATE
AS
BEGIN
    DECLARE @result DATE;
    SET @result = TRY_CONVERT(DATE, @raw, 23);   -- yyyy-mm-dd
    IF @result IS NULL SET @result = TRY_CONVERT(DATE, @raw, 105);  -- dd-mm-yyyy
    IF @result IS NULL SET @result = TRY_CONVERT(DATE, @raw, 101);  -- mm/dd/yyyy
    IF @result IS NULL SET @result = TRY_CONVERT(DATE, @raw, 103);  -- dd/mm/yyyy
    IF @result IS NULL SET @result = TRY_CONVERT(DATE, @raw, 110);  -- mm-dd-yyyy
    IF @result IS NULL SET @result = TRY_CONVERT(DATE, @raw, 111);  -- yyyy/mm/dd
    RETURN @result;
END;
GO

-- Simple Title Case helper (T-SQL has no built-in INITCAP). Used for name/text fields.
IF OBJECT_ID('dbo.fn_TitleCase', 'FN') IS NOT NULL DROP FUNCTION dbo.fn_TitleCase;
GO
CREATE FUNCTION dbo.fn_TitleCase (@input VARCHAR(300))
RETURNS VARCHAR(300)
AS
BEGIN
    IF @input IS NULL RETURN NULL;
    DECLARE @output VARCHAR(300) = '';
    DECLARE @i INT = 1;
    DECLARE @c CHAR(1);
    DECLARE @prevWasSpace BIT = 1;
    SET @input = LOWER(LTRIM(RTRIM(@input)));
    WHILE @i <= LEN(@input)
    BEGIN
        SET @c = SUBSTRING(@input, @i, 1);
        IF @prevWasSpace = 1
            SET @output = @output + UPPER(@c);
        ELSE
            SET @output = @output + @c;
        SET @prevWasSpace = CASE WHEN @c = ' ' THEN 1 ELSE 0 END;
        SET @i = @i + 1;
    END
    RETURN @output;
END;
GO

-- Next: run 01_Stores.sql, then 02_Products.sql, 03_Customers.sql, 04_Employees.sql,
-- 05_Inventory.sql, 06_Sales.sql, 07_Returns.sql, in that order (dimensions before
-- facts; employees needs stores; inventory/sales/returns need their parent dimensions
-- already in Silver for the FK to hold). Finish with 08_Validation_And_Comparison.sql.
