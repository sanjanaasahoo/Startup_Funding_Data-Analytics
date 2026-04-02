-- =========================================
-- CLEAN + SAFE VERSION
-- =========================================

-- 1) Raw Check
SELECT *
FROM PortfolioProject..startup_funding;


-- 2) City Analysis
SELECT City_Location, COUNT(*) AS total_deals
FROM PortfolioProject..startup_funding
GROUP BY City_Location
ORDER BY total_deals DESC;


-- 3) Standardize City
UPDATE PortfolioProject..startup_funding
SET City_Location = 'Bengaluru'
WHERE City_Location IN ('Bangalore', 'Bengaluru');


-- 4) Remove invalid city
UPDATE PortfolioProject..startup_funding
SET City_Location = NULL
WHERE City_Location = 'nan';


-- 5) Clean Amount column (VERY IMPORTANT)
UPDATE PortfolioProject..startup_funding
SET Amount_in_USD = NULL
WHERE Amount_in_USD = '';


-- 6) Convert amount safely
-- (Use TRY_CAST to avoid errors)
SELECT TOP 10 TRY_CAST(Amount_in_USD AS FLOAT)
FROM PortfolioProject..startup_funding;


-- =========================================
-- CORE ANALYTICS
-- =========================================

-- Yearly Funding
SELECT 
    YEAR(TRY_CAST(Date_dd_mm_yyyy AS DATE)) AS year,
    COUNT(*) AS total_deals,
    SUM(TRY_CAST(Amount_in_USD AS FLOAT)) AS total_funding,
    AVG(TRY_CAST(Amount_in_USD AS FLOAT)) AS avg_deal_size
FROM PortfolioProject..startup_funding
WHERE TRY_CAST(Amount_in_USD AS FLOAT) IS NOT NULL
GROUP BY YEAR(TRY_CAST(Date_dd_mm_yyyy AS DATE))
ORDER BY year;


-- YoY Growth
;WITH yearly AS (
    SELECT 
        YEAR(TRY_CAST(Date_dd_mm_yyyy AS DATE)) AS year,
        SUM(TRY_CAST(Amount_in_USD AS FLOAT)) AS total_funding
    FROM PortfolioProject..startup_funding
    WHERE TRY_CAST(Amount_in_USD AS FLOAT) IS NOT NULL
    GROUP BY YEAR(TRY_CAST(Date_dd_mm_yyyy AS DATE))
)
SELECT *,
       (total_funding - LAG(total_funding) OVER (ORDER BY year)) * 100.0
       / LAG(total_funding) OVER (ORDER BY year) AS yoy_growth
FROM yearly;


-- Sector Share
SELECT Industry_Vertical,
       SUM(TRY_CAST(Amount_in_USD AS FLOAT)) AS total_funding,
       SUM(TRY_CAST(Amount_in_USD AS FLOAT)) * 100.0 /
       SUM(SUM(TRY_CAST(Amount_in_USD AS FLOAT))) OVER () AS pct_share
FROM PortfolioProject..startup_funding
WHERE TRY_CAST(Amount_in_USD AS FLOAT) IS NOT NULL
GROUP BY Industry_Vertical;


-- City Ranking
SELECT City_Location,
       COUNT(*) AS deals,
       SUM(TRY_CAST(Amount_in_USD AS FLOAT)) AS total_funding,
       RANK() OVER (ORDER BY SUM(TRY_CAST(Amount_in_USD AS FLOAT)) DESC) AS rank_city
FROM PortfolioProject..startup_funding
GROUP BY City_Location;


-- =========================================
-- FUNNEL ANALYSIS
-- =========================================
;WITH stages AS (
    SELECT Startup_Name,
        MAX(CASE WHEN InvestmentnType LIKE '%Seed%' THEN 1 ELSE 0 END) AS seed,
        MAX(CASE WHEN InvestmentnType LIKE '%Series A%' THEN 1 ELSE 0 END) AS seriesA
    FROM PortfolioProject..startup_funding
    GROUP BY Startup_Name
)
SELECT 
    SUM(seed) AS total_seed,
    SUM(seriesA) AS total_seriesA,
    SUM(seriesA)*100.0 / SUM(seed) AS conversion_rate
FROM stages;


-- =========================================
-- SCORING ENGINE
-- =========================================
SELECT Industry_Vertical,
       SUM(TRY_CAST(Amount_in_USD AS FLOAT)) AS total_funding,
       COUNT(*) AS deals,
       STDEV(TRY_CAST(Amount_in_USD AS FLOAT)) AS volatility,
       
       (SUM(TRY_CAST(Amount_in_USD AS FLOAT))*0.4 +
        COUNT(*)*0.3 -
        STDEV(TRY_CAST(Amount_in_USD AS FLOAT))*0.3) AS score
FROM PortfolioProject..startup_funding
WHERE TRY_CAST(Amount_in_USD AS FLOAT) IS NOT NULL
GROUP BY Industry_Vertical
ORDER BY score DESC;