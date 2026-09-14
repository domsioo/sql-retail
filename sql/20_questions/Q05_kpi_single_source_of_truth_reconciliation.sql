/* Q5 - KPI single source of truth check (header vs line reconciliation)

Definitions
- Answered via reporting view: reporting.v_audit_sales_header_vs_computed_monthly
- Base dataset grain = 1 row per MonthStartDate in the source view
- Valid sale = OrderStatusCode = 'DELIVERED' (inherited from the source view)
- Reporting month bucket = util.CalendarDate.MonthStartDate, inherited from the source view
- HeaderNetSales = SUM(sales.SalesOrder.HeaderNetAmount)
- ComputedNetSales = SUM(sales.SalesOrderLine.NetAmount) + SUM(sales.SalesOrder.ShippingAmount)
- DiffAmount = HeaderNetSales - ComputedNetSales
- DiffPct = DiffAmount / ComputedNetSales * 100
- OrdersWithMismatch = delivered orders where ABS(HeaderNetAmount - ComputedNetAmount) > 0.01
- OrdersHeaderHigher = delivered orders where HeaderNetAmount > ComputedNetAmount by more than 0.01
- OrdersHeaderLower = delivered orders where HeaderNetAmount < ComputedNetAmount by more than 0.01
- SalesOrderLine values are first aggregated to SalesOrderID before comparison
- The question file returns two outputs:
    1) an overall one-row summary
    2) a monthly detail result set

Output 1 - Overall summary
- Grain = 1 row overall
- TotalHeaderNetSales
- TotalComputedNetSales
- TotalDiffAmount
- TotalDiffPct
- OrdersWithMismatch
- OrdersHeaderHigher
- OrdersHeaderLower

Output 2 - Monthly detail
- Grain = 1 row per MonthStartDate
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

SELECT
    SUM(HeaderNetSales) AS TotalHeaderNetSales,
    SUM(ComputedNetSales) AS TotalComputedNetSales,
    SUM(DiffAmount) AS TotalDiffAmount,
    CAST(
        SUM(DiffAmount) * 100.0 / NULLIF(SUM(ComputedNetSales), 0)
        AS DECIMAL(18, 6)
    ) AS TotalDiffPct,
    SUM(OrdersWithMismatch) AS OrdersWithMismatch,
    SUM(OrdersHeaderHigher) AS OrdersHeaderHigher,
    SUM(OrdersHeaderLower) AS OrdersHeaderLower
FROM reporting.v_audit_sales_header_vs_computed_monthly;

SELECT
    MonthStartDate,
    DeliveredOrders,
    HeaderNetSales,
    ComputedNetSales,
    DiffAmount,
    DiffPct,
    OrdersWithMismatch,
    OrdersHeaderHigher,
    OrdersHeaderLower
FROM reporting.v_audit_sales_header_vs_computed_monthly
ORDER BY
    MonthStartDate;