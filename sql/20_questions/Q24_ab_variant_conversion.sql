/* Q24 - A/B variant conversion

Definitions
- Reporting grain = 1 row per A/B variant
- Session grain is enforced before final aggregation
- Variant source = web.Event.Properties
- Sessions are included only when:
    AbVariant IS NOT NULL
    AND the session has at most one distinct variant value across its events
- HasPurchase = 1 when the session has at least one PURCHASE event with SalesOrderID IS NOT NULL
- SessionsWithPurchase = count of sessions where HasPurchase = 1
- ConversionRatePct = SessionsWithPurchase / Sessions * 100
- TimeToPurchaseMinutes = time from web.Session.StartedAt to the first qualifying PURCHASE event
- AvgTimeToPurchaseMinutes is calculated only across purchase sessions
- Sessions with conflicting multiple variants are excluded

Output columns
- AbVariant
- Sessions
- SessionsWithPurchase
- ConversionRatePct
- AvgTimeToPurchaseMinutes
*/

WITH EventBase AS
(
    SELECT
        e.WebSessionID,
        JSON_VALUE(e.Properties, '$.ab_variant') AS AbVariant,
        e.EventType,
        e.SalesOrderID,
        e.EventTime
    FROM web.Event e
),
SessionFacts AS
(
    SELECT
        s.WebSessionID,
        s.StartedAt,
        MIN(eb.AbVariant) AS AbVariant,
        COUNT(DISTINCT eb.AbVariant) AS DistinctVariantCount,
        MAX(CASE WHEN eb.EventType = 'PURCHASE' AND eb.SalesOrderID IS NOT NULL THEN 1 ELSE 0 END) AS HasPurchase,
        MIN(CASE WHEN eb.EventType = 'PURCHASE' AND eb.SalesOrderID IS NOT NULL THEN eb.EventTime END) AS FirstPurchaseAt
    FROM web.Session s
    LEFT JOIN EventBase eb
        ON eb.WebSessionID = s.WebSessionID
    GROUP BY
        s.WebSessionID,
        s.StartedAt
),
SessionLevel AS
(
    SELECT
        sf.WebSessionID,
        sf.AbVariant,
        sf.HasPurchase,
        CASE
            WHEN sf.HasPurchase = 1
                THEN DATEDIFF(SECOND, sf.StartedAt, sf.FirstPurchaseAt) / 60.0
            ELSE NULL
        END AS TimeToPurchaseMinutes
    FROM SessionFacts sf
    WHERE
        sf.DistinctVariantCount <= 1
        AND sf.AbVariant IS NOT NULL
)
SELECT
    sl.AbVariant,
    COUNT(*) AS [Sessions],
    SUM(sl.HasPurchase) AS SessionsWithPurchase, 
    CAST
    (
        SUM(sl.HasPurchase) * 100.0 
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(18, 2)
    ) AS ConversionRatePct,
    CAST(AVG(CAST(sl.TimeToPurchaseMinutes AS DECIMAL(18, 2))) AS DECIMAL(18, 2)) AS AvgTimeToPurchaseMinutes
FROM SessionLevel sl
GROUP BY
    sl.AbVariant