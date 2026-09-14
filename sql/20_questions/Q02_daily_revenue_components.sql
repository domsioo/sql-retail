/* Q2 - Daily revenue components

Definitions
- Answered via reporting view: reporting.v_kpi_daily
- Reporting grain = 1 row per calendar date
- Reporting date bucket = util.CalendarDate.[Date]
- Orders are assigned to a day based on sales.SalesOrder.OrderDate falling within:
    OrderDate >= [Date]
    AND OrderDate < DATEADD(DAY, 1, [Date])
- Valid sale = OrderStatusCode = 'DELIVERED'
- GrossSales = SUM(sales.SalesOrderLine.GrossAmount) for delivered orders
- DiscountTotal = SUM(sales.SalesOrderLine.DiscountAmount) for delivered orders
- TaxTotal = SUM(sales.SalesOrderLine.TaxAmount) for delivered orders
- ShippingTotal = SUM(sales.SalesOrder.ShippingAmount) for delivered orders
- NetSales = SUM(sales.SalesOrderLine.NetAmount) + SUM(sales.SalesOrder.ShippingAmount) for delivered orders
- SalesOrderLine values are first aggregated to SalesOrderID to avoid shipping double-counting
- Date spine is driven from util.CalendarDate
- Output includes dates with zero activity
- Reporting range = observable min/max order dates from sales.SalesOrder

Output columns
- Date
- GrossSales
- DiscountTotal
- TaxTotal
- ShippingTotal
- NetSales
*/

SELECT
    [Date],
    GrossSales,
    DiscountTotal,
    TaxTotal,
    ShippingTotal,
    NetSales
FROM reporting.v_kpi_daily
ORDER BY
    [Date];