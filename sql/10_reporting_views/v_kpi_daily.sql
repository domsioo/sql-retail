/* reporting.v_kpi_daily - Daily KPI backbone

Definitions
- Reporting grain = 1 row per calendar date
- Reporting date bucket = util.CalendarDate.[Date]
- Observable reporting range is derived from the minimum and maximum sales.SalesOrder.OrderDate values
- Orders are assigned to a date when:
    sales.SalesOrder.OrderDate >= util.CalendarDate.[Date]
    AND sales.SalesOrder.OrderDate < DATEADD(DAY, 1, util.CalendarDate.[Date])
- TotalOrders = count of all orders assigned to that date, regardless of status
- DeliveredOrders = count of orders where OrderStatusCode = 'DELIVERED'
- GrossSales = SUM(sales.SalesOrderLine.GrossAmount) for delivered orders
- DiscountTotal = SUM(sales.SalesOrderLine.DiscountAmount) for delivered orders
- TaxTotal = SUM(sales.SalesOrderLine.TaxAmount) for delivered orders
- ShippingTotal = SUM(sales.SalesOrder.ShippingAmount) for delivered orders
- NetSales = SUM(sales.SalesOrderLine.NetAmount) + SUM(sales.SalesOrder.ShippingAmount) for delivered orders
- SalesOrderLine values are first aggregated to SalesOrderID to avoid shipping double-counting
- Date spine is driven from util.CalendarDate
- Output includes dates with zero orders

Output columns
- Date
- TotalOrders
- DeliveredOrders
- GrossSales
- DiscountTotal
- TaxTotal
- ShippingTotal
- NetSales
*/

CREATE OR ALTER VIEW [reporting].[v_kpi_daily]
AS
WITH DateSpan AS
(
    SELECT
        CAST(MIN(so.OrderDate) AS DATE) AS MinDate,
        DATEADD(DAY, 1, CAST(MAX(so.OrderDate) AS DATE)) AS MaxDateExclusive
    FROM sales.SalesOrder so
),
OrderLineAgg AS
(
    SELECT
        sol.SalesOrderID,
        SUM(sol.GrossAmount) AS GrossSales,
        SUM(sol.DiscountAmount) AS DiscountTotal,
        SUM(sol.TaxAmount) AS TaxTotal,
        SUM(sol.NetAmount) AS LinesNetSales
    FROM sales.SalesOrderLine sol
    GROUP BY 
        sol.SalesOrderID
),
DailyKPI AS
(
    SELECT
        cd.[Date],
        COUNT(so.SalesOrderID) AS TotalOrders,
        SUM(CASE WHEN so.OrderStatusCode = 'DELIVERED' THEN 1 ELSE 0 END) AS DeliveredOrders,

        SUM(CASE WHEN so.OrderStatusCode = 'DELIVERED' THEN COALESCE(ola.GrossSales, 0) ELSE 0 END) AS GrossSales,
        SUM(CASE WHEN so.OrderStatusCode = 'DELIVERED' THEN COALESCE(ola.DiscountTotal, 0) ELSE 0 END) AS DiscountTotal,
        SUM(CASE WHEN so.OrderStatusCode = 'DELIVERED' THEN COALESCE(ola.TaxTotal, 0) ELSE 0 END) AS TaxTotal,

        SUM(CASE WHEN so.OrderStatusCode = 'DELIVERED' THEN COALESCE(so.ShippingAmount, 0) ELSE 0 END) AS ShippingTotal,

        SUM(CASE 
                WHEN so.OrderStatusCode = 'DELIVERED' 
                    THEN COALESCE(ola.LinesNetSales, 0) + COALESCE(so.ShippingAmount, 0) 
                ELSE 0 
            END) AS NetSales
    FROM util.CalendarDate cd
    JOIN DateSpan ds
        ON cd.[Date] >= ds.MinDate AND cd.[Date] < ds.MaxDateExclusive
    LEFT JOIN sales.SalesOrder so
        ON so.OrderDate >= cd.[Date] AND so.OrderDate < DATEADD(DAY, 1, cd.[Date])
    LEFT JOIN OrderLineAgg ola
        ON ola.SalesOrderID = so.SalesOrderID
    GROUP BY
        cd.[Date]
)
SELECT
    [Date],
    TotalOrders,
    DeliveredOrders,
    GrossSales,
    DiscountTotal,
    TaxTotal,
    ShippingTotal,
    NetSales
FROM DailyKPI
GO