/* reporting.v_audit_return_base - Return/refund audit base dataset

Definitions
- Reporting grain = 1 row per ReturnHeader x ReturnLine
- Headers with no ReturnLine still appear once with ReturnLine* and SoldLine* columns NULL
- Return-level context comes from sales.ReturnHeader
- Order-level context comes from sales.SalesOrder
- Return-line context comes from sales.ReturnLine
- Sold-line context comes from sales.SalesOrderLine referenced by the return line
- OrderTotalQuantity and OrderLinesNetAmount are aggregated at SalesOrderID grain
- This view is the base layer for downstream anomaly detection

Output columns
- ReturnID
- ReturnNumber
- ReturnStatusCode
- ReturnReasonCode
- ReturnSalesOrderID
- ReturnCustomerID
- ReturnCreatedAt
- ReturnReceivedAt
- OrderNumber
- OrderDate
- SalesOrderStatusCode
- ChannelCode
- StoreID
- OrderCustomerID
- OrderShippingAmount
- OrderHeaderNetAmount
- OrderTotalQuantity
- OrderLinesNetAmount
- ReturnLineID
- ReturnSalesOrderLineID
- ReturnLineQuantity
- ReturnLineRefundAmount
- ReturnLineRefundStatusCode
- ReturnLineRefundedAt
- SoldLineSalesOrderID
- SoldLineSalesOrderLineID
- SoldLineNumber
- SoldLineProductID
- SoldLineQuantity
*/

CREATE OR ALTER VIEW [reporting].[v_audit_return_base]
AS
WITH OrderAgg AS
(
    SELECT
        SalesOrderID,
        SUM(Quantity) AS OrderTotalQuantity,
        SUM(NetAmount) AS OrderLinesNetAmount
    FROM sales.SalesOrderLine
    GROUP BY 
        SalesOrderID
)
SELECT
    -- Return header
    rh.ReturnID,
    rh.ReturnNumber,
    rh.ReturnStatusCode,
    rh.ReturnReasonCode,
    rh.SalesOrderID AS ReturnSalesOrderID,
    rh.CustomerID AS ReturnCustomerID,
    rh.CreatedAt AS ReturnCreatedAt,
    rh.ReceivedAt AS ReturnReceivedAt,

    -- Order
    so.OrderNumber,
    so.OrderDate,
    so.OrderStatusCode AS SalesOrderStatusCode,
    so.ChannelCode,
    so.StoreID,
    so.CustomerID AS OrderCustomerID,
    so.ShippingAmount AS OrderShippingAmount,
    so.HeaderNetAmount AS OrderHeaderNetAmount,

    -- Order aggregates
    oa.OrderTotalQuantity,
    oa.OrderLinesNetAmount,

    -- Return line (line-level - NULL when header has no lines)
    rl.ReturnLineID,
    rl.SalesOrderLineID AS ReturnSalesOrderLineID,
    rl.Quantity AS ReturnLineQuantity,
    rl.RefundAmount AS ReturnLineRefundAmount,
    rl.RefundStatusCode AS ReturnLineRefundStatusCode,
    rl.RefundedAt AS ReturnLineRefundedAt,

    -- Sold line referenced by the return line (for mismatch checks)
    sol.SalesOrderID AS SoldLineSalesOrderID,
    sol.SalesOrderLineID AS SoldLineSalesOrderLineID,
    sol.LineNumber AS SoldLineNumber,
    sol.ProductID AS SoldLineProductID,
    sol.Quantity AS SoldLineQuantity
FROM sales.ReturnHeader rh
LEFT JOIN sales.SalesOrder so
    ON so.SalesOrderID = rh.SalesOrderID
LEFT JOIN OrderAgg oa
    ON oa.SalesOrderID = rh.SalesOrderID
LEFT JOIN sales.ReturnLine rl
    ON rl.ReturnID = rh.ReturnID
LEFT JOIN sales.SalesOrderLine sol
    ON sol.SalesOrderLineID = rl.SalesOrderLineID
GO