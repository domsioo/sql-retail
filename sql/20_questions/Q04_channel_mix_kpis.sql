/* Q4 - Channel mix KPIs

Definitions
- Answered via reporting view: reporting.v_kpi_channel_monthly
- Reporting grain = 1 row per ChannelCode + ChannelName
- Base dataset grain = 1 row per MonthStartDate + ChannelCode in reporting.v_kpi_channel_monthly
- Valid sale = OrderStatusCode = 'DELIVERED' (inherited from reporting.v_kpi_channel_monthly)
- Channel = ref.Channel.ChannelCode / ChannelName
- NetSales = SUM(sales.SalesOrderLine.NetAmount) + SUM(sales.SalesOrder.ShippingAmount), inherited from the source view
- DeliveredOrders = SUM(monthly DeliveredOrders) across all observable months
- AOV = SUM(NetSales) / SUM(DeliveredOrders)
- The source view includes zero-activity month/channel combinations via a month spine × channel spine

Output columns
- ChannelCode
- ChannelName
- DeliveredOrders
- NetSales
- AOV
*/

SELECT
    ChannelCode,
    ChannelName,
    SUM(DeliveredOrders) AS DeliveredOrders,
    CAST(SUM(NetSales) AS DECIMAL(18, 2)) AS NetSales,
    CAST(
        SUM(NetSales) / NULLIF(SUM(DeliveredOrders), 0) 
        AS DECIMAL(18, 2)
    ) AS AOV
FROM reporting.v_kpi_channel_monthly
GROUP BY
    ChannelCode,
    ChannelName
ORDER BY
    ChannelCode;