/* Q23 - Returns integrity & anomaly report

Definitions
- Answered via reporting views:
    1) reporting.v_audit_return_anomaly_summary
    2) reporting.v_audit_return_anomalies
- Base anomaly logic is implemented in reporting.v_audit_return_anomalies using reporting.v_audit_return_base
- This question file returns:
    1) a summary result set by anomaly type
    2) a detail result set with example anomaly records
- Summary grain = 1 row per anomaly type
- Detail grain = 1 row per anomaly instance

Implemented anomaly types
- RECEIVED_RETURN_WITHOUT_LINES
    ReturnStatusCode = 'RECEIVED' and no ReturnLine exists
- RETURN_CUSTOMER_MISMATCH
    ReturnCustomerID differs from OrderCustomerID
- RETURN_LINE_ORDER_MISMATCH
    ReturnLine exists but the sold line belongs to a different SalesOrder than the ReturnHeader
- REFUNDED_RETURN_WITHOUT_REFUNDED_LINES
    ReturnStatusCode = 'REFUNDED' but no related ReturnLine has RefundStatusCode = 'REFUNDED'
- RECEIVED_OR_REFUNDED_WITHOUT_RECEIVEDAT
    ReturnStatusCode IN ('RECEIVED', 'REFUNDED') and ReturnReceivedAt IS NULL
- REFUNDED_LINE_MISSING_REFUNDEDAT
    ReturnLineRefundStatusCode = 'REFUNDED' and ReturnLineRefundedAt IS NULL
- REFUNDEDAT_PRESENT_BUT_NOT_REFUNDED
    ReturnLineRefundedAt IS NOT NULL but ReturnLineRefundStatusCode <> 'REFUNDED'
- RETURN_QTY_GT_SOLD_QTY
    ReturnLineQuantity > SoldLineQuantity

Output 1 - Anomaly summary
- SortOrder
- AnomalyType
- AnomalyGrain
- Severity
- AnomaliesCount
- AffectedReturns
- AffectedReturnLines

Output 2 - Anomaly detail
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

SELECT
    SortOrder,
    AnomalyType,
    AnomalyGrain,
    Severity,
    AnomaliesCount,
    AffectedReturns,
    AffectedReturnLines
FROM reporting.v_audit_return_anomaly_summary
ORDER BY
    SortOrder;

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
FROM reporting.v_audit_return_anomalies
ORDER BY
    AnomalyType,
    ReturnID,
    ReturnLineID;