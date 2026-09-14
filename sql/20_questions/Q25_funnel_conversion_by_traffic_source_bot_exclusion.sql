/* Q25 - Funnel conversion by traffic source + bot exclusion comparison

Definitions
- Reporting grain = 1 row per BotFilterMode + TrafficSource
- Funnel is evaluated at session grain (1 row per WebSessionID before final aggregation)
- Funnel interpretation = reached-step funnel, not strict sequential order
- HasPageview = session has at least one PAGEVIEW event
- HasAddToCart = session has at least one ADD_TO_CART event
- HasCheckout = session has at least one CHECKOUT event
- HasPurchase = session has at least one PURCHASE event where SalesOrderID IS NOT NULL
- SessionLengthSeconds = DATEDIFF(SECOND, web.Session.StartedAt, web.Session.EndedAt)
- TotalEventCount = total count of web.Event rows in the session

Bot rule
- IsBotLike = 1 when:
    SessionLengthSeconds <= 60
    AND TotalEventCount >= 150

Bot filter modes
- ALL_SESSIONS = all sessions included
- EXCLUDE_BOTS = only sessions where IsBotLike = 0

Conversion metrics
- PageviewSessions = SUM(HasPageview)
- AddToCartSessions = SUM(HasAddToCart)
- CheckoutSessions = SUM(HasCheckout)
- PurchaseSessions = SUM(HasPurchase)
- PageviewToCartConversionPct = AddToCartSessions / PageviewSessions * 100
- CartToCheckoutConversionPct = CheckoutSessions / AddToCartSessions * 100
- CheckoutToPurchaseConversionPct = PurchaseSessions / CheckoutSessions * 100
- PageviewToPurchaseConversionPct = PurchaseSessions / PageviewSessions * 100

Output columns
- BotFilterMode
- TrafficSource
- PageviewSessions
- AddToCartSessions
- CheckoutSessions
- PurchaseSessions
- PageviewToCartConversionPct
- CartToCheckoutConversionPct
- CheckoutToPurchaseConversionPct
- PageviewToPurchaseConversionPct
*/

;WITH EventsAgg AS
(
    SELECT
        e.WebSessionID,
        COUNT(*) AS TotalEventCount,
        SUM(CASE WHEN e.EventType = 'PAGEVIEW' THEN 1 ELSE 0 END) AS PageviewEventCount,
        SUM(CASE WHEN e.EventType = 'ADD_TO_CART' THEN 1 ELSE 0 END) AS CartEventCount,
        SUM(CASE WHEN e.EventType = 'CHECKOUT' THEN 1 ELSE 0 END) AS CheckoutEventCount,
        SUM(CASE WHEN e.EventType = 'PURCHASE' AND e.SalesOrderID IS NOT NULL THEN 1 ELSE 0 END) AS PurchaseEventCount
    FROM web.[Event] e
    GROUP BY
        e.WebSessionID
),
EventsWithFlag AS
(
    SELECT
        ea.WebSessionID,
        ea.TotalEventCount,
        ea.PageviewEventCount,
        ea.CartEventCount,
        ea.CheckoutEventCount,
        ea.PurchaseEventCount,
        CASE WHEN ea.PageviewEventCount >= 1 THEN 1 ELSE 0 END AS HasPageview,
        CASE WHEN ea.CartEventCount >= 1 THEN 1 ELSE 0 END AS HasAddToCart,
        CASE WHEN ea.CheckoutEventCount >= 1 THEN 1 ELSE 0 END AS HasCheckout,
        CASE WHEN ea.PurchaseEventCount >= 1 THEN 1 ELSE 0 END AS HasPurchase
    FROM EventsAgg ea
),
SessionLevelOverview AS
(
    SELECT
        s.WebSessionID,
        s.TrafficSource,
        DATEDIFF(SECOND, s.StartedAt, s.EndedAt) AS SessionLengthSeconds,
        COALESCE(ewf.TotalEventCount, 0) AS TotalEventCount,
        COALESCE(ewf.PageviewEventCount, 0) AS PageviewEventCount,
        COALESCE(ewf.CartEventCount, 0) AS CartEventCount,
        COALESCE(ewf.CheckoutEventCount, 0) AS CheckoutEventCount,
        COALESCE(ewf.PurchaseEventCount, 0) AS PurchaseEventCount,
        COALESCE(ewf.HasPageview, 0) AS HasPageview,
        COALESCE(ewf.HasAddToCart, 0) AS HasAddToCart,
        COALESCE(ewf.HasCheckout, 0) AS HasCheckout,
        COALESCE(ewf.HasPurchase, 0) AS HasPurchase,
        CASE
            WHEN DATEDIFF(SECOND, s.StartedAt, s.EndedAt) <= 60
            AND COALESCE(ewf.TotalEventCount, 0) >= 150
                THEN 1
            ELSE 0
        END AS IsBotLike
    FROM web.[Session] s
    LEFT JOIN EventsWithFlag ewf
        ON ewf.WebSessionID = s.WebSessionID
),
BotFilterModes AS
(
    SELECT 'ALL_SESSIONS' AS BotFilterMode, 0 AS ExcludeBots
    UNION ALL
    SELECT 'EXCLUDE_BOTS' AS BotFilterMode, 1 AS ExcludeBots
),
SessionByMode AS
(
    SELECT
        bfm.BotFilterMode,
        slo.WebSessionID,
        slo.TrafficSource,
        slo.HasPageview,
        slo.HasAddToCart,
        slo.HasCheckout,
        slo.HasPurchase
    FROM SessionLevelOverview slo
    CROSS JOIN BotFilterModes bfm
    WHERE
        bfm.ExcludeBots = 0
        OR slo.IsBotLike = 0
)
SELECT
    sbm.BotFilterMode,
    sbm.TrafficSource,
    SUM(sbm.HasPageview) AS PageviewSessions,
    SUM(sbm.HasAddToCart) AS AddToCartSessions,
    SUM(sbm.HasCheckout) AS CheckoutSessions,
    SUM(sbm.HasPurchase) AS PurchaseSessions,
    CAST(SUM(sbm.HasAddToCart) * 100.0 / NULLIF(SUM(sbm.HasPageview), 0) AS DECIMAL(18, 2)) AS PageviewToCartConversionPct,
    CAST(SUM(sbm.HasCheckout) * 100.0 / NULLIF(SUM(sbm.HasAddToCart), 0) AS DECIMAL(18, 2)) AS CartToCheckoutConversionPct,
    CAST(SUM(sbm.HasPurchase) * 100.0 / NULLIF(SUM(sbm.HasCheckout), 0) AS DECIMAL(18, 2)) AS CheckoutToPurchaseConversionPct,
    CAST(SUM(sbm.HasPurchase) * 100.0 / NULLIF(SUM(sbm.HasPageview), 0) AS DECIMAL(18, 2)) AS PageviewToPurchaseConversionPct
FROM SessionByMode sbm
GROUP BY
    sbm.BotFilterMode,
    sbm.TrafficSource
ORDER BY
    sbm.BotFilterMode,
    sbm.TrafficSource;