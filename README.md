# PortfolioRetailLab

This repo is a SQL Server portfolio project built around a retail-style dataset.

It started as a practice database, but I pushed it further and built a small reporting layer on top of it before answering the question set.

The point of the project was to practice BI / DA work that is closer to real use than random SQL snippets:

- KPI definitions  
- date spines  
- reconciliations  
- customer cohorts  
- product hierarchy rollups  
- returns and refund audits  
- shipping quality checks  
- web funnel and A/B event analysis

## Stack

- SQL Server  
- T-SQL  
- SSMS

## What is in the repo

### 1\. Source-style tables

The database includes:

- orders and order lines  
- returns and refunds  
- shipments  
- customers and customer attribute history  
- products, categories, and price history  
- web sessions and web events

### 2\. Reporting layer

The `reporting` schema contains reusable views for:

- daily KPI outputs  
- monthly channel KPIs  
- sales reconciliation  
- missing shipment audits  
- return anomaly reporting  
- customer profile selection  
- category hierarchy flattening  
- product-to-root category mapping

### 3\. Question set

There are 25 SQL questions in `sql/20_questions/`.

Some of them are answered directly as standalone queries.  
Some of them intentionally reuse reporting views instead of repeating the same logic in every file.

That was a deliberate choice. If I had already standardized the logic in a reporting view, I used that instead of copy-pasting it into the question file.

## Folder layout

sql/

  00\_setup/

  10\_reporting\_views/

  20\_questions/

docs/

  metric\_definitions.md

  question\_index.md

  question\_set.md

  schema\_overview.md

  assumptions\_and\_caveats.md

## How to run it

Suggested order:

1. Run the setup scripts in `sql/00_setup/`  
2. Run the reporting view scripts in `sql/10_reporting_views/`  
3. Run any question file from `sql/20_questions/`

The question files are numbered `Q01` to `Q25`.

## Main reporting views

### KPI views

- `reporting.v_kpi_daily`  
- `reporting.v_kpi_daily_mtd_ytd`  
- `reporting.v_kpi_channel_monthly`

### Audit views

- `reporting.v_audit_sales_header_vs_computed_monthly`  
- `reporting.v_audit_missing_shipments_detail`  
- `reporting.v_audit_missing_shipments_summary`  
- `reporting.v_audit_return_base`  
- `reporting.v_audit_return_anomalies`  
- `reporting.v_audit_return_anomaly_catalog`  
- `reporting.v_audit_return_anomaly_summary`

### Dimension-style views

- `reporting.v_dim_customer_profile`  
- `reporting.v_dim_category_hierarchy`  
- `reporting.v_dim_product_with_root_category`

## Conventions used in the project

The default metric rules are in `docs/metric_definitions.md`.

A few important ones:

- sales KPIs use `OrderStatusCode = ‘DELIVERED’`  
- the main KPI date is `sales.SalesOrder.OrderDate`  
- order-level net sales \= line net sales \+ shipping  
- product/category analysis excludes shipping  
- some questions intentionally use a different scope and say so in the SQL header

## Where to start if you are skimming

If you only want to look at a few files, these are probably the best entry points:

- `sql/10_reporting_views/v_kpi_daily.sql`  
- `sql/10_reporting_views/v_audit_sales_header_vs_computed_monthly.sql`  
- `sql/10_reporting_views/v_audit_return_anomalies.sql`  
- `sql/20_questions/Q11_cohort_retention_matrix_month_index_0_6.sql`  
- `sql/20_questions/Q17_price_at_time_of_sale_correctness.sql`  
- `sql/20_questions/Q25_funnel_conversion_by_traffic_source_bot_exclusion.sql`

## Notes

A few things are intentional:

- Some question files are thin wrappers over reporting views  
- AOV is left as `NULL` when the denominator is zero  
- Return anomalies are stored as a normalized anomaly log and then summarized from there  
- Category hierarchy is flattened once and reused rather than rebuilt in every query

## Question list

See `docs/question_index.md` and `docs/question_set.md`.  
