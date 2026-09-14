/* reporting.v_audit_missing_shipments_summary - Missing shipment counts by channel and order status

Definitions
- Base dataset = reporting.v_audit_missing_shipments_detail
- Reporting grain = 1 row per ChannelCode + OrderStatusCode
- TotalMissingShipments = count of orders in the detail view for that channel/status combination

Output columns
- ChannelCode
- OrderStatusCode
- TotalMissingShipments
*/

CREATE OR ALTER VIEW [reporting].[v_audit_missing_shipments_summary]
AS
SELECT
	msd.ChannelCode,
	msd.OrderStatusCode,
	COUNT(*) AS TotalMissingShipments
FROM reporting.v_audit_missing_shipments_detail msd
GROUP BY
	msd.ChannelCode,
	msd.OrderStatusCode
GO