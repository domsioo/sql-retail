/* Q12 - Pareto customers (80/20)

Definitions
- Valid sale = OrderStatusCode = 'DELIVERED'
- Reporting grain = 1 row per customer
- NetSales = SUM(sales.SalesOrderLine.NetAmount) + SUM(sales.SalesOrder.ShippingAmount)
- OverallNetSales = total delivered customer NetSales across all customers
- CumulativeNetSales = running total of customer NetSales ordered by NetSales DESC, CustomerID ASC
- CumulativePct = CumulativeNetSales / OverallNetSales * 100
- Pareto set = smallest cumulative set of customers, ordered by NetSales DESC then CustomerID ASC, 
  whose combined NetSales reaches/exceeds 80% of total NetSales
- IsWithinTop80PercentSales = 1 when the customer belongs to that Pareto set
- Tie-break at equal NetSales = CustomerID ASC

Output columns
- CustomerID
- CustomerNK
- FullName
- NetSales
- CumulativeNetSales
- CumulativePct
- IsWithinTop80PercentSales
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
CustomerNetSales AS
(
    SELECT
        so.CustomerID,
        SUM(COALESCE(ola.OrderLinesNetSales, 0.00) + COALESCE(so.ShippingAmount, 0.00)) AS NetSales
    FROM sales.SalesOrder so
    LEFT JOIN OrderLineAgg ola
        ON ola.SalesOrderID = so.SalesOrderID
    WHERE
        so.OrderStatusCode = 'DELIVERED'
    GROUP BY
        so.CustomerID
),
Ranked AS
(
    SELECT
        cns.CustomerID,
        c.CustomerNK,
        CONCAT(c.FirstName, ' ', c.LastName) AS FullName,
        cns.NetSales,
        SUM(cns.NetSales) OVER () AS OverallNetSales,
        SUM(cns.NetSales) OVER
        (
            ORDER BY cns.NetSales DESC, cns.CustomerID ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS CumulativeNetSales
    FROM CustomerNetSales cns
    JOIN crm.Customer c
        ON c.CustomerID = cns.CustomerID
),
Final AS
(
    SELECT
        r.*,
        LAG(r.CumulativeNetSales, 1, 0.00) OVER
        (
            ORDER BY r.NetSales DESC, r.CustomerID ASC
        ) AS PriorCumulativeNetSales
    FROM Ranked r
)
SELECT
    CustomerID,
    CustomerNK,
    FullName,
    CAST(NetSales AS DECIMAL(18, 2)) AS NetSales,
    CAST(CumulativeNetSales AS DECIMAL(18, 2)) AS CumulativeNetSales,
    CAST
    (
        CumulativeNetSales * 100.0 / NULLIF(OverallNetSales, 0.00)
        AS DECIMAL(18, 2)
    ) AS CumulativePct,
    CASE
        WHEN PriorCumulativeNetSales < 0.80 * OverallNetSales THEN 1
        ELSE 0
    END AS IsWithinTop80PercentSales
FROM Final
ORDER BY
    NetSales DESC,
    CustomerID ASC;