/* Q13 - Top products by net sales

Definitions
- Valid sale = OrderStatusCode = 'DELIVERED'
- Reporting grain = 1 row per product
- QuantitySold = SUM(sales.SalesOrderLine.Quantity)
- NetSales = SUM(sales.SalesOrderLine.NetAmount)
- ProductRank = DENSE_RANK() ordered by NetSales DESC
- Result returns the top 20 rows ordered by ProductRank ASC, NetSales DESC
- Ties beyond the 20-row cutoff are not automatically included

Output columns
- SKU
- ProductName
- QuantitySold
- NetSales
- ProductRank
*/

WITH ProductDetail AS (
	SELECT
		p.SKU,
		p.ProductName,
		SUM(sol.Quantity) AS QuantitySold,
		SUM(sol.NetAmount) AS NetSales
	FROM sales.SalesOrder so
	JOIN sales.SalesOrderLine sol
		ON sol.SalesOrderID = so.SalesOrderID
	JOIN ref.Product p
		ON p.ProductID = sol.ProductID
	WHERE 
		so.OrderStatusCode = 'DELIVERED'
	GROUP BY
		p.SKU,
		p.ProductName
)
SELECT TOP 20
	SKU,
	ProductName,
	QuantitySold,
	NetSales,
	DENSE_RANK() OVER (ORDER BY NetSales DESC) AS ProductRank
FROM ProductDetail
ORDER BY
	ProductRank ASC,
	NetSales DESC