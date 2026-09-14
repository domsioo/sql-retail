/* Q21 - Return rate by root category + net after refunds

Definitions
- Delivered quantity / delivered net sales:
    sales from DELIVERED orders only
- Returned quantity:
    returns where ReturnStatusCode IN ('RECEIVED', 'REFUNDED')
    (REQUESTED returns are excluded)
- Refund amount:
    only ReturnLine rows with RefundStatusCode = 'REFUNDED'
    and RefundedAt IS NOT NULL
- Category/product net sales exclude shipping
- ReturnRatePct = ReturnedQuantity / DeliveredQuantity * 100

Output columns
- RootCategoryID
- RootCategoryName
- DeliveredQuantity
- ReturnedQuantity
- ReturnRatePct
- TotalRefundedAmount
- DeliveredNetSales
- NetSalesAfterRefunds
*/

WITH DeliveredProductSales AS
(
    SELECT
        sol.ProductID,
        SUM(sol.Quantity) AS DeliveredQuantity,
        SUM(sol.NetAmount) AS DeliveredNetSales
    FROM sales.SalesOrder so
    JOIN sales.SalesOrderLine sol
        ON sol.SalesOrderID = so.SalesOrderID
    WHERE
        so.OrderStatusCode = 'DELIVERED'
    GROUP BY
        sol.ProductID
),
ReturnedProductQuantity AS
(
    SELECT
        sol.ProductID,
        SUM(rl.Quantity) AS ReturnedQuantity
    FROM sales.ReturnHeader rh
    JOIN sales.ReturnLine rl
        ON rl.ReturnID = rh.ReturnID
    JOIN sales.SalesOrderLine sol
        ON sol.SalesOrderLineID = rl.SalesOrderLineID
    WHERE
        rh.ReturnStatusCode IN ('RECEIVED', 'REFUNDED')
    GROUP BY
        sol.ProductID
),
RefundedProductAmount AS
(
    SELECT
        sol.ProductID,
        SUM(rl.RefundAmount) AS RefundedAmount
    FROM sales.ReturnLine rl
    JOIN sales.SalesOrderLine sol
        ON sol.SalesOrderLineID = rl.SalesOrderLineID
    WHERE
        rl.RefundStatusCode = 'REFUNDED'
        AND rl.RefundedAt IS NOT NULL
    GROUP BY
        sol.ProductID
),
ProductCategoryMetrics AS
(
    SELECT
        pwr.ProductID,
        pwr.RootCategoryID,
        pwr.RootCategoryName,
        COALESCE(dps.DeliveredQuantity, 0) AS DeliveredQuantity,
        COALESCE(dps.DeliveredNetSales, 0.00) AS DeliveredNetSales,
        COALESCE(rpq.ReturnedQuantity, 0) AS ReturnedQuantity,
        COALESCE(rpa.RefundedAmount, 0.00) AS RefundedAmount
    FROM reporting.v_dim_product_with_root_category pwr
    LEFT JOIN DeliveredProductSales dps
        ON dps.ProductID = pwr.ProductID
    LEFT JOIN ReturnedProductQuantity rpq
        ON rpq.ProductID = pwr.ProductID
    LEFT JOIN RefundedProductAmount rpa
        ON rpa.ProductID = pwr.ProductID
)
SELECT
    pcm.RootCategoryID,
    pcm.RootCategoryName,
    SUM(pcm.DeliveredQuantity) AS DeliveredQuantity,
    SUM(pcm.ReturnedQuantity) AS ReturnedQuantity,
    CAST
    (
        SUM(pcm.ReturnedQuantity) * 100.0
        / NULLIF(SUM(pcm.DeliveredQuantity), 0)
        AS DECIMAL(18, 4)
    ) AS ReturnRatePct,
    CAST(SUM(pcm.RefundedAmount) AS DECIMAL(18, 2)) AS TotalRefundedAmount,
    CAST(SUM(pcm.DeliveredNetSales) AS DECIMAL(18, 2)) AS DeliveredNetSales,
    CAST(SUM(pcm.DeliveredNetSales) - SUM(pcm.RefundedAmount) AS DECIMAL(18, 2)) AS NetSalesAfterRefunds
FROM ProductCategoryMetrics pcm
GROUP BY
    pcm.RootCategoryID,
    pcm.RootCategoryName
ORDER BY
    NetSalesAfterRefunds DESC,
    pcm.RootCategoryName;