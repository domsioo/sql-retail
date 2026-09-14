/* reporting.v_audit_return_anomalies - Return/refund anomaly log

Definitions
- Base dataset = reporting.v_audit_return_base
- Reporting grain = 1 row per anomaly instance
- Return-level anomalies are de-duplicated to one row per ReturnID where needed
- Return-line anomalies remain at return-line grain
- The view unions all implemented anomaly rules into one normalized anomaly log

Implemented anomaly types
- RECEIVED_RETURN_WITHOUT_LINES
- RETURN_CUSTOMER_MISMATCH
- RETURN_LINE_ORDER_MISMATCH
- REFUNDED_RETURN_WITHOUT_REFUNDED_LINES
- RECEIVED_OR_REFUNDED_WITHOUT_RECEIVEDAT
- REFUNDED_LINE_MISSING_REFUNDEDAT
- REFUNDEDAT_PRESENT_BUT_NOT_REFUNDED
- RETURN_QTY_GT_SOLD_QTY

Output columns
- AnomalyType
- AnomalyGrain
- Severity
- AnomalyDetails
- ReturnID
- ReturnNumber
- ReturnStatusCode
- ReturnReasonCode
- ReturnCreatedAt
- ReturnReceivedAt
- ReturnCustomerID
- OrderCustomerID
- ReturnSalesOrderID
- OrderNumber
- OrderDate
- SalesOrderStatusCode
- ChannelCode
- StoreID
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
- OrderShippingAmount
- OrderHeaderNetAmount
- OrderTotalQuantity
- OrderLinesNetAmount
*/

CREATE OR ALTER VIEW [reporting].[v_audit_return_anomalies]
AS
WITH
a_received_return_without_lines AS (
SELECT
    'RECEIVED_RETURN_WITHOUT_LINES' AS AnomalyType,
    'RETURN'                        AS AnomalyGrain,
    'WARN'                          AS Severity,
    'ReturnStatusCode=RECEIVED but no ReturnLine exists.' AS AnomalyDetails,

    b.ReturnID,
    b.ReturnNumber,
    b.ReturnStatusCode,
    b.ReturnReasonCode,
    b.ReturnCreatedAt,
    b.ReturnReceivedAt,

    b.ReturnCustomerID,
    b.OrderCustomerID,

    b.ReturnSalesOrderID,
    b.OrderNumber,
    b.OrderDate,
    b.SalesOrderStatusCode,
    b.ChannelCode,
    b.StoreID,

    b.ReturnLineID,
    b.ReturnSalesOrderLineID,
    b.ReturnLineQuantity,
    b.ReturnLineRefundAmount,
    b.ReturnLineRefundStatusCode,
    b.ReturnLineRefundedAt,

    b.SoldLineSalesOrderID,
    b.SoldLineSalesOrderLineID,
    b.SoldLineNumber,
    b.SoldLineProductID,
    b.SoldLineQuantity,

    b.OrderShippingAmount,
    b.OrderHeaderNetAmount,
    b.OrderTotalQuantity,
    b.OrderLinesNetAmount
FROM reporting.v_audit_return_base b
WHERE
    b.ReturnStatusCode = 'RECEIVED'
    AND b.ReturnLineID IS NULL
),

