/* Q18 - Orders that should have shipped but didn’t

Definitions
- Answered via reporting view: reporting.v_audit_missing_shipments_detail
- Supporting summary source = reporting.v_audit_missing_shipments_summary
- Reporting grain of detail output = 1 row per sales order
- Included orders = sales.SalesOrder rows where OrderStatusCode IN ('SHIPPED', 'DELIVERED')
- A missing shipment means no matching logistics.Shipment row exists for the SalesOrderID
- Implemented upstream as a LEFT JOIN from sales.SalesOrder to logistics.Shipment
  with a filter where logistics.Shipment.SalesOrderID IS NULL
- This question file returns:
    1) a detail result set of affected orders
    2) a summary result set by ChannelCode + OrderStatusCode

Output 1 - Missing shipment detail
- OrderNumber
- SalesOrderID
- OrderStatusCode
- OrderDate
- ChannelCode
- CustomerID

Output 2 - Missing shipment summary
- ChannelCode
- OrderStatusCode
- TotalMissingShipments
*/

SELECT
    OrderNumber,
    SalesOrderID,
    OrderStatusCode,
    OrderDate,
    ChannelCode,
    CustomerID
FROM reporting.v_audit_missing_shipments_detail
ORDER BY
    OrderDate,
    OrderNumber;

SELECT
    ChannelCode,
    OrderStatusCode,
    TotalMissingShipments
FROM reporting.v_audit_missing_shipments_summary
ORDER BY
    OrderStatusCode,
    ChannelCode;