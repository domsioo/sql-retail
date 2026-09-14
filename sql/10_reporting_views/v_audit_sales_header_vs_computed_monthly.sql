/* reporting.v_audit_sales_header_vs_computed_monthly - Monthly sales reconciliation audit

Definitions
- Reporting grain = 1 row per MonthStartDate
- Reporting month = util.CalendarDate.MonthStartDate based on sales.SalesOrder.OrderDate
- Valid sale = OrderStatusCode = 'DELIVERED'
- HeaderNetSales = SUM(sales.SalesOrder.HeaderNetAmount)
- ComputedNetSales = SUM(sales.SalesOrderLine.NetAmount) + SUM(sales.SalesOrder.ShippingAmount)
- DiffAmount = HeaderNetSales - ComputedNetSales
- DiffPct = DiffAmount / ComputedNetSales * 100
- OrdersWithMismatch = delivered orders where ABS(HeaderNetAmount - ComputedNetAmount) > 0.01
- OrdersHeaderHigher = delivered orders where HeaderNetAmount > ComputedNetAmount by more than 0.01
- OrdersHeaderLower = delivered orders where HeaderNetAmount < ComputedNetAmount by more than 0.01
- SalesOrderLine values are first aggregated to SalesOrderID before comparison
- Output includes observable months in the order date range

Output columns
- MonthStartDate
- DeliveredOrders
- HeaderNetSales
- ComputedNetSales
- DiffAmount
- DiffPct
- OrdersWithMismatch
- OrdersHeaderHigher
- OrdersHeaderLower
*/

CREATE OR ALTER VIEW [reporting].[v_audit_sales_header_vs_computed_monthly]
AS
WITH DateSpan AS
(
    SELECT
        CAST(MIN(so.OrderDate) AS DATE) AS MinDate,
        DATEADD(DAY, 1, CAST(MAX(so.OrderDate) AS DATE)) AS MaxDateExclusive
    FROM 
        sales.SalesOrder so
),
MonthSpine AS
(
    SELECT DISTINCT 
        cd.MonthStartDate
    FROM util.CalendarDate cd
    JOIN DateSpan ds
        ON cd.[Date] >= ds.MinDate AND cd.[Date] < ds.MaxDateExclusive
),
OrderLineAgg AS
(
    SELECT
        sol.SalesOrderID,
        SUM(sol.NetAmount) AS LinesNetSales
    FROM sales.SalesOrderLine sol
    GROUP BY 
        sol.SalesOrderID
),
DeliveredOrderAudit AS
(
    SELECT
        cd.MonthStartDate,
        so.SalesOrderID,
        so.HeaderNetAmount,
        COALESCE(ola.LinesNetSales, 0.00) AS LinesNetSales,
        COALESCE(so.ShippingAmount, 0.00) AS ShippingAmount,
        COALESCE(ola.LinesNetSales, 0.00) + COALESCE(so.ShippingAmount, 0.00) AS ComputedNetAmount,
        so.HeaderNetAmount - (COALESCE(ola.LinesNetSales, 0.00) + COALESCE(so.ShippingAmount, 0.00)) AS DiffAmount
    FROM sales.SalesOrder so
    JOIN DateSpan ds
        ON so.OrderDate >= ds.MinDate 
        AND so.OrderDate < ds.MaxDateExclusive
    JOIN util.CalendarDate cd
        ON so.OrderDate >= cd.[Date] 
        AND so.OrderDate < DATEADD(day, 1, cd.[Date])
    LEFT JOIN OrderLineAgg ola
        ON ola.SalesOrderID = so.SalesOrderID
    WHERE 
        so.OrderStatusCode = 'DELIVERED'
),
MonthlyAgg AS
(
    SELECT
        MonthStartDate,
        COUNT(*) AS DeliveredOrders,
        SUM(HeaderNetAmount) AS HeaderNetSales,
        SUM(ComputedNetAmount) AS ComputedNetSales,
        SUM(CASE WHEN DiffAmount > 0.01 OR DiffAmount < -0.01 THEN 1 ELSE 0 END) AS OrdersWithMismatch,
        SUM(CASE WHEN DiffAmount > 0.01 THEN 1 ELSE 0 END) AS OrdersHeaderHigher,
        SUM(CASE WHEN DiffAmount < -0.01 THEN 1 ELSE 0 END) AS OrdersHeaderLower
    FROM DeliveredOrderAudit
    GROUP BY 
        MonthStartDate
)
SELECT
    ms.MonthStartDate,
    COALESCE(ma.DeliveredOrders, 0) AS DeliveredOrders,
    COALESCE(ma.HeaderNetSales, 0.00) AS HeaderNetSales,
    COALESCE(ma.ComputedNetSales, 0.00) AS ComputedNetSales,
    COALESCE(ma.HeaderNetSales, 0.00) - COALESCE(ma.ComputedNetSales, 0.00) AS DiffAmount,
    CAST(
        (COALESCE(ma.HeaderNetSales, 0.00) - COALESCE(ma.ComputedNetSales, 0.00)) * 100
        / NULLIF(COALESCE(ma.ComputedNetSales, 0.00), 0.00)
        AS DECIMAL(18, 6)
    ) AS DiffPct,
    COALESCE(ma.OrdersWithMismatch, 0) AS OrdersWithMismatch,
    COALESCE(ma.OrdersHeaderHigher, 0) AS OrdersHeaderHigher,
    COALESCE(ma.OrdersHeaderLower, 0) AS OrdersHeaderLower
FROM MonthSpine ms
LEFT JOIN MonthlyAgg ma
    ON ma.MonthStartDate = ms.MonthStartDate;
GO