a_return_customer_mismatch AS (
SELECT
    'RETURN_CUSTOMER_MISMATCH' AS AnomalyType,
    'RETURN'                   AS AnomalyGrain,
    'WARN'                     AS Severity,
    'ReturnCustomerID differs from the customer who placed the order.' AS AnomalyDetails,

     cm.ReturnID,
     cm.ReturnNumber,
     cm.ReturnStatusCode,
     cm.ReturnReasonCode,
     cm.ReturnCreatedAt,
     cm.ReturnReceivedAt,

     cm.ReturnCustomerID,
     cm.OrderCustomerID,

     cm.ReturnSalesOrderID,
     cm.OrderNumber,
     cm.OrderDate,
     cm.SalesOrderStatusCode,
     cm.ChannelCode,
     cm.StoreID,

     cm.ReturnLineID,
     cm.ReturnSalesOrderLineID,
     cm.ReturnLineQuantity,
     cm.ReturnLineRefundAmount,
     cm.ReturnLineRefundStatusCode,
     cm.ReturnLineRefundedAt,

     cm.SoldLineSalesOrderID,
     cm.SoldLineSalesOrderLineID,
     cm.SoldLineNumber,
     cm.SoldLineProductID,
     cm.SoldLineQuantity,

     cm.OrderShippingAmount,
     cm.OrderHeaderNetAmount,
     cm.OrderTotalQuantity,
     cm.OrderLinesNetAmount
FROM (
    SELECT
        b.ReturnID,
        b.ReturnNumber,
        b.ReturnStatusCode,
        b.ReturnReasonCode,
        b.ReturnCreatedAt,
        b.ReturnReceivedAt,

        b.ReturnCustomerID,
        b.OrderCustomerID,

        b.ReturnSalesOrderID,
        b.OrderNumber,
        b.OrderDate,
        b.SalesOrderStatusCode,
        b.ChannelCode,
        b.StoreID,

        b.ReturnLineID,
        b.ReturnSalesOrderLineID,
        b.ReturnLineQuantity,
        b.ReturnLineRefundAmount,
        b.ReturnLineRefundStatusCode,
        b.ReturnLineRefundedAt,

        b.SoldLineSalesOrderID,
        b.SoldLineSalesOrderLineID,
        b.SoldLineNumber,
        b.SoldLineProductID,
        b.SoldLineQuantity,

        b.OrderShippingAmount,
        b.OrderHeaderNetAmount,
        b.OrderTotalQuantity,
        b.OrderLinesNetAmount,
        ROW_NUMBER() OVER(PARTITION BY b.ReturnID ORDER BY CASE WHEN b.ReturnLineID IS NULL THEN 1 ELSE 0 END, b.ReturnLineID) AS rn
    FROM reporting.v_audit_return_base b
    WHERE
        b.ReturnCustomerID <> b.OrderCustomerID
) cm
WHERE cm.rn = 1
),

a_return_line_order_mismatch AS (
SELECT
    'RETURN_LINE_ORDER_MISMATCH' AS AnomalyType,
    'RETURN_LINE'                AS AnomalyGrain,
    'WARN'                       AS Severity,
    'ReturnLine exists but the sold SalesOrder and return SalesOrder differ.' AS AnomalyDetails,

    b.ReturnID,
    b.ReturnNumber,
    b.ReturnStatusCode,
    b.ReturnReasonCode,
    b.ReturnCreatedAt,
    b.ReturnReceivedAt,

    b.ReturnCustomerID,
    b.OrderCustomerID,

    b.ReturnSalesOrderID,
    b.OrderNumber,
    b.OrderDate,
    b.SalesOrderStatusCode,
    b.ChannelCode,
    b.StoreID,

    b.ReturnLineID,
    b.ReturnSalesOrderLineID,
    b.ReturnLineQuantity,
    b.ReturnLineRefundAmount,
    b.ReturnLineRefundStatusCode,
    b.ReturnLineRefundedAt,

    b.SoldLineSalesOrderID,
    b.SoldLineSalesOrderLineID,
    b.SoldLineNumber,
    b.SoldLineProductID,
    b.SoldLineQuantity,

    b.OrderShippingAmount,
    b.OrderHeaderNetAmount,
    b.OrderTotalQuantity,
    b.OrderLinesNetAmount
FROM reporting.v_audit_return_base b
WHERE 
    b.ReturnLineID IS NOT NULL
    AND b.SoldLineSalesOrderID <> b.ReturnSalesOrderID
),

