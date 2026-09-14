/* reporting.v_kpi_channel_monthly - Monthly channel KPI mart

Definitions
- Reporting grain = 1 row per MonthStartDate + ChannelCode
- Reporting month = util.CalendarDate.MonthStartDate based on sales.SalesOrder.OrderDate
- Valid sale = OrderStatusCode = 'DELIVERED'
- NetSales = SUM(sales.SalesOrderLine.NetAmount) + SUM(sales.SalesOrder.ShippingAmount)
- AOV = NetSales / DeliveredOrders
- AOV is NULL when DeliveredOrders = 0
- SalesOrderLine values are first aggregated to SalesOrderID to avoid shipping double-counting
- Output includes zero-activity month/channel combinations via month spine x channel spine

Output columns
- MonthStartDate
- ChannelCode
- ChannelName
- DeliveredOrders
- NetSales
- AOV
*/

CREATE OR ALTER VIEW [reporting].[v_kpi_channel_monthly]
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
        ON cd.[Date] >= ds.MinDate AND cd.[Date] <  ds.MaxDateExclusive
),
MonthChannelSpine AS
(
    SELECT
        m.MonthStartDate,
        ch.ChannelCode,
        ch.ChannelName
    FROM MonthSpine m
    CROSS JOIN ref.Channel ch
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
DeliveredMonthChannelAgg AS
(
    SELECT
        cd.MonthStartDate,
        so.ChannelCode,
        COUNT(*) AS DeliveredOrders,
        SUM(COALESCE(ola.LinesNetSales, 0) + COALESCE(so.ShippingAmount, 0)) AS NetSales
    FROM sales.SalesOrder so
    JOIN DateSpan ds
        ON so.OrderDate >= ds.MinDate AND so.OrderDate < ds.MaxDateExclusive
    JOIN util.CalendarDate cd
        ON so.OrderDate >= cd.[Date] AND so.OrderDate < DATEADD(DAY, 1, cd.[Date])
    LEFT JOIN OrderLineAgg ola
        ON ola.SalesOrderID = so.SalesOrderID
    WHERE 
        so.OrderStatusCode = 'DELIVERED'
    GROUP BY
        cd.MonthStartDate,
        so.ChannelCode
)
SELECT
    spine.MonthStartDate,
    spine.ChannelCode,
    spine.ChannelName,
    COALESCE(a.DeliveredOrders, 0) AS DeliveredOrders,
    COALESCE(a.NetSales, 0.00) AS NetSales,
    CAST(a.NetSales / NULLIF(a.DeliveredOrders, 0) AS DECIMAL(18, 2)) AS AOV
FROM MonthChannelSpine spine
LEFT JOIN DeliveredMonthChannelAgg a
    ON a.MonthStartDate = spine.MonthStartDate 
    AND a.ChannelCode = spine.ChannelCode
GO