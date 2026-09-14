# Assumptions and caveats

This file lists the main project-level choices I made so the SQL stays consistent across the repo.

These are not meant to be universal business definitions. They are the rules used in this project.

## Sales and KPI assumptions

### Valid sale

For most KPI questions, a valid sale means:

- `sales.SalesOrder.OrderStatusCode = ‘DELIVERED’`

This is the default unless a question explicitly says otherwise.

### Reporting date

For KPI trends, the default reporting date is:

- `sales.SalesOrder.OrderDate`

I did not use shipment delivery date as the main sales date because the seed data includes shipment gaps and anomalies.

### Net sales

The main net sales definition used in the reporting layer is:

- `SUM(sales.SalesOrderLine.NetAmount) + SUM(sales.SalesOrder.ShippingAmount)`

### Header net vs computed net

- `sales.SalesOrder.HeaderNetAmount` is treated as a comparison / reconciliation figure  
- the computed line-based version is the main KPI version

### AOV

AOV is left as `NULL` when the denominator is zero.

I did not force it to `0.00` because zero orders means the value is undefined, not zero.

## Product and category assumptions

### Product/category net sales

Product and category questions use line-level net sales:

- `SUM(sales.SalesOrderLine.NetAmount)`

### Shipping treatment

Shipping is excluded from product/category rollups.

Reason:

- there is no shipping allocation rule to products in this project

### Root category mapping

Root-category rollups use:

- `reporting.v_dim_category_hierarchy`  
- `reporting.v_dim_product_with_root_category`

## Customer assumptions

### New vs returning

A customer is:

- new in the month of their first delivered order  
- returning in later months where they have delivered-order activity

### Acquisition month

Acquisition month is the month of the first delivered order.

### Repeat rate in Q10

For the 60-day repeat window:

- window start is inclusive  
- window end is exclusive  
- first order counts as one of the two orders  
- repeat means at least 2 delivered orders in the 60-day window

### Cohort retention in Q11

For the retention matrix:

- customer activity is reduced to 1 row per customer per month before retention is calculated  
- only observable MonthIndex values are returned  
- I did not pad incomplete trailing cohorts with fake future zeros

## Returns and refunds assumptions

### Returned quantity in Q21

Returned quantity includes only returns where:

- `sales.ReturnHeader.ReturnStatusCode IN (‘RECEIVED’, ‘REFUNDED’)`

`REQUESTED` returns are excluded.

### Refunded amount

Refunded amount includes only rows where:

- `sales.ReturnLine.RefundStatusCode = ‘REFUNDED’`  
- `sales.ReturnLine.RefundedAt IS NOT NULL`

### Net after refunds

For Q21:

- `NetSalesAfterRefunds = DeliveredNetSales - RefundedAmount`

## Shipping assumptions

### Missing shipments

A missing-shipment case means:

- `sales.SalesOrder.OrderStatusCode IN (‘SHIPPED’, ‘DELIVERED’)`  
- no matching `logistics.Shipment` row exists

### Carrier performance in Q19

- `AvgOrderToShipMinutes` uses all shipment rows  
- `AvgShipToDeliverMinutes` only uses rows where `DeliveredAt IS NOT NULL`  
- `LostShipmentRatePct` is based on shipment status

### On-time delivery in Q20

For Q20:

- shipment must have `ShipmentStatusCode = ‘DELIVERED’`  
- shipment must have `DeliveredAt IS NOT NULL`  
- customer region is matched as of order date using `crm.CustomerAttributeHistory`  
- SLA is defined as delivery within 3 days of ship timestamp

## Pricing assumptions

### Q16 price change impact

- price-change events are analyzed independently  
- if a product has multiple price changes close together, before/after windows can overlap  
- the same delivered sales can therefore contribute to more than one price-change event

### Q17 price at time of sale

- Q17 uses all order lines, not delivered-only  
- price history matching uses order date against effective date range  
- `EffectiveTo` is treated as inclusive  
- if multiple historical price rows match, the latest `EffectiveFrom` row is chosen

## Web analytics assumptions

### Q24 A/B conversion

- sessions with conflicting multiple A/B variants are excluded  
- purchase means `PURCHASE` event with `SalesOrderID IS NOT NULL`

### Q25 funnel

- funnel is a reached-step funnel  
- I did not enforce strict event order  
- a session counts in a step if it has at least one event of that type  
- purchase means `PURCHASE` event with `SalesOrderID IS NOT NULL`

### Q25 bot rule

Bot-like sessions are defined as:

- `SessionLengthSeconds <= 60`  
- and `TotalEventCount >= 150`

The seed data had a very obvious cluster of short, high-volume sessions, so I kept the rule simple.

## Seeded data caveats

This project uses synthetic data and some anomalies are intentional.

Examples:

- order header totals do not always exactly match recomputed line totals  
- some shipped/delivered orders have no shipment row  
- some customer email setups are messy, including multiple primaries  
- returns and refund states are not perfectly clean  
- web events include bot-like sessions

Those issues are there on purpose because several questions are about reconciliation, anomaly detection, and data quality.

## Final note

This repo is not trying to present one universal version of “correct” retail reporting logic.

It is trying to present:

- a consistent set of rules  
- documented assumptions  
- reusable reporting outputs  
- and SQL that is explicit about business definitions
