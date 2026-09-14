/* Q6 - Store leaderboard + contribution %

Definitions
- Valid sale = OrderStatusCode = 'DELIVERED'
- Scope = physical store orders only (sales.SalesOrder.ChannelCode = 'STORE')
- Reporting grain = 1 row per store
- NetSales = SUM(sales.SalesOrderLine.NetAmount) + SUM(sales.SalesOrder.ShippingAmount)
- DeliveredOrders = count of delivered store orders
- StoreRank = DENSE_RANK() ordered by NetSales DESC
- RevenueContributionPct = store NetSales / total store NetSales * 100
- CumulativeRevenueContributionPct = running cumulative revenue contribution ordered by NetSales DESC, StoreID ASC
- Top 20% revenue contribution set = smallest cumulative set of stores whose combined NetSales reaches/exceeds 20% of total store NetSales
- Tie-break at equal NetSales = StoreID ASC

Output columns
- StoreID
- StoreCode
- StoreName
- RegionCode
- DeliveredOrders
- NetSales
- RevenueContributionPct
- StoreRank
- CumulativeRevenueContributionPct
- IsInTop20PctRevenueContributionSet
- RevenueContributionBucket
*/

WITH LineAgg AS
(
    SELECT
        sol.SalesOrderID,
        SUM(sol.NetAmount) AS LinesNetSales
    FROM sales.SalesOrderLine sol
    GROUP BY
        sol.SalesOrderID
),
DeliveredStoreOrders AS
(
    SELECT
        so.SalesOrderID,
        so.StoreID,
        COALESCE(la.LinesNetSales, 0.00) + COALESCE(so.ShippingAmount, 0.00) AS OrderNetSales
    FROM sales.SalesOrder so
    LEFT JOIN LineAgg la
        ON la.SalesOrderID = so.SalesOrderID
    WHERE
        so.OrderStatusCode = 'DELIVERED'
        AND so.ChannelCode = 'STORE'
        AND so.StoreID IS NOT NULL
),
StoreAgg AS
(
    SELECT
        s.StoreID,
        s.StoreCode,
        s.StoreName,
        s.RegionCode,
        COUNT(dso.SalesOrderID) AS DeliveredOrders,
        CAST(COALESCE(SUM(dso.OrderNetSales), 0.00) AS DECIMAL(18, 2)) AS NetSales
    FROM ops.Store s
    LEFT JOIN DeliveredStoreOrders dso
        ON dso.StoreID = s.StoreID
    GROUP BY
        s.StoreID,
        s.StoreCode,
        s.StoreName,
        s.RegionCode
),
Ranked AS
(
    SELECT
        sa.StoreID,
        sa.StoreCode,
        sa.StoreName,
        sa.RegionCode,
        sa.DeliveredOrders,
        sa.NetSales,
        DENSE_RANK() OVER(ORDER BY sa.NetSales DESC) AS StoreRank,
        CAST
        (
            sa.NetSales * 100.0
            / NULLIF(SUM(sa.NetSales) OVER(), 0.00)
            AS DECIMAL(18, 4)
        ) AS RevenueContributionPct,
        CAST
        (
            SUM(sa.NetSales) OVER
            (
                ORDER BY sa.NetSales DESC, sa.StoreID ASC
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) * 100.0
            / NULLIF(SUM(sa.NetSales) OVER (), 0.00)
         AS DECIMAL(18, 4)
         ) AS CumulativeRevenueContributionPct
         FROM StoreAgg sa
),
Final AS
(
    SELECT
        r.*,
        LAG(r.CumulativeRevenueContributionPct, 1, 0.0000) OVER
        (
            ORDER BY r.NetSales DESC, r.StoreID ASC
        ) AS PriorCumulativeRevenueContributionPct
    FROM Ranked r
)
SELECT
    StoreID,
    StoreCode,
    StoreName,
    RegionCode,
    DeliveredOrders,
    NetSales,
    RevenueContributionPct,
    StoreRank,
    CumulativeRevenueContributionPct,
    CASE
        WHEN PriorCumulativeRevenueContributionPct < 20.0000 THEN 1
        ELSE 0
    END AS IsInTop20PctRevenueContributionSet,
    CASE
        WHEN PriorCumulativeRevenueContributionPct < 20.0000 THEN 'Top 20% revenue contribution set'
        ELSE 'Other'
    END AS RevenueContributionBucket
FROM Final
ORDER BY
    NetSales DESC,
    StoreID ASC;