a_refunded_return_without_refunded_lines AS (
SELECT
    'REFUNDED_RETURN_WITHOUT_REFUNDED_LINES' AS AnomalyType,
    'RETURN'                                 AS AnomalyGrain,
    'ERROR'                                  AS Severity,
    'ReturnStatusCode=REFUNDED but no ReturnLine with RefundStatusCode=REFUNDED exists for this ReturnID.' AS AnomalyDetails,

    x.ReturnID,
    x.ReturnNumber,
    x.ReturnStatusCode,
    x.ReturnReasonCode,
    x.ReturnCreatedAt,
    x.ReturnReceivedAt,

    x.ReturnCustomerID,
    x.OrderCustomerID,

    x.ReturnSalesOrderID,
    x.OrderNumber,
    x.OrderDate,
    x.SalesOrderStatusCode,
    x.ChannelCode,
    x.StoreID,

    x.ReturnLineID,
    x.ReturnSalesOrderLineID,
    x.ReturnLineQuantity,
    x.ReturnLineRefundAmount,
    x.ReturnLineRefundStatusCode,
    x.ReturnLineRefundedAt,

    x.SoldLineSalesOrderID,
    x.SoldLineSalesOrderLineID,
    x.SoldLineNumber,
    x.SoldLineProductID,
    x.SoldLineQuantity,

    x.OrderShippingAmount,
    x.OrderHeaderNetAmount,
    x.OrderTotalQuantity,
    x.OrderLinesNetAmount
FROM (
    SELECT
        b.*,
        MAX(CASE WHEN b.ReturnLineRefundStatusCode = 'REFUNDED' THEN 1 ELSE 0 END)
            OVER (PARTITION BY b.ReturnID) AS HasRefundedLine,
        ROW_NUMBER() OVER
        (
            PARTITION BY b.ReturnID
            ORDER BY
                CASE WHEN b.ReturnLineID IS NULL THEN 1 ELSE 0 END,
                b.ReturnLineID
        ) AS rn
    FROM reporting.v_audit_return_base b
    WHERE b.ReturnStatusCode = 'REFUNDED'
) x
WHERE
    x.HasRefundedLine = 0
    AND x.rn = 1
),

a_received_or_refunded_without_receivedat AS (
SELECT
    'RECEIVED_OR_REFUNDED_WITHOUT_RECEIVEDAT' AS AnomalyType,
    'RETURN'                                  AS AnomalyGrain,
    'WARN'                                    AS Severity,
    'Return was either received or refunded but no received date.' AS AnomalyDetails,

    x.ReturnID,
    x.ReturnNumber,
    x.ReturnStatusCode,
    x.ReturnReasonCode,
    x.ReturnCreatedAt,
    x.ReturnReceivedAt,

    x.ReturnCustomerID,
    x.OrderCustomerID,

    x.ReturnSalesOrderID,
    x.OrderNumber,
    x.OrderDate,
    x.SalesOrderStatusCode,
    x.ChannelCode,
    x.StoreID,

    x.ReturnLineID,
    x.ReturnSalesOrderLineID,
    x.ReturnLineQuantity,
    x.ReturnLineRefundAmount,
    x.ReturnLineRefundStatusCode,
    x.ReturnLineRefundedAt,

    x.SoldLineSalesOrderID,
    x.SoldLineSalesOrderLineID,
    x.SoldLineNumber,
    x.SoldLineProductID,
    x.SoldLineQuantity,

    x.OrderShippingAmount,
    x.OrderHeaderNetAmount,
    x.OrderTotalQuantity,
    x.OrderLinesNetAmount
FROM (
    SELECT
        b.ReturnID,
        b.ReturnNumber,
        b.ReturnStatusCode,
        b.ReturnReasonCode,
        b.ReturnCreatedAt,
        b.ReturnReceivedAt,

        b.ReturnCustomerID,
        b.OrderCustomerID,

        b.ReturnSalesOrderID,
        b.OrderNumber,
        b.OrderDate,
        b.SalesOrderStatusCode,
        b.ChannelCode,
        b.StoreID,

        b.ReturnLineID,
        b.ReturnSalesOrderLineID,
        b.ReturnLineQuantity,
        b.ReturnLineRefundAmount,
        b.ReturnLineRefundStatusCode,
        b.ReturnLineRefundedAt,

        b.SoldLineSalesOrderID,
        b.SoldLineSalesOrderLineID,
        b.SoldLineNumber,
        b.SoldLineProductID,
        b.SoldLineQuantity,

        b.OrderShippingAmount,
        b.OrderHeaderNetAmount,
        b.OrderTotalQuantity,
        b.OrderLinesNetAmount,
        ROW_NUMBER() OVER(PARTITION BY b.ReturnID ORDER BY CASE WHEN b.ReturnLineID IS NULL THEN 1 ELSE 0 END, b.ReturnLineID) AS rn
    FROM reporting.v_audit_return_base b
    WHERE
        b.ReturnStatusCode IN ('RECEIVED', 'REFUNDED')
        AND b.ReturnReceivedAt IS NULL
) x
WHERE x.rn = 1
),

