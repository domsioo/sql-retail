/* reporting.v_kpi_daily_mtd_ytd - Daily KPI with MTD/YTD extensions

Definitions
- Base dataset = reporting.v_kpi_daily
- Reporting grain = 1 row per calendar date
- NetSalesMTD = running sum of NetSales within the month
- NetSalesYTD = running sum of NetSales within the year
- DeliveredOrdersMTD = running sum of DeliveredOrders within the month
- DeliveredOrdersYTD = running sum of DeliveredOrders within the year

Output columns
- Date
- TotalOrders
- DeliveredOrders
- GrossSales
- DiscountTotal
- TaxTotal
- ShippingTotal
- NetSales
- NetSalesMTD
- NetSalesYTD
- DeliveredOrdersMTD
- DeliveredOrdersYTD
*/

CREATE OR ALTER VIEW [reporting].[v_kpi_daily_mtd_ytd]
AS
SELECT
    dk.[Date],
    dk.TotalOrders,
    dk.DeliveredOrders,
    dk.GrossSales,
    dk.DiscountTotal,
    dk.TaxTotal,
    dk.ShippingTotal,
    dk.NetSales,
    SUM(dk.NetSales) OVER (PARTITION BY DATEFROMPARTS(YEAR([Date]),MONTH([Date]), 1) ORDER BY [Date] ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS NetSalesMTD,
    SUM(dk.NetSales) OVER (PARTITION BY DATEFROMPARTS(YEAR([Date]), 1, 1) ORDER BY [Date] ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS NetSalesYTD,
    SUM(dk.DeliveredOrders) OVER(PARTITION BY DATEFROMPARTS(YEAR([Date]),MONTH([Date]),1) ORDER BY [Date] ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS DeliveredOrdersMTD,
    SUM(dk.DeliveredOrders) OVER(PARTITION BY DATEFROMPARTS(YEAR([Date]), 1, 1) ORDER BY [Date] ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS DeliveredOrdersYTD
FROM reporting.v_kpi_daily dk
GO