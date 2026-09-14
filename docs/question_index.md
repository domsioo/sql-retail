# Question index

This file maps each question to its SQL file and, where relevant, the reporting view it uses.

If “Source” is blank, the question is answered as a standalone query.

| Question | Title | File | Source |
| :---- | :---- | :---- | :---- |
| Q01 | Date spine with orders | `sql/20_questions/Q01_date_spine_with_orders.sql` | `reporting.v_kpi_daily` |
| Q02 | Daily revenue components | `sql/20_questions/Q02_daily_revenue_components.sql` | `reporting.v_kpi_daily` |
| Q03 | MTD and YTD net sales by day | `sql/20_questions/Q03_mtd_ytd_net_sales_by_day.sql` | `reporting.v_kpi_daily_mtd_ytd` |
| Q04 | Channel mix KPIs | `sql/20_questions/Q04_channel_mix_kpis.sql` | `reporting.v_kpi_channel_monthly` |
| Q05 | KPI single source of truth reconciliation | `sql/20_questions/Q05_kpi_single_source_of_truth_reconciliation.sql` | `reporting.v_audit_sales_header_vs_computed_monthly` |
| Q06 | Store leaderboard and contribution % | `sql/20_questions/Q06_store_leaderboard_contribution_pct.sql` |  |
| Q07 | Customer profile and primary email | `sql/20_questions/Q07_customer_profile_primary_email.sql` | `reporting.v_dim_customer_profile` |
| Q08 | New vs returning customers by month | `sql/20_questions/Q08_new_vs_returning_customers_monthly.sql` |  |
| Q09 | Customer lifetime value snapshot | `sql/20_questions/Q09_customer_lifetime_value_top_100.sql` |  |
| Q10 | Repeat rate by acquisition month, 60d window | `sql/20_questions/Q10_repeat_rate_by_acquisition_month_60d.sql` |  |
| Q11 | Cohort retention matrix, MonthIndex 0 to 6 | `sql/20_questions/Q11_cohort_retention_matrix_month_index_0_6.sql` |  |
| Q12 | Pareto customers 80/20 | `sql/20_questions/Q12_pareto_customers_80_20.sql` |  |
| Q13 | Top products by net sales | `sql/20_questions/Q13_top_products_by_net_sales.sql` |  |
| Q14 | Top product per month, ties allowed | `sql/20_questions/Q14_top_product_per_month_ties_allowed.sql` |  |
| Q15 | Category roll-up to root | `sql/20_questions/Q15_category_rollup_to_root.sql` | `reporting.v_dim_product_with_root_category` |
| Q16 | Price change impact, before vs after 30d | `sql/20_questions/Q16_price_change_impact_before_after_30d.sql` |  |
| Q17 | Price at time of sale correctness | `sql/20_questions/Q17_price_at_time_of_sale_correctness.sql` |  |
| Q18 | Orders that should have shipped but did not | `sql/20_questions/Q18_orders_should_have_shipped_but_did_not.sql` | `reporting.v_audit_missing_shipments_detail`, `reporting.v_audit_missing_shipments_summary` |
| Q19 | Delivery performance by carrier | `sql/20_questions/Q19_delivery_performance_by_carrier.sql` |  |
| Q20 | On-time delivery by customer region | `sql/20_questions/Q20_on_time_delivery_by_customer_region.sql` |  |
| Q21 | Return rate by root category, net after refunds | `sql/20_questions/Q21_return_rate_by_root_category_net_after_refunds.sql` | `reporting.v_dim_product_with_root_category` |
| Q22 | Refund turnaround time by reason | `sql/20_questions/Q22_refund_turnaround_time_by_reason.sql` |  |
| Q23 | Returns integrity and anomaly audit | `sql/20_questions/Q23_returns_integrity_anomaly_audit.sql` | `reporting.v_audit_return_anomaly_summary`, `reporting.v_audit_return_anomalies` |
| Q24 | A/B variant conversion | `sql/20_questions/Q24_ab_variant_conversion.sql` |  |
| Q25 | Funnel conversion by traffic source with bot exclusion | `sql/20_questions/Q25_funnel_conversion_by_traffic_source_bot_exclusion.sql` |  |

## Notes

- Questions 1 to 5, 7, 18, and 23 are intentionally backed by reporting views instead of repeating the logic in each file.  
- Questions 15 and 21 reuse the product to root-category mapping from the reporting layer.  
- For the exact metric rules used across the repo, see `docs/metric_definitions.md`.
