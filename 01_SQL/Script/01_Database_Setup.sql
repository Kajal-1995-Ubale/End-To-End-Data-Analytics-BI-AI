/*
=============================================================
Project: RetailMart Enterprise Sales Analytics Platform
File: 01_database_setup.sql
Purpose: Create database and analytical schemas
=============================================================
*/

-- =========================================================
-- 1. Create Database
-- =========================================================

CREATE DATABASE retailmart_analytics;
GO


-- =========================================================
-- 2. Use Database
-- =========================================================

USE retailmart_analytics;
GO


-- =========================================================
-- 3. Create Schemas
-- =========================================================
DROP SCHEMA bronze;
DROP SCHEMA gold;
DROP SCHEMA mart;
DROP SCHEMA silver;

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'bronze')
BEGIN
    EXEC('CREATE SCHEMA bronze;');
END

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'silver')
BEGIN
    EXEC('CREATE SCHEMA silver;');
END

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC('CREATE SCHEMA gold;');
END

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'mart')
BEGIN
    EXEC('CREATE SCHEMA mart;');
END

-- =========================================================
-- 4. Verify Schemas
-- =========================================================

SELECT
    name AS schema_name
FROM sys.schemas
WHERE name IN ('bronze', 'silver', 'gold', 'mart')
ORDER BY name;