a_refunded_line_missing_refundedat AS (
SELECT
    'REFUNDED_LINE_MISSING_REFUNDEDAT' AS AnomalyType,
    'RETURN_LINE'                      AS AnomalyGrain,
    'WARN'                             AS Severity,
    'Refunded line doesn''t specify refund time' AS AnomalyDetails,

    b.ReturnID,
    b.ReturnNumber,
    b.ReturnStatusCode,
    b.ReturnReasonCode,
    b.ReturnCreatedAt,
    b.ReturnReceivedAt,

    b.ReturnCustomerID,
    b.OrderCustomerID,

    b.ReturnSalesOrderID,
    b.OrderNumber,
    b.OrderDate,
    b.SalesOrderStatusCode,
    b.ChannelCode,
    b.StoreID,

    b.ReturnLineID,
    b.ReturnSalesOrderLineID,
    b.ReturnLineQuantity,
    b.ReturnLineRefundAmount,
    b.ReturnLineRefundStatusCode,
    b.ReturnLineRefundedAt,

    b.SoldLineSalesOrderID,
    b.SoldLineSalesOrderLineID,
    b.SoldLineNumber,
    b.SoldLineProductID,
    b.SoldLineQuantity,

    b.OrderShippingAmount,
    b.OrderHeaderNetAmount,
    b.OrderTotalQuantity,
    b.OrderLinesNetAmount
FROM reporting.v_audit_return_base b
WHERE 
    b.ReturnLineRefundStatusCode = 'REFUNDED'
    AND b.ReturnLineRefundedAt IS NULL
),

a_refundedat_present_but_not_refunded AS (
SELECT
    'REFUNDEDAT_PRESENT_BUT_NOT_REFUNDED' AS AnomalyType,
    'RETURN_LINE'                        AS AnomalyGrain,
    'WARN'                          AS Severity,
    'Refund has refunded date but isn''t tagged as refunded' AS AnomalyDetails,

    b.ReturnID,
    b.ReturnNumber,
    b.ReturnStatusCode,
    b.ReturnReasonCode,
    b.ReturnCreatedAt,
    b.ReturnReceivedAt,

    b.ReturnCustomerID,
    b.OrderCustomerID,

    b.ReturnSalesOrderID,
    b.OrderNumber,
    b.OrderDate,
    b.SalesOrderStatusCode,
    b.ChannelCode,
    b.StoreID,

    b.ReturnLineID,
    b.ReturnSalesOrderLineID,
    b.ReturnLineQuantity,
    b.ReturnLineRefundAmount,
    b.ReturnLineRefundStatusCode,
    b.ReturnLineRefundedAt,

    b.SoldLineSalesOrderID,
    b.SoldLineSalesOrderLineID,
    b.SoldLineNumber,
    b.SoldLineProductID,
    b.SoldLineQuantity,

    b.OrderShippingAmount,
    b.OrderHeaderNetAmount,
    b.OrderTotalQuantity,
    b.OrderLinesNetAmount
FROM reporting.v_audit_return_base b
WHERE b.ReturnLineRefundedAt IS NOT NULL AND b.ReturnLineRefundStatusCode <> 'REFUNDED'
),

a_return_qty_gt_sold_qty AS (
SELECT
    'RETURN_QTY_GT_SOLD_QTY' AS AnomalyType,
    'RETURN_LINE'            AS AnomalyGrain,
    'WARN'                   AS Severity,
    'Check if returned quantity is greater than sold quantity' AS AnomalyDetails,

    b.ReturnID,
    b.ReturnNumber,
    b.ReturnStatusCode,
    b.ReturnReasonCode,
    b.ReturnCreatedAt,
    b.ReturnReceivedAt,

    b.ReturnCustomerID,
    b.OrderCustomerID,

    b.ReturnSalesOrderID,
    b.OrderNumber,
    b.OrderDate,
    b.SalesOrderStatusCode,
    b.ChannelCode,
    b.StoreID,

    b.ReturnLineID,
    b.ReturnSalesOrderLineID,
    b.ReturnLineQuantity,
    b.ReturnLineRefundAmount,
    b.ReturnLineRefundStatusCode,
    b.ReturnLineRefundedAt,

    b.SoldLineSalesOrderID,
    b.SoldLineSalesOrderLineID,
    b.SoldLineNumber,
    b.SoldLineProductID,
    b.SoldLineQuantity,

    b.OrderShippingAmount,
    b.OrderHeaderNetAmount,
    b.OrderTotalQuantity,
    b.OrderLinesNetAmount
FROM reporting.v_audit_return_base b
WHERE b.ReturnLineID IS NOT NULL AND b.ReturnLineQuantity > b.SoldLineQuantity
)

SELECT
    AnomalyType,
    AnomalyGrain,
    Severity,
    AnomalyDetails,
    ReturnID,
    ReturnNumber,
    ReturnStatusCode,
    ReturnReasonCode,
    ReturnCreatedAt,
    ReturnReceivedAt,
    ReturnCustomerID,
    OrderCustomerID,
    ReturnSalesOrderID,
    OrderNumber,
    OrderDate,
    SalesOrderStatusCode,
    ChannelCode,
    StoreID,
    ReturnLineID,
    ReturnSalesOrderLineID,
    ReturnLineQuantity,
    ReturnLineRefundAmount,
    ReturnLineRefundStatusCode,
    ReturnLineRefundedAt,
    SoldLineSalesOrderID,
    SoldLineSalesOrderLineID,
    SoldLineNumber,
    SoldLineProductID,
    SoldLineQuantity,
    OrderShippingAmount,
    OrderHeaderNetAmount,
    OrderTotalQuantity,
    OrderLinesNetAmount
FROM a_received_return_without_lines

UNION ALL

SELECT
    AnomalyType,
    AnomalyGrain,
    Severity,
    AnomalyDetails,
    ReturnID,
    ReturnNumber,
    ReturnStatusCode,
    ReturnReasonCode,
    ReturnCreatedAt,
    ReturnReceivedAt,
    ReturnCustomerID,
    OrderCustomerID,
    ReturnSalesOrderID,
    OrderNumber,
    OrderDate,
    SalesOrderStatusCode,
    ChannelCode,
    StoreID,
    ReturnLineID,
    ReturnSalesOrderLineID,
    ReturnLineQuantity,
    ReturnLineRefundAmount,
    ReturnLineRefundStatusCode,
    ReturnLineRefundedAt,
    SoldLineSalesOrderID,
    SoldLineSalesOrderLineID,
    SoldLineNumber,
    SoldLineProductID,
    SoldLineQuantity,
    OrderShippingAmount,
    OrderHeaderNetAmount,
    OrderTotalQuantity,
    OrderLinesNetAmount
FROM a_return_customer_mismatch

UNION ALL

SELECT
    AnomalyType,
    AnomalyGrain,
    Severity,
    AnomalyDetails,
    ReturnID,
    ReturnNumber,
    ReturnStatusCode,
    ReturnReasonCode,
    ReturnCreatedAt,
    ReturnReceivedAt,
    ReturnCustomerID,
    OrderCustomerID,
    ReturnSalesOrderID,
    OrderNumber,
    OrderDate,
    SalesOrderStatusCode,
    ChannelCode,
    StoreID,
    ReturnLineID,
    ReturnSalesOrderLineID,
    ReturnLineQuantity,
    ReturnLineRefundAmount,
    ReturnLineRefundStatusCode,
    ReturnLineRefundedAt,
    SoldLineSalesOrderID,
    SoldLineSalesOrderLineID,
    SoldLineNumber,
    SoldLineProductID,
    SoldLineQuantity,
    OrderShippingAmount,
    OrderHeaderNetAmount,
    OrderTotalQuantity,
    OrderLinesNetAmount
FROM a_return_line_order_mismatch

UNION ALL

SELECT
    AnomalyType,
    AnomalyGrain,
    Severity,
    AnomalyDetails,
    ReturnID,
    ReturnNumber,
    ReturnStatusCode,
    ReturnReasonCode,
    ReturnCreatedAt,
    ReturnReceivedAt,
    ReturnCustomerID,
    OrderCustomerID,
    ReturnSalesOrderID,
    OrderNumber,
    OrderDate,
    SalesOrderStatusCode,
    ChannelCode,
    StoreID,
    ReturnLineID,
    ReturnSalesOrderLineID,
    ReturnLineQuantity,
    ReturnLineRefundAmount,
    ReturnLineRefundStatusCode,
    ReturnLineRefundedAt,
    SoldLineSalesOrderID,
    SoldLineSalesOrderLineID,
    SoldLineNumber,
    SoldLineProductID,
    SoldLineQuantity,
    OrderShippingAmount,
    OrderHeaderNetAmount,
    OrderTotalQuantity,
    OrderLinesNetAmount
FROM a_refunded_return_without_refunded_lines

UNION ALL

SELECT
    AnomalyType,
    AnomalyGrain,
    Severity,
    AnomalyDetails,
    ReturnID,
    ReturnNumber,
    ReturnStatusCode,
    ReturnReasonCode,
    ReturnCreatedAt,
    ReturnReceivedAt,
    ReturnCustomerID,
    OrderCustomerID,
    ReturnSalesOrderID,
    OrderNumber,
    OrderDate,
    SalesOrderStatusCode,
    ChannelCode,
    StoreID,
    ReturnLineID,
    ReturnSalesOrderLineID,
    ReturnLineQuantity,
    ReturnLineRefundAmount,
    ReturnLineRefundStatusCode,
    ReturnLineRefundedAt,
    SoldLineSalesOrderID,
    SoldLineSalesOrderLineID,
    SoldLineNumber,
    SoldLineProductID,
    SoldLineQuantity,
    OrderShippingAmount,
    OrderHeaderNetAmount,
    OrderTotalQuantity,
    OrderLinesNetAmount
FROM a_received_or_refunded_without_receivedat

UNION ALL

SELECT
    AnomalyType,
    AnomalyGrain,
    Severity,
    AnomalyDetails,
    ReturnID,
    ReturnNumber,
    ReturnStatusCode,
    ReturnReasonCode,
    ReturnCreatedAt,
    ReturnReceivedAt,
    ReturnCustomerID,
    OrderCustomerID,
    ReturnSalesOrderID,
    OrderNumber,
    OrderDate,
    SalesOrderStatusCode,
    ChannelCode,
    StoreID,
    ReturnLineID,
    ReturnSalesOrderLineID,
    ReturnLineQuantity,
    ReturnLineRefundAmount,
    ReturnLineRefundStatusCode,
    ReturnLineRefundedAt,
    SoldLineSalesOrderID,
    SoldLineSalesOrderLineID,
    SoldLineNumber,
    SoldLineProductID,
    SoldLineQuantity,
    OrderShippingAmount,
    OrderHeaderNetAmount,
    OrderTotalQuantity,
    OrderLinesNetAmount
FROM a_refunded_line_missing_refundedat

UNION ALL

SELECT
    AnomalyType,
    AnomalyGrain,
    Severity,
    AnomalyDetails,
    ReturnID,
    ReturnNumber,
    ReturnStatusCode,
    ReturnReasonCode,
    ReturnCreatedAt,
    ReturnReceivedAt,
    ReturnCustomerID,
    OrderCustomerID,
    ReturnSalesOrderID,
    OrderNumber,
    OrderDate,
    SalesOrderStatusCode,
    ChannelCode,
    StoreID,
    ReturnLineID,
    ReturnSalesOrderLineID,
    ReturnLineQuantity,
    ReturnLineRefundAmount,
    ReturnLineRefundStatusCode,
    ReturnLineRefundedAt,
    SoldLineSalesOrderID,
    SoldLineSalesOrderLineID,
    SoldLineNumber,
    SoldLineProductID,
    SoldLineQuantity,
    OrderShippingAmount,
    OrderHeaderNetAmount,
    OrderTotalQuantity,
    OrderLinesNetAmount
FROM a_refundedat_present_but_not_refunded

UNION ALL

SELECT
    AnomalyType,
    AnomalyGrain,
    Severity,
    AnomalyDetails,
    ReturnID,
    ReturnNumber,
    ReturnStatusCode,
    ReturnReasonCode,
    ReturnCreatedAt,
    ReturnReceivedAt,
    ReturnCustomerID,
    OrderCustomerID,
    ReturnSalesOrderID,
    OrderNumber,
    OrderDate,
    SalesOrderStatusCode,
    ChannelCode,
    StoreID,
    ReturnLineID,
    ReturnSalesOrderLineID,
    ReturnLineQuantity,
    ReturnLineRefundAmount,
    ReturnLineRefundStatusCode,
    ReturnLineRefundedAt,
    SoldLineSalesOrderID,
    SoldLineSalesOrderLineID,
    SoldLineNumber,
    SoldLineProductID,
    SoldLineQuantity,
    OrderShippingAmount,
    OrderHeaderNetAmount,
    OrderTotalQuantity,
    OrderLinesNetAmount
FROM a_return_qty_gt_sold_qty;
GO