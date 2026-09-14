/* reporting.v_audit_return_anomaly_catalog - Return anomaly metadata catalog

Definitions
- Reporting grain = 1 row per anomaly type
- Provides display metadata for anomaly reporting:
    SortOrder
    AnomalyType
    AnomalyGrain
    Severity
    AnomalyDetails
- Used to guarantee that summary reports include all defined anomaly types
  even when a given anomaly has zero observed rows

Output columns
- SortOrder
- AnomalyType
- AnomalyGrain
- Severity
- AnomalyDetails
*/

CREATE OR ALTER VIEW [reporting].[v_audit_return_anomaly_catalog]
AS
SELECT
    v.SortOrder,
    v.AnomalyType,
    v.AnomalyGrain,
    v.Severity,
    v.AnomalyDetails
FROM (VALUES
    ( 10, 'RECEIVED_RETURN_WITHOUT_LINES',           'RETURN',      'WARN', 'ReturnStatusCode=RECEIVED but no ReturnLine exists.' ),
    ( 20, 'RETURN_CUSTOMER_MISMATCH',                'RETURN',      'WARN', 'ReturnCustomerID differs from the customer who placed the order.' ),
    ( 30, 'RETURN_LINE_ORDER_MISMATCH',              'RETURN_LINE', 'WARN', 'ReturnLine exists but the sold SalesOrder and return SalesOrder differ.' ),
    ( 40, 'REFUNDED_RETURN_WITHOUT_REFUNDED_LINES',  'RETURN',      'ERROR','ReturnStatusCode=REFUNDED but no ReturnLine with RefundStatusCode=REFUNDED exists for this ReturnID.' ),
    ( 50, 'RECEIVED_OR_REFUNDED_WITHOUT_RECEIVEDAT', 'RETURN',      'WARN', 'Return was either received or refunded but no received date.' ),
    ( 60, 'REFUNDED_LINE_MISSING_REFUNDEDAT',        'RETURN_LINE', 'WARN', 'Refunded line is missing RefundedAt timestamp.' ),
    ( 70, 'REFUNDEDAT_PRESENT_BUT_NOT_REFUNDED',     'RETURN_LINE', 'WARN', 'RefundedAt is present but RefundStatusCode is not REFUNDED.' ),
    ( 80, 'RETURN_QTY_GT_SOLD_QTY',                  'RETURN_LINE', 'WARN', 'ReturnLineQuantity is greater than SoldLineQuantity.' )
) v(SortOrder, AnomalyType, AnomalyGrain, Severity, AnomalyDetails);
GO