/* Q8 - New vs returning customers (monthly)

Definitions
- Valid sale = OrderStatusCode = 'DELIVERED'
- Reporting grain = 1 row per month
- Reporting month = first day of month based on sales.SalesOrder.OrderDate
- Customer-month activity = one row per CustomerID + MonthBucket when the customer had at least one delivered order in that month
- FirstOrderMonth = earliest month in which the customer had a delivered order
- NewCustomers = customers whose FirstOrderMonth = reporting month
- ReturningCustomers = customers with delivered order activity in the reporting month where FirstOrderMonth < reporting month
- Output includes observable months in the delivered-order date range

Output columns
- MonthBucket
- NewCustomers
- ReturningCustomers
*/

WITH DateSpan AS
(
    SELECT
        CAST(MIN(so.OrderDate) AS DATE) AS MinDate,
        DATEADD(DAY, 1, CAST(MAX(so.OrderDate) AS DATE)) AS MaxDateExclusive
    FROM sales.SalesOrder so
    WHERE
        so.OrderStatusCode = 'DELIVERED'
),
MonthSpan AS
(
    SELECT DISTINCT 
        cd.MonthStartDate
    FROM util.CalendarDate cd
    JOIN DateSpan ds
        ON cd.[Date] >= ds.MinDate AND cd.[Date] < ds.MaxDateExclusive
),
CustomerMonth AS
(
    SELECT DISTINCT
        so.CustomerID,
        DATEFROMPARTS(YEAR(so.OrderDate), MONTH(so.OrderDate), 1) AS MonthBucket
    FROM sales.SalesOrder so
    WHERE so.OrderStatusCode = 'DELIVERED'
),
FirstMonth AS
(
    SELECT
        CustomerID,
        MIN(MonthBucket) AS FirstOrderMonth
    FROM CustomerMonth
    GROUP BY CustomerID
)
SELECT
    ms.MonthStartDate AS MonthBucket,
    SUM(CASE WHEN fm.FirstOrderMonth = ms.MonthStartDate THEN 1 ELSE 0 END) AS NewCustomers,
    SUM(CASE WHEN fm.FirstOrderMonth < ms.MonthStartDate THEN 1 ELSE 0 END) AS ReturningCustomers
FROM MonthSpan ms
LEFT JOIN CustomerMonth cm
    ON ms.MonthStartDate = cm.MonthBucket
LEFT JOIN FirstMonth fm
    ON cm.CustomerID = fm.CustomerID
GROUP BY
    ms.MonthStartDate
ORDER BY 
    ms.MonthStartDate;