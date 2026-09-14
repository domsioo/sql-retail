/* Q16 - Price change impact (before/after 30-day window)

Definitions
- Reporting grain: 1 row per product price-change event
- Valid order: DELIVERED
- Sales date: SalesOrder.OrderDate
- Window length: 30 days
- BEFORE window: OrderDate >= DATEADD(DAY, -30, ChangeDate) AND OrderDate < ChangeDate
- AFTER window: OrderDate >= ChangeDate AND OrderDate < DATEADD(DAY, 30, ChangeDate)
- AvgUnitPrice = weighted average selling unit price = SUM(UnitPrice * Quantity) / SUM(Quantity)
- NetSales = SUM(SalesOrderLine.NetAmount)
- Each price-change event is analyzed independently
  If multiple price changes for the same product occur within overlapping 30-day windows, 
  the same delivered sales can contribute to more than one event
*/

WITH PriceHistoryOrdered AS
(
    SELECT
        plph.ProductID,
        plph.EffectiveFrom,
        plph.EffectiveTo,
        plph.ListPrice,
        LAG(plph.ListPrice) OVER
        (
            PARTITION BY plph.ProductID
            ORDER BY plph.EffectiveFrom ASC
        ) AS PrevListPrice
    FROM ref.ProductListPriceHistory plph
),
PriceChangeEvents AS
(
    SELECT
        pho.ProductID,
        pho.EffectiveFrom AS ChangeDate,
        pho.PrevListPrice AS OldListPrice,
        pho.ListPrice AS NewListPrice,
        pho.ListPrice - pho.PrevListPrice AS ListPriceDelta
    FROM PriceHistoryOrdered pho
    WHERE
        pho.PrevListPrice IS NOT NULL
        AND pho.PrevListPrice <> pho.ListPrice
),
DeliveredProductSales AS
(
    SELECT
        so.OrderDate,
        sol.ProductID,
        sol.Quantity,
        sol.UnitPrice,
        sol.NetAmount
    FROM sales.SalesOrder so
    JOIN sales.SalesOrderLine sol
        ON sol.SalesOrderID = so.SalesOrderID
    WHERE
        so.OrderStatusCode = 'DELIVERED'
),
BeforeAfterTaggedSales AS
(
    SELECT
        pce.ProductID,
        pce.ChangeDate,
        pce.OldListPrice,
        pce.NewListPrice,
        pce.ListPriceDelta,

        dps.OrderDate,
        dps.Quantity,
        dps.UnitPrice,
        dps.NetAmount,

        CASE
            WHEN dps.OrderDate >= DATEADD(DAY, -30, pce.ChangeDate)
            AND dps.OrderDate <  pce.ChangeDate
                THEN 'BEFORE'
            WHEN dps.OrderDate >= pce.ChangeDate
            AND dps.OrderDate <  DATEADD(DAY, 30, pce.ChangeDate)
                THEN 'AFTER'
        END AS PeriodFlag
    FROM PriceChangeEvents pce
    JOIN DeliveredProductSales dps
        ON dps.ProductID = pce.ProductID
        AND
        (
            (dps.OrderDate >= DATEADD(DAY, -30, pce.ChangeDate) AND dps.OrderDate < pce.ChangeDate)
            OR (dps.OrderDate >= pce.ChangeDate AND dps.OrderDate < DATEADD(DAY, 30, pce.ChangeDate))
        )
),
WindowAgg AS
(
    SELECT
        bats.ProductID,
        bats.ChangeDate,
        bats.OldListPrice,
        bats.NewListPrice,
        bats.ListPriceDelta,
        bats.PeriodFlag,
        SUM(bats.Quantity) AS QtySold,
        SUM(bats.NetAmount) AS NetSales,
        SUM(bats.UnitPrice * bats.Quantity) AS UnitPriceValue
    FROM BeforeAfterTaggedSales bats
    GROUP BY
        bats.ProductID,
        bats.ChangeDate,
        bats.OldListPrice,
        bats.NewListPrice,
        bats.ListPriceDelta,
        bats.PeriodFlag
),
FinalEventMetrics AS
(
    SELECT
        pce.ProductID,
        pce.ChangeDate,
        pce.OldListPrice,
        pce.NewListPrice,
        pce.ListPriceDelta,

        COALESCE(SUM(CASE WHEN wa.PeriodFlag = 'BEFORE' THEN wa.QtySold END), 0) AS BeforeQtySold,
        COALESCE(SUM(CASE WHEN wa.PeriodFlag = 'AFTER' THEN wa.QtySold END), 0) AS AfterQtySold,

        COALESCE(SUM(CASE WHEN wa.PeriodFlag = 'BEFORE' THEN wa.NetSales END), 0.00) AS BeforeNetSales,
        COALESCE(SUM(CASE WHEN wa.PeriodFlag = 'AFTER' THEN wa.NetSales END), 0.00) AS AfterNetSales,

        CAST
        (
            SUM(CASE WHEN wa.PeriodFlag = 'BEFORE' THEN wa.UnitPriceValue END)
            / NULLIF(SUM(CASE WHEN wa.PeriodFlag = 'BEFORE' THEN wa.QtySold END), 0)
            AS DECIMAL(18, 2)
        ) AS BeforeAvgUnitPrice,

        CAST
        (
            SUM(CASE WHEN wa.PeriodFlag = 'AFTER' THEN wa.UnitPriceValue END)
            / NULLIF(SUM(CASE WHEN wa.PeriodFlag = 'AFTER' THEN wa.QtySold END), 0)
            AS DECIMAL(18, 2)
        ) AS AfterAvgUnitPrice
    FROM PriceChangeEvents pce
    LEFT JOIN WindowAgg wa
        ON wa.ProductID = pce.ProductID
        AND wa.ChangeDate = pce.ChangeDate
        AND wa.OldListPrice = pce.OldListPrice
        AND wa.NewListPrice = pce.NewListPrice
    GROUP BY
        pce.ProductID,
        pce.ChangeDate,
        pce.OldListPrice,
        pce.NewListPrice,
        pce.ListPriceDelta
)
SELECT TOP 20
    fem.ProductID,
    p.SKU,
    p.ProductName,
    fem.ChangeDate,
    fem.OldListPrice,
    fem.NewListPrice,
    fem.ListPriceDelta,

    fem.BeforeQtySold,
    fem.AfterQtySold,
    fem.AfterQtySold - fem.BeforeQtySold AS QtySoldDelta,

    fem.BeforeAvgUnitPrice,
    fem.AfterAvgUnitPrice,
    CAST(fem.AfterAvgUnitPrice - fem.BeforeAvgUnitPrice AS DECIMAL(18, 2)) AS AvgUnitPriceDelta,

    CAST(fem.BeforeNetSales AS DECIMAL(18, 2)) AS BeforeNetSales,
    CAST(fem.AfterNetSales AS DECIMAL(18, 2)) AS AfterNetSales,
    CAST(fem.AfterNetSales - fem.BeforeNetSales AS DECIMAL(18, 2)) AS NetSalesDelta,
    CAST(ABS(fem.AfterNetSales - fem.BeforeNetSales) AS DECIMAL(18, 2)) AS AbsNetSalesDelta
FROM FinalEventMetrics fem
JOIN ref.Product p
    ON p.ProductID = fem.ProductID
ORDER BY
    ABS(fem.AfterNetSales - fem.BeforeNetSales) DESC,
    fem.ProductID ASC,
    fem.ChangeDate ASC;