/* Q11 - Cohort retention matrix (MonthIndex 0..6, long format)

Definitions
- Valid order = OrderStatusCode = 'DELIVERED'
- Customer monthly activity is reduced to 1 row per CustomerID + OrderMonth
- CohortMonth = first month in which the customer had a delivered order
- ActivityMonth = month in which the customer had at least one delivered order
- MonthIndex = DATEDIFF(MONTH, CohortMonth, ActivityMonth)
- Output is limited to MonthIndex values 0 through 6
- Only observable MonthIndex values are returned, fake future zeros are excluded
- CohortSize = number of customers in the cohort month
- ActiveCustomers = distinct customers from that cohort with activity in the given MonthIndex
- RetentionPct = ActiveCustomers / CohortSize * 100
- Long format = 1 row per CohortMonth + MonthIndex

Output columns
- CohortMonth
- MonthIndex
- ActiveCustomers
- CohortSize
- RetentionPct
*/

WITH CustomerOrders AS
(
    SELECT DISTINCT
        so.CustomerID,
        DATEFROMPARTS(YEAR(so.OrderDate), MONTH(so.OrderDate), 1) AS OrderMonth
    FROM sales.SalesOrder so
    WHERE
        so.OrderStatusCode = 'DELIVERED'
),
CustomerFirstOrder AS
(
    SELECT
        co.CustomerID,
        MIN(co.OrderMonth) AS CohortMonth
    FROM CustomerOrders co
    GROUP BY
        co.CustomerID
),
CohortSize AS
(
    SELECT
        cfo.CohortMonth,
        COUNT(*) AS CohortSize
    FROM CustomerFirstOrder cfo
    GROUP BY
        cfo.CohortMonth
),
MaxObservedMonth AS
(
    SELECT
        MAX(co.OrderMonth) AS MaxOrderMonth
    FROM CustomerOrders co
),
CustomerActivity AS
(
    SELECT
        co.CustomerID,
        cfo.CohortMonth,
        co.OrderMonth,
        DATEDIFF(MONTH, cfo.CohortMonth, co.OrderMonth) AS MonthIndex
    FROM CustomerOrders co
    JOIN CustomerFirstOrder cfo
        ON cfo.CustomerID = co.CustomerID
    WHERE
        DATEDIFF(MONTH, cfo.CohortMonth, co.OrderMonth) BETWEEN 0 AND 6
),
MonthIndexes AS
(
    SELECT v.MonthIndex
    FROM (VALUES (0),(1),(2),(3),(4),(5),(6)) v(MonthIndex)
),
ObservableCohortMonths AS
(
    SELECT
        cs.CohortMonth,
        cs.CohortSize,
        mi.MonthIndex
    FROM CohortSize cs
    CROSS JOIN MonthIndexes mi
    CROSS JOIN MaxObservedMonth mom
    WHERE
        mi.MonthIndex <= DATEDIFF(MONTH, cs.CohortMonth, mom.MaxOrderMonth)
)
SELECT
    ocm.CohortMonth,
    ocm.MonthIndex,
    COUNT(DISTINCT ca.CustomerID) AS ActiveCustomers,
    ocm.CohortSize,
    CAST
    (
        COUNT(DISTINCT ca.CustomerID) * 100.0
        / NULLIF(ocm.CohortSize, 0)
        AS DECIMAL(18, 2)
    ) AS RetentionPct
FROM ObservableCohortMonths ocm
LEFT JOIN CustomerActivity ca
    ON ca.CohortMonth = ocm.CohortMonth
    AND ca.MonthIndex = ocm.MonthIndex
GROUP BY
    ocm.CohortMonth,
    ocm.MonthIndex,
    ocm.CohortSize
ORDER BY
    ocm.CohortMonth,
    ocm.MonthIndex;