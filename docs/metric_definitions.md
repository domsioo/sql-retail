# Metric definitions

These are the default definitions used across the repo.

They are not meant to be universal business truths. They are just the rules I picked for this project so the answers stay consistent.

If a question intentionally uses a different rule, the SQL file says so in the header.

## 1\. Sales

### Valid sale

For sales KPIs, a valid sale is:

- `sales.SalesOrder.OrderStatusCode = ‘DELIVERED’`

This applies to the main KPI questions unless the question is clearly an audit or pricing check.

### Reporting date

For KPI trend questions, the reporting date is:

- `sales.SalesOrder.OrderDate`

This is the default date used in daily and monthly sales outputs.

### Net sales

Canonical net sales definition at order level:

- `SUM(sales.SalesOrderLine.NetAmount) + SUM(sales.SalesOrder.ShippingAmount)`

This is the main net sales definition used in the reporting layer.

### Header net vs computed net

- `sales.SalesOrder.HeaderNetAmount` is treated as a comparison value for reconciliation  
- It is not the main KPI definition  
- Reconciliation is in `reporting.v_audit_sales_header_vs_computed_monthly`

### Gross, discount, tax

These come from `sales.SalesOrderLine`, aggregated to order level first to avoid shipping duplication:

- `GrossSales = SUM(GrossAmount)`  
- `DiscountTotal = SUM(DiscountAmount)`  
- `TaxTotal = SUM(TaxAmount)`

### AOV

- `AOV = NetSales / DeliveredOrders`  
- In reporting views, AOV is `NULL` when DeliveredOrders \= 0

I kept it as `NULL` on purpose. Zero orders does not mean zero average order value. It means the value is undefined.

## 2\. Store and channel reporting

### Channel

Channel comes from:

- `sales.SalesOrder.ChannelCode`  
- `ref.Channel`

### Store leaderboard

Store leaderboard only covers physical store orders:

- `sales.SalesOrder.ChannelCode = ‘STORE’`

### Top 20 percent contribution set in Q06

For Q06, “top 20%” means:

- the smallest cumulative set of stores, ordered by NetSales DESC then StoreID ASC,  
- whose combined net sales reaches or exceeds 20 percent of total store net sales

It does not mean “top 20 percent of stores by count”.

## 3\. Customer definitions

### New vs returning

For monthly customer questions:

- a customer is “new” in the month of their first delivered order  
- a customer is “returning” in later months where they have delivered-order activity

### Customer monthly activity

A customer counts once per month if they had at least one delivered order in that month.

This is reduced to one row per `CustomerID + MonthBucket` before further cohort or retention logic.

### Acquisition month

Acquisition month is:

- the month of the customer’s first delivered order

### Repeat within 60 days

For Q10:

- the 60-day window starts at the first delivered order timestamp  
- the window end is exclusive: `< DATEADD(DAY, 60, FirstDeliveredOrderDate)`  
- a customer counts as repeated if they have at least 2 delivered orders in that window  
- the first delivered order itself counts as one of the two

### Cohort retention

For Q11:

- `CohortMonth` \= first delivered-order month  
- `ActivityMonth` \= month where the customer had at least one delivered order  
- `MonthIndex = DATEDIFF(MONTH, CohortMonth, ActivityMonth)`

Only observable month indexes are returned. I did not manufacture future zeros for incomplete trailing cohorts.

## 4\. Product and category definitions

### Product and category sales

For product and category questions:

- sales use `sales.SalesOrderLine.NetAmount`  
- quantities use `sales.SalesOrderLine.Quantity`

### Shipping in product/category reporting

Shipping is excluded from product and category rollups.

Reason:

- there is no allocation rule in this project for splitting shipping across products

### Root category

Root category mapping comes from:

- `reporting.v_dim_category_hierarchy`  
- `reporting.v_dim_product_with_root_category`

This is the standard source for category rollups.

## 5\. Returns and refunds

### Returned quantity

For Q21, returned quantity includes only returns where:

- `sales.ReturnHeader.ReturnStatusCode IN (‘RECEIVED’, ‘REFUNDED’)`

`REQUESTED` returns are excluded from returned quantity.

### Refunded amount

Refunded amount includes only:

- `sales.ReturnLine.RefundStatusCode = ‘REFUNDED’`  
- `sales.ReturnLine.RefundedAt IS NOT NULL`

### Net sales after refunds

For category-level refund analysis:

- `NetSalesAfterRefunds = DeliveredNetSales - RefundedAmount`

### Return anomaly layer

Return anomalies are built from:

- `reporting.v_audit_return_base`  
- `reporting.v_audit_return_anomalies`  
- `reporting.v_audit_return_anomaly_summary`

## 6\. Shipping and delivery

### Missing shipment

An order is considered a missing-shipment case when:

- `sales.SalesOrder.OrderStatusCode IN (‘SHIPPED’, ‘DELIVERED’)`  
- and no matching row exists in `logistics.Shipment`

### Carrier performance

For Q19:

- `AvgOrderToShipMinutes` uses all shipment rows  
- `AvgShipToDeliverMinutes` uses only rows where `DeliveredAt IS NOT NULL`  
- `LostShipmentRatePct = LostShipments / TotalShipments * 100`

### On-time delivery by region

For Q20:

- included shipments:  
  - `logistics.Shipment.ShipmentStatusCode = ‘DELIVERED’`  
  - and `DeliveredAt IS NOT NULL`  
- historical customer region is matched as of `CAST(sales.SalesOrder.OrderDate AS DATE)`  
- SLA rule:  
  - on-time \= `DeliveredAt <= DATEADD(DAY, 3, ShippedAt)`

## 7\. Pricing

### Q16 price change impact

- valid sale \= delivered orders only  
- 30-day before and after windows  
- average selling price is weighted:  
  - `SUM(UnitPrice * Quantity) / SUM(Quantity)`

Important caveat:

- each price-change event is analyzed independently  
- if the same product has multiple price changes close together, windows can overlap

### Q17 price at time of sale

- scope \= all order lines, not delivered-only  
- effective-date matching uses:  
  - `OrderDate >= EffectiveFrom`  
  - and `OrderDate <= EffectiveTo` when `EffectiveTo` exists  
- if multiple price rows match, use the one with the latest `EffectiveFrom`

## 8\. Web analytics

### Q24 A/B conversion

Purchase definition:

- session has at least one `PURCHASE` event with `SalesOrderID IS NOT NULL`

Sessions with conflicting A/B variants across events are excluded.

### Q25 funnel

Funnel is a reached-step funnel, not a strict sequential funnel.

A session is counted in a step if it has at least one event of that type:

- `PAGEVIEW`  
- `ADD_TO_CART`  
- `CHECKOUT`  
- `PURCHASE` with `SalesOrderID IS NOT NULL`

### Bot rule for Q25

A session is flagged as bot-like when:

- `SessionLengthSeconds <= 60`  
- and `TotalEventCount >= 150`

Q25 returns results both:

- with all sessions  
- and with bot-like sessions excluded
