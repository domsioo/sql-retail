/* Q9 - Customer lifetime value snapshot (Top 100)

Definitions
- Valid sale = OrderStatusCode = 'DELIVERED'
- Reporting grain = 1 row per customer
- Reporting date = sales.SalesOrder.OrderDate
- LifetimeNetSales = SUM(sales.SalesOrderLine.NetAmount) + SUM(sales.SalesOrder.ShippingAmount)
- DeliveredOrdersCount = count of delivered orders for the customer
- AOV = LifetimeNetSales / DeliveredOrdersCount
- FirstDeliveredOrder = earliest delivered order date for the customer
- LastDeliveredOrder = latest delivered order date for the customer
- Result returns the top 100 customers ordered by LifetimeNetSales DESC, CustomerID ASC
- LifetimeNetSalesRank uses DENSE_RANK() over LifetimeNetSales DESC

Output columns
- CustomerID
- CustomerNK
- CustomerName
- FirstDeliveredOrder
- LastDeliveredOrder
- DeliveredOrdersCount
- LifetimeNetSales
- AOV
- LifetimeNetSalesRank
*/

WITH OrderLineAgg AS
(
	SELECT
		sol.SalesOrderID,
		SUM(sol.NetAmount) AS OrderLinesNetSales
	FROM sales.SalesOrderLine sol
	GROUP BY
		sol.SalesOrderID
),
DeliveredOrders AS
(
	SELECT
		so.SalesOrderID,
		so.CustomerID,
		so.OrderDate,
		COALESCE(ola.OrderLinesNetSales, 0.00) + COALESCE(so.ShippingAmount, 0.00) AS OrderNetSales
	FROM sales.SalesOrder so
	LEFT JOIN OrderLineAgg ola
		ON ola.SalesOrderID = so.SalesOrderID
	WHERE
		so.OrderStatusCode = 'DELIVERED'
),
CustomerAgg AS
(
	SELECT
		d.CustomerID,
		MIN(d.OrderDate) AS FirstDeliveredOrder,
		MAX(d.OrderDate) AS LastDeliveredOrder,
		COUNT(*) AS DeliveredOrdersCount,
		SUM(d.OrderNetSales) AS LifetimeNetSales
	FROM DeliveredOrders d
	GROUP BY
		d.CustomerID
)
SELECT TOP 100
	ca.CustomerID,
	c.CustomerNK,
	CONCAT(c.FirstName, ' ', c.LastName) AS CustomerName,
	CAST(ca.FirstDeliveredOrder AS DATE) AS FirstDeliveredOrder,
	CAST(ca.LastDeliveredOrder AS DATE) AS LastDeliveredOrder,
	ca.DeliveredOrdersCount,
	CAST(ca.LifetimeNetSales AS DECIMAL(18, 2)) AS LifetimeNetSales,
	CAST(ca.LifetimeNetSales / NULLIF(ca.DeliveredOrdersCount, 0) AS DECIMAL(18, 2)) AS AOV,
	DENSE_RANK() OVER(ORDER BY ca.LifetimeNetSales DESC) AS LifetimeNetSalesRank
FROM CustomerAgg ca
JOIN crm.Customer c
	ON c.CustomerID = ca.CustomerID
ORDER BY
	ca.LifetimeNetSales DESC,
	ca.CustomerID ASC;