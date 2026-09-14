/* Q3 - MTD and YTD net sales by day

Definitions
- Answered via reporting view: reporting.v_kpi_daily_mtd_ytd
- Base dataset for cumulative calculations = reporting.v_kpi_daily
- Reporting grain = 1 row per calendar date
- Reporting date bucket = util.CalendarDate.[Date], inherited from reporting.v_kpi_daily
- Orders are assigned to a day based on sales.SalesOrder.OrderDate falling within:
    OrderDate >= [Date]
    AND OrderDate < DATEADD(DAY, 1, [Date])
- Valid sale = OrderStatusCode = 'DELIVERED' (inherited from reporting.v_kpi_daily)
- NetSales = SUM(sales.SalesOrderLine.NetAmount) + SUM(sales.SalesOrder.ShippingAmount) for delivered orders
- NetSalesMTD = running sum of NetSales within the calendar month
- NetSalesYTD = running sum of NetSales within the calendar year
- Zero-activity dates are preserved because the underlying daily KPI view is calendar-driven

Output columns
- Date
- NetSales
- NetSalesMTD
- NetSalesYTD
*/

SELECT
    [Date],
    NetSales,
    NetSalesMTD,
    NetSalesYTD
FROM reporting.v_kpi_daily_mtd_ytd
ORDER BY
    [Date];