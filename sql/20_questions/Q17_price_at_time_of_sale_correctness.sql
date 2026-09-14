/* Q17 - Price at time of sale correctness dataset

Definitions
- Scope = all order lines (not restricted to DELIVERED orders)
- Reporting grain of detail output = 1 row per SalesOrderLineID
- Sales date used for price matching = CAST(sales.SalesOrder.OrderDate AS DATE)
- Price match rule:
    ref.ProductListPriceHistory.ProductID = sales.SalesOrderLine.ProductID
    AND OrderDate >= EffectiveFrom
    AND (OrderDate <= EffectiveTo OR EffectiveTo IS NULL)
- EffectiveTo is treated as inclusive
- If multiple historical price rows match, the row with the latest EffectiveFrom is selected
  using OUTER APPLY + TOP 1 ORDER BY EffectiveFrom DESC
- UnitPriceUsed = sales.SalesOrderLine.UnitPrice
- ListPriceAtTimeOfSale = ref.ProductListPriceHistory.ListPrice valid on the order date
- Difference = UnitPriceUsed - ListPriceAtTimeOfSale
- HasPriceMatch = 1 when a valid historical price row is found, else 0
- IsDiscrepant = 1 when HasPriceMatch = 1 and ABS(Difference) > 0.01, else 0

Detail output columns
- SalesOrderLineID
- OrderNumber
- OrderDate
- SKU
- UnitPriceUsed
- ListPriceAtTimeOfSale
- Difference
- HasPriceMatch
- IsDiscrepant

Summary output columns
- TotalOrderLines
- MatchedPriceLines
- UnmatchedPriceLines
- DiscrepantLines
- PctDiscrepantAmongAllLines
- PctDiscrepantAmongMatchedLines
*/

DROP TABLE IF EXISTS #TimeOfLineSales;

WITH ProductOrderLineDetails AS
(
    SELECT
        sol.SalesOrderLineID,
        sol.ProductID,
        so.OrderNumber,
        CAST(so.OrderDate AS DATE) AS OrderDate,
        p.SKU,
        sol.UnitPrice
    FROM sales.SalesOrderLine sol
    JOIN sales.SalesOrder so
        ON so.SalesOrderID = sol.SalesOrderID
    JOIN ref.Product p
        ON p.ProductID = sol.ProductID
),
TimeOfLineSales AS
(
    SELECT
        pold.SalesOrderLineID,
        pold.OrderNumber,
        pold.OrderDate,
        pold.SKU,
        pold.UnitPrice AS UnitPriceUsed,
        plph.ListPrice AS ListPriceAtTimeOfSale,
        pold.UnitPrice - plph.ListPrice AS [Difference],
        CASE WHEN plph.ListPrice IS NOT NULL THEN 1 ELSE 0 END AS HasPriceMatch,
        CASE 
            WHEN plph.ListPrice IS NOT NULL
            AND ABS(pold.UnitPrice - plph.ListPrice) > 0.01
                THEN 1
            ELSE 0
        END AS IsDiscrepant
    FROM ProductOrderLineDetails pold
    OUTER APPLY
    (
        SELECT TOP 1
            ph.ListPrice
        FROM ref.ProductListPriceHistory ph
        WHERE ph.ProductID = pold.ProductID
            AND pold.OrderDate >= ph.EffectiveFrom
            AND (pold.OrderDate <= ph.EffectiveTo OR ph.EffectiveTo IS NULL)
        ORDER BY 
            ph.EffectiveFrom DESC
    ) plph
)
SELECT *
INTO #TimeOfLineSales
FROM TimeOfLineSales;


SELECT
    SalesOrderLineID,
    OrderNumber,
    OrderDate,
    SKU,
    UnitPriceUsed,
    ListPriceAtTimeOfSale,
    [Difference],
    HasPriceMatch,
    IsDiscrepant
FROM #TimeOfLineSales
ORDER BY
    OrderDate,
    OrderNumber,
    SalesOrderLineID;

SELECT
    COUNT(*) AS TotalOrderLines,
    SUM(HasPriceMatch) AS MatchedPriceLines,
    SUM(CASE WHEN HasPriceMatch = 0 THEN 1 ELSE 0 END) AS UnmatchedPriceLines,
    SUM(IsDiscrepant) AS DiscrepantLines,
    CAST(
        SUM(IsDiscrepant) * 100.0 / NULLIF(COUNT(*), 0)
        AS DECIMAL(18, 2)
    ) AS PctDiscrepantAmongAllLines,
    CAST(
        SUM(IsDiscrepant) * 100.0 / NULLIF(SUM(HasPriceMatch), 0)
        AS DECIMAL(18, 2)
    ) AS PctDiscrepantAmongMatchedLines
FROM #TimeOfLineSales