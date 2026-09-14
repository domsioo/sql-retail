/* Q19 - Delivery performance by carrier

Definitions
- Reporting grain = 1 row per carrier
- Shipment population = all rows from logistics.Shipment joined to sales.SalesOrder
- AvgOrderToShipMinutes = AVG(DATEDIFF(MINUTE, sales.SalesOrder.OrderDate, logistics.Shipment.ShippedAt))
- AvgShipToDeliverMinutes = AVG(DATEDIFF(MINUTE, logistics.Shipment.ShippedAt, logistics.Shipment.DeliveredAt))
  calculated only for shipments where DeliveredAt IS NOT NULL
- TotalShipments = count of all shipment rows for the carrier
- ShipmentsWithDeliveredAt = count of shipment rows where DeliveredAt IS NOT NULL
- DeliveredStatusShipments = count of shipment rows where ShipmentStatusCode = 'DELIVERED'
- LostShipments = count of shipment rows where ShipmentStatusCode = 'LOST'
- DeliveredStatusMissingDeliveredAt = shipments where ShipmentStatusCode = 'DELIVERED'
  and DeliveredAt IS NULL
- LostShipmentRatePct = LostShipments / TotalShipments * 100
- Output includes all carriers from ref.Carrier, even if a carrier has zero shipments

Output columns
- CarrierID
- CarrierName
- TotalShipments
- ShipmentsWithDeliveredAt
- DeliveredStatusShipments
- LostShipments
- DeliveredStatusMissingDeliveredAt
- AvgOrderToShipMinutes
- AvgShipToDeliverMinutes
- LostShipmentRatePct
*/

WITH ShipmentBase AS
(
	SELECT
        s.ShipmentID,
        s.CarrierID,
        s.ShipmentStatusCode,
        so.OrderDate,
        s.ShippedAt,
        s.DeliveredAt,
		DATEDIFF(MINUTE, so.OrderDate, s.ShippedAt) AS OrderToShipMinutes,
        CASE
            WHEN s.DeliveredAt IS NOT NULL
                THEN DATEDIFF(MINUTE, s.ShippedAt, s.DeliveredAt)
            ELSE NULL
        END AS ShipToDeliverMinutes
	FROM logistics.Shipment s
	JOIN sales.SalesOrder so
        ON so.SalesOrderID = s.SalesOrderID
),
CarrierAgg AS
(
	SELECT
		sb.CarrierID,
		COUNT(*) AS TotalShipments,
		SUM(CASE WHEN sb.DeliveredAt IS NOT NULL THEN 1 ELSE 0 END) AS ShipmentsWithDeliveredAt,
		SUM(CASE WHEN sb.ShipmentStatusCode = 'DELIVERED' THEN 1 ELSE 0 END) AS DeliveredStatusShipments,
		SUM(CASE WHEN sb.ShipmentStatusCode = 'LOST' THEN 1 ELSE 0 END) AS LostShipments,
		SUM(CASE WHEN sb.ShipmentStatusCode = 'DELIVERED' AND sb.DeliveredAt IS NULL THEN 1 ELSE 0 END) AS DeliveredStatusMissingDeliveredAt,
		CAST(AVG(CAST(sb.OrderToShipMinutes AS DECIMAL(18, 2))) AS DECIMAL(18, 2)) AS AvgOrderToShipMinutes,
		CAST(AVG(CAST(sb.ShipToDeliverMinutes AS DECIMAL(18, 2))) AS DECIMAL(18, 2)) AS AvgShipToDeliverMinutes,
		CAST(
			SUM(CASE WHEN sb.ShipmentStatusCode = 'LOST' THEN 1 ELSE 0 END) * 100.0 
			/ NULLIF(COUNT(*), 0)
			AS DECIMAL(18, 2)
		) AS LostShipmentRatePct
	FROM ShipmentBase sb
	GROUP BY 
        sb.CarrierID
)
SELECT
    c.CarrierID,
    c.CarrierName,
    COALESCE(ca.TotalShipments, 0) AS TotalShipments,
    COALESCE(ca.ShipmentsWithDeliveredAt, 0) AS ShipmentsWithDeliveredAt,
	COALESCE(ca.DeliveredStatusShipments, 0) AS DeliveredStatusShipments,
    COALESCE(ca.LostShipments, 0) AS LostShipments,
    COALESCE(ca.DeliveredStatusMissingDeliveredAt, 0) AS DeliveredStatusMissingDeliveredAt,
    ca.AvgOrderToShipMinutes,
    ca.AvgShipToDeliverMinutes,
    ca.LostShipmentRatePct
FROM ref.Carrier c
LEFT JOIN CarrierAgg ca
    ON ca.CarrierID = c.CarrierID
ORDER BY
    c.CarrierName;