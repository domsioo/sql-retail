/* Q20 - On-time delivery rate by customer region (as-of order date)

Definitions
- Reporting grain = 1 row per historical RegionCode
- Included shipments:
    logistics.Shipment.ShipmentStatusCode = 'DELIVERED'
    AND logistics.Shipment.DeliveredAt IS NOT NULL
- Historical region is determined as-of CAST(sales.SalesOrder.OrderDate AS DATE)
- Effective dating rule:
    OrderDateDate >= crm.CustomerAttributeHistory.EffectiveFrom
    AND (
        crm.CustomerAttributeHistory.EffectiveTo IS NULL
        OR OrderDateDate < DATEADD(DAY, 1, crm.CustomerAttributeHistory.EffectiveTo)
    )
- If multiple historical rows match, the row with the latest EffectiveFrom is chosen
- SLA rule:
    on-time = DeliveredAt <= DATEADD(DAY, 3, ShippedAt)
    (exact 72-hour SLA)
- AvgShipToDeliverDays = AVG(DATEDIFF(MINUTE, ShippedAt, DeliveredAt)) / 1440.0
- AvgShipToDeliverHours = AVG(DATEDIFF(MINUTE, ShippedAt, DeliveredAt)) / 60.0
- Unmatched historical region rows are grouped into RegionCode = 'UNKNOWN'

Output columns
- RegionCode
- DeliveredShipments
- OnTimeShipments
- OnTimeDeliveryRatePct
- AvgShipToDeliverDays
- AvgShipToDeliverHours
*/

WITH DeliveredShipments AS
(
    SELECT
        s.ShipmentID,
        so.SalesOrderID,
        so.CustomerID,
        CAST(so.OrderDate AS DATE) AS OrderDateDate,
        s.ShippedAt,
        s.DeliveredAt
    FROM logistics.Shipment s
    JOIN sales.SalesOrder so
        ON so.SalesOrderID = s.SalesOrderID
    WHERE
        s.ShipmentStatusCode = 'DELIVERED'
        AND s.DeliveredAt IS NOT NULL
),
ShipmentRegionAsOf AS
(
    SELECT
        ds.ShipmentID,
        ds.SalesOrderID,
        ds.CustomerID,
        COALESCE(region_asof.RegionCode, 'UNKNOWN') AS RegionCode,
        DATEDIFF(MINUTE, ds.ShippedAt, ds.DeliveredAt) AS ShipToDeliverMinutes,
        CASE
            WHEN ds.DeliveredAt <= DATEADD(DAY, 3, ds.ShippedAt) THEN 1
            ELSE 0
        END AS IsOnTimeDelivery
    FROM DeliveredShipments ds
    OUTER APPLY
    (
        SELECT TOP 1
            cah.RegionCode
        FROM crm.CustomerAttributeHistory cah
        WHERE
            cah.CustomerID = ds.CustomerID
            AND ds.OrderDateDate >= cah.EffectiveFrom
            AND (cah.EffectiveTo IS NULL OR ds.OrderDateDate < DATEADD(DAY, 1, cah.EffectiveTo))
        ORDER BY
            cah.EffectiveFrom DESC
    ) region_asof
)
SELECT
    sr.RegionCode,
    COUNT(*) AS DeliveredShipments,
    SUM(sr.IsOnTimeDelivery) AS OnTimeShipments,
    CAST
    (
        SUM(sr.IsOnTimeDelivery) * 100.0
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(18, 2)
    ) AS OnTimeDeliveryRatePct,
    CAST
    (
        AVG(CAST(sr.ShipToDeliverMinutes AS DECIMAL(18, 2))) / 1440.0
        AS DECIMAL(18, 2)
    ) AS AvgShipToDeliverDays,
    CAST
    (
        AVG(CAST(sr.ShipToDeliverMinutes AS DECIMAL(18, 2))) / 60.0
        AS DECIMAL(18, 2)
    ) AS AvgShipToDeliverHours
FROM ShipmentRegionAsOf sr
GROUP BY
    sr.RegionCode
ORDER BY
    sr.RegionCode;