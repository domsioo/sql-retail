/* Q1 - Date spine with orders (include zeros)

Definitions
- Answered via reporting view: reporting.v_kpi_daily
- Reporting grain = 1 row per calendar date
- Reporting date bucket = util.CalendarDate.[Date]
- Orders are assigned to a day based on sales.SalesOrder.OrderDate falling within:
    OrderDate >= [Date]
    AND OrderDate < DATEADD(DAY, 1, [Date])
- OrdersCount = count of all orders on that date, regardless of status
- DeliveredOrdersCount = count of orders where OrderStatusCode = 'DELIVERED'
- Date spine is driven from util.CalendarDate
- Output includes dates with zero orders
- Reporting range = observable min/max order dates from sales.SalesOrder

Output columns
- Date
- OrdersCount
- DeliveredOrdersCount
*/

SELECT
    [Date],
    TotalOrders AS OrdersCount,
    DeliveredOrders AS DeliveredOrdersCount
FROM reporting.v_kpi_daily
ORDER BY
    [Date];