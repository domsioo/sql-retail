/* reporting.v_audit_missing_shipments_detail - Orders that should have shipment rows but do not

Definitions
- Reporting grain = 1 row per sales order
- Included orders = sales.SalesOrder rows where OrderStatusCode IN ('SHIPPED', 'DELIVERED')
- A missing shipment means no matching logistics.Shipment row exists for the SalesOrderID
- Implemented as a LEFT JOIN from sales.SalesOrder to logistics.Shipment
  with a filter where logistics.Shipment.SalesOrderID IS NULL

Output columns
- OrderNumber
- SalesOrderID
- OrderStatusCode
- OrderDate
- ChannelCode
- CustomerID
*/

CREATE OR ALTER VIEW [reporting].[v_audit_missing_shipments_detail]
AS
SELECT 
	so.OrderNumber,
	so.SalesOrderID,
	so.OrderStatusCode,
	so.OrderDate,
	so.ChannelCode,
	so.CustomerID 
FROM sales.SalesOrder so
LEFT JOIN logistics.Shipment s
	ON s.SalesOrderID = so.SalesOrderID
WHERE
	so.OrderStatusCode IN ('DELIVERED', 'SHIPPED')
	AND s.SalesOrderID IS NULL
GO