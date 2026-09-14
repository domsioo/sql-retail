# Schema overview

This project uses a small retail-style database with orders, returns, shipments, customer history, product hierarchy, price history, and web events.

The database is split into schemas by domain.

## Schemas

### util

Utility tables used in reporting.

- `util.CalendarDate`  
  - Date spine used for daily and monthly reporting

### ref

Reference and master data.

- `ref.Channel`  
- `ref.OrderStatus`  
- `ref.ShipmentStatus`  
- `ref.Carrier`  
- `ref.ReturnReason`  
- `ref.Category`  
- `ref.Product`  
- `ref.ProductListPriceHistory`

### crm

Customer and customer-history data.

- `crm.Customer`  
- `crm.CustomerEmail`  
- `crm.CustomerAttributeHistory`

### ops

Store-related operational data.

- `ops.Store`

### sales

Commercial transaction data.

- `sales.SalesOrder`  
- `sales.SalesOrderLine`  
- `sales.ReturnHeader`  
- `sales.ReturnLine`

### logistics

Shipment and delivery data.

- `logistics.Shipment`

### web

Session and event data for digital analytics.

- `web.Session`  
- `web.Event`

### reporting

Reusable views built on top of the base tables.

Examples:

- KPI views  
- audit/reconciliation views  
- customer profile view  
- category hierarchy view  
- product to root-category mapping view

## Main table grains

These are the important ones to keep straight.

- `sales.SalesOrder`  
    
  - 1 row per order


- `sales.SalesOrderLine`  
    
  - 1 row per order line


- `logistics.Shipment`  
    
  - 1 row per shipment


- `sales.ReturnHeader`  
    
  - 1 row per return


- `sales.ReturnLine`  
    
  - 1 row per return line


- `crm.Customer`  
    
  - 1 row per customer


- `crm.CustomerEmail`  
    
  - 1 row per customer email


- `crm.CustomerAttributeHistory`  
    
  - 1 row per customer effective period


- `ref.Product`  
    
  - 1 row per product


- `ref.ProductListPriceHistory`  
    
  - 1 row per product effective period


- `web.Session`  
    
  - 1 row per session


- `web.Event`  
    
  - 1 row per event

## Main join paths

These are the join paths used most often in the question set.

### Sales and product analysis

- `sales.SalesOrder`  
- `sales.SalesOrderLine`  
- `ref.Product`  
- `ref.Category`  
- `reporting.v_dim_category_hierarchy`  
- `reporting.v_dim_product_with_root_category`

### Customer analysis

- `sales.SalesOrder`  
- `crm.Customer`  
- `crm.CustomerEmail`  
- `crm.CustomerAttributeHistory`

### Shipping analysis

- `sales.SalesOrder`  
- `logistics.Shipment`  
- `ref.Carrier`

### Returns analysis

- `sales.ReturnHeader`  
- `sales.ReturnLine`  
- `sales.SalesOrderLine`  
- `sales.SalesOrder`

### Web / funnel analysis

- `web.Session`  
- `web.Event`

## Reporting layer

The reporting schema is used as a reusable semantic layer so the same business logic is not rewritten in every question file.

Main reporting views:

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
