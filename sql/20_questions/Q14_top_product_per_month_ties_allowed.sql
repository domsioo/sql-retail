/* Q14 - Top product per month (ties allowed)

Definitions
- Valid sale = OrderStatusCode = 'DELIVERED'
- Reporting grain = 1 row per MonthStartDate + ProductID for products ranked #1 in that month
- Reporting month = first day of month based on sales.SalesOrder.OrderDate
- ProductMonthlySales = SUM(sales.SalesOrderLine.NetAmount)
- Shipping is excluded because no shipping allocation rule is applied to products
- Ranking method = DENSE_RANK() partitioned by MonthStartDate and ordered by ProductMonthlySales DESC
- Ties are included by returning all rows where rank = 1

Output columns
- MonthStartDate
- ProductID
- SKU
- ProductName
- ProductMonthlySales
*/

WITH ProductMonthlySales AS
(
	SELECT
		DATEFROMPARTS(YEAR(so.OrderDate), MONTH(so.OrderDate), 1) AS MonthStartDate,
		sol.ProductID,
		CAST(SUM(sol.NetAmount) AS DECIMAL(18, 2)) AS ProductMonthlySales
	FROM sales.SalesOrder so
	JOIN sales.SalesOrderLine sol
		ON sol.SalesOrderID = so.SalesOrderID
	WHERE so.OrderStatusCode = 'DELIVERED'
	GROUP BY
		DATEFROMPARTS(YEAR(so.OrderDate), MONTH(so.OrderDate), 1),
		sol.ProductID
),
Ranked AS
(
	SELECT
		pms.MonthStartDate,
		pms.ProductID,
		p.SKU,
		p.ProductName,
		pms.ProductMonthlySales,
		DENSE_RANK() OVER(PARTITION BY pms.MonthStartDate ORDER BY pms.ProductMonthlySales DESC) AS rnk
	FROM ProductMonthlySales pms
	JOIN ref.Product p
		ON p.ProductID = pms.ProductID
)
SELECT
	r.MonthStartDate,
	r.ProductID,
	r.SKU,
	r.ProductName,
	r.ProductMonthlySales
FROM Ranked r
WHERE r.rnk = 1
ORDER BY
	MonthStartDate ASC;