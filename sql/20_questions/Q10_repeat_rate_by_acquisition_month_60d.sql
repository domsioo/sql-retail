/* Q10 - Repeat rate by acquisition month (60-day window)

Definitions
- Reporting grain = 1 row per AcquisitionMonth
- Valid order = OrderStatusCode = 'DELIVERED'
- FirstDeliveredOrderDate = earliest delivered order timestamp for the customer
- AcquisitionMonth = first day of the month of FirstDeliveredOrderDate
- Each customer belongs to exactly one acquisition cohort
- 60-day window = from FirstDeliveredOrderDate (inclusive)
                  to DATEADD(DAY, 60, FirstDeliveredOrderDate) (exclusive)
- DeliveredOrdersWithin60D = count of delivered orders for the customer in that 60-day window
- RepeatCustomers60D = customers where DeliveredOrdersWithin60D >= 2
- The first delivered order itself counts as one of the two, so this is effectively:
    did the customer place a second delivered order within 60 days of the first one
- CohortSize = count of customers in the acquisition cohort
- RepeatRate60D = RepeatCustomers60D / CohortSize * 100
- Each customer contributes at most once to RepeatCustomers60D

Output columns
- AcquisitionMonth
- CohortSize
- RepeatCustomers60D
- RepeatRate60D_Pct
*/

WITH DeliveredOrders AS
(
    SELECT
        so.SalesOrderID,
        so.CustomerID,
        so.OrderDate
    FROM sales.SalesOrder so
    WHERE
        so.OrderStatusCode = 'DELIVERED'
),
FirstDeliveredOrder AS
(
    SELECT
        d.CustomerID,
        MIN(d.OrderDate) AS FirstDeliveredOrderDate
    FROM DeliveredOrders d
    GROUP BY
        d.CustomerID
),
CustomerCohort AS
(
    SELECT
        fdo.CustomerID,
        fdo.FirstDeliveredOrderDate,
        DATEFROMPARTS(YEAR(fdo.FirstDeliveredOrderDate), MONTH(fdo.FirstDeliveredOrderDate), 1) AS AcquisitionMonth
    FROM FirstDeliveredOrder fdo
),
OrdersWithin60Days AS
(
    SELECT
        cc.CustomerID,
        cc.AcquisitionMonth,
        cc.FirstDeliveredOrderDate,
        COUNT(d.SalesOrderID) AS DeliveredOrdersWithin60D
    FROM CustomerCohort cc
    JOIN DeliveredOrders d
        ON d.CustomerID = cc.CustomerID
        AND d.OrderDate >= cc.FirstDeliveredOrderDate
        AND d.OrderDate < DATEADD(DAY, 60, cc.FirstDeliveredOrderDate)
    GROUP BY
        cc.CustomerID,
        cc.AcquisitionMonth,
        cc.FirstDeliveredOrderDate
),
CustomerRepeatFlag AS
(
    SELECT
        o.CustomerID,
        o.AcquisitionMonth,
        o.DeliveredOrdersWithin60D,
        CASE
            WHEN o.DeliveredOrdersWithin60D >= 2 THEN 1
            ELSE 0
        END AS RepeatedWithin60DFlag
    FROM OrdersWithin60Days o
)
SELECT
    crf.AcquisitionMonth,
    COUNT(*) AS CohortSize,
    SUM(crf.RepeatedWithin60DFlag) AS RepeatCustomers60D,
    CAST
    (
        SUM(crf.RepeatedWithin60DFlag) * 100.0
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(18, 2)
    ) AS RepeatRate60D_Pct
FROM CustomerRepeatFlag crf
GROUP BY
    crf.AcquisitionMonth
ORDER BY
    crf.AcquisitionMonth;