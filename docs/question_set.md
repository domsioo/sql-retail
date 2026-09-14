# Question set

These are the prompts I used to structure the project.

Some ended up as standalone query files.  
Some are answered through reusable reporting views, because once the logic was standardized it made no sense to rewrite it in every file.

Answers are available in `sql/20_questions/`.  
The file-to-question mapping is in `docs/question_index.md`.

## General rules

For each query:

- state which orders count  
- state which date is used  
- define revenue clearly  
- define the output grain  
- make the output safe for BI use  
- avoid accidental double counting  
- handle nulls and divide-by-zero cases explicitly

## Group 1: KPI foundations

### Q01. Date spine with orders

**What it checks**  
Date spines, zero-activity reporting, and clean counting.

**Task**  
Using `util.CalendarDate`, return one row per date in a chosen range with:

- Date  
- Total orders count  
- Delivered orders count

Dates with zero orders must still appear.

---

### Q02. Daily revenue components

**What it checks**  
Basic KPI definition and daily revenue reporting.

**Task**  
Return one row per date with:

- Gross sales  
- Discount total  
- Tax total  
- Shipping total  
- Net sales

Use delivered orders only. Include dates with zero activity.

---

### Q03. MTD and YTD net sales by day

**What it checks**  
Running totals and time-intelligence logic.

**Task**  
Return one row per date with:

- Net sales for that date  
- MTD net sales  
- YTD net sales

Use the same net sales definition as in Q02.

---

### Q04. Channel mix KPIs

**What it checks**  
Dimensional breakdowns and AOV logic.

**Task**  
Return one row per `ref.Channel.ChannelCode` with:

- Delivered orders  
- Net sales  
- AOV

Use delivered orders only.

---

### Q05. KPI single source of truth reconciliation

**What it checks**  
Reconciliation between competing metric sources.

**Task**  
Produce a dataset showing:

- total net sales from `sales.SalesOrder` header totals  
- total net sales from `sales.SalesOrderLine` totals, plus shipping if included  
- difference in amount  
- difference in percent

Do this both overall and by month.

---

### Q06. Store leaderboard and contribution %

**What it checks**  
Ranking, percent-of-total logic, and business-style segmentation.

**Task**  
Return one row per store (`ops.Store`) with:

- Net sales  
- percent contribution to total net sales  
- rank by net sales  
- a flag or bucket identifying the top 20 percent contribution set

Use delivered orders only.

## Group 2: Customer analytics

### Q07. Customer profile with primary email

**What it checks**  
Deterministic record selection and customer-profile outputs.

**Task**  
Return one row per customer from `crm.Customer` with:

- CustomerNK and full name  
- Primary email  
- Verified flag for the chosen email  
- CreatedAt  
- IsActive  
- A flag for:  
  - no primary email  
  - exactly one primary email  
  - multiple primary emails

---

### Q08. New vs returning customers by month

**What it checks**  
First-purchase logic and monthly customer classification.

**Task**  
Return one row per month with:

- New customers whose first delivered order occurs in that month  
- Returning customers who ordered in that month but had their first delivered order earlier

---

### Q09. Customer lifetime value snapshot

**What it checks**  
Customer value analysis, first/last order dates, and order counts.

**Task**  
Return the top 100 customers by net sales with:

- First delivered order date  
- Last delivered order date  
- Delivered orders count  
- Total net sales  
- AOV

Use delivered orders only.

---

### Q10. Repeat rate by acquisition month, 60-day window

**What it checks**  
Cohort acquisition logic and short-term repeat behavior.

**Task**  
Define acquisition month as the month of first delivered order.  
For each acquisition month, return:

- Cohort size  
- Percent of customers with at least 2 delivered orders within 60 days of the first delivered order

---

### Q11. Cohort retention matrix, MonthIndex 0 to 6

**What it checks**  
Retention logic in a format a BI tool can pivot.

**Task**  
Return a long-format table with:

- CohortMonth, based on first delivered order month  
- MonthIndex from 0 to 6  
- ActiveCustomers, meaning customers from that cohort who had a delivered order in that month index

---

### Q12. Pareto customers 80/20

**What it checks**  
Cumulative contribution analysis with window functions.

**Task**  
Identify the smallest set of customers contributing to 80 percent of net sales.  
Return per customer:

- Net sales  
- Cumulative net sales  
- Cumulative percent  
- A flag showing whether the customer is inside the 80 percent set

## Group 3: Product and category performance

### Q13. Top products by net sales

**What it checks**  
Product ranking and product-level reporting.

**Task**  
Return the top 20 products, delivered only, with:

- SKU  
- ProductName  
- Quantity sold  
- Net sales  
- Rank

---

### Q14. Top product per month

**What it checks**  
Top-per-group logic, including ties.

**Task**  
For each month, return the product or products with the highest net sales.  
If multiple products tie, return all of them.

---

### Q15. Category roll-up to root

**What it checks**  
Hierarchy rollups from child categories to top-level categories.

**Task**  
For each root category, return:

- Net sales  
- Quantity sold  
- Percent contribution to total net sales

Subcategories must roll up correctly to the root.

---

### Q16. Price change impact

**What it checks**  
Before/after analysis against effective-dated price history.

**Task**  
For products with list price changes in `ref.ProductListPriceHistory`, compute for each change:

- Average unit price before vs after  
- Quantity sold before vs after  
- Net sales before vs after  
- Deltas for price, quantity, and net sales

Use either a 30-day or 60-day window and state which one you chose.

Return the top 20 biggest changes by absolute net sales delta.

---

### Q17. Price at time of sale correctness

**What it checks**  
Effective-dated joins and pricing audits.

**Task**  
For each order line, determine the list price valid on the order date and return:

- OrderNumber  
- OrderDate  
- SKU  
- UnitPrice used  
- ListPrice valid at time of sale  
- Difference

Then produce an aggregate result with:

- Percent of lines where `ABS(Difference) > 0.01`

## Group 4: Operations, shipping, returns, reliability

### Q18. Orders that should have shipped but did not

**What it checks**  
Completeness checks with missing child records.

**Task**  
Find orders with status `SHIPPED` or `DELIVERED` that have no row in `logistics.Shipment`.  
Return:

- OrderNumber  
- OrderStatusCode  
- OrderDate  
- ChannelCode  
- CustomerID

---

### Q19. Delivery performance by carrier

**What it checks**  
Operational KPI design and time interval calculations.

**Task**  
For each carrier, compute:

- Average time from OrderDate to ShippedAt  
- Average time from ShippedAt to DeliveredAt  
- Lost shipment rate based on shipment status

Include shipment counts and state how null `DeliveredAt` values are handled.

---

### Q20. On-time delivery by customer region

**What it checks**  
Effective-dated customer attributes and SLA reporting.

**Task**  
Join customer region as-of the order date using `crm.CustomerAttributeHistory`.  
Define an SLA, for example delivered within X days of ship, and return one row per region with:

- On-time delivery rate  
- Average ship-to-deliver time

Only include shipments you consider delivered, and state the rule.

---

### Q21. Return rate by root category plus net after refunds

**What it checks**  
Combining sales, returns, and hierarchy logic in one output.

**Task**  
For each root category, compute:

- Delivered quantity  
- Returned quantity  
- Return rate  
- Net sales after refunds using `sales.ReturnLine.RefundAmount`

State the refund logic you use.

---

### Q22. Refund turnaround time by return reason

**What it checks**  
Lifecycle timing and median calculation.

**Task**  
For refunded return lines, compute:

- Average days from return created to refunded  
- Median days from return created to refunded

Break the result down by return reason. State how missing refunded timestamps are handled.

---

### Q23. Returns integrity and anomaly report

**What it checks**  
Detection of inconsistent states and data-quality issues.

**Task**  
Produce a dataset that surfaces and summarizes anomalies such as:

- return marked refunded but missing refunded return lines  
- return line marked refunded but missing refunded timestamp  
- returned quantity greater than originally sold quantity

Return counts by anomaly type and provide example records for each anomaly type.

## Group 5: Web and event analytics

### Q24. A/B variant conversion

**What it checks**  
Session-level conversion analysis and semi-structured event fields.

**Task**  
Compute per A/B variant:

- Sessions  
- Sessions with purchase  
- Conversion rate  
- Average time to purchase in minutes

Define exactly how a session with purchase is identified.

---

### Q25. Funnel conversion by traffic source with bot exclusion

**What it checks**  
Funnel logic, segmentation, and practical filtering of bad session data.

**Task**  
For each traffic source, build a funnel:

- PAGEVIEW  
- ADD\_TO\_CART  
- CHECKOUT  
- PURCHASE

Return:

- Sessions reaching each step  
- Step conversion rates:  
  - 1 to 2  
  - 2 to 3  
  - 3 to 4  
  - 1 to 4

Define a bot-like session rule and show the results both with and without excluding those sessions.  
