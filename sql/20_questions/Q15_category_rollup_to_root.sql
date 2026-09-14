/* Q15 - Category roll-up to root category

Definitions
- Valid sale = OrderStatusCode = 'DELIVERED'
- Reporting grain = 1 row per root category
- Product-to-root mapping is provided by reporting.v_dim_product_with_root_category
- RootCategoryNetSales = SUM(sales.SalesOrderLine.NetAmount) rolled up from products to root category
- RootCategoryQuantitySold = SUM(sales.SalesOrderLine.Quantity) rolled up from products to root category
- TotalSalesContributionPct = root category net sales / total delivered product net sales * 100
- Shipping is excluded because no shipping allocation rule is applied to products
- Output is driven from the product dimension so root categories with zero sales still appear if present

Output columns
- RootCategoryID
- RootCategoryName
- RootCategoryNetSales
- RootCategoryQuantitySold
- TotalSalesContributionPct
*/

WITH ProductSalesAgg AS
(
    SELECT
        sol.ProductID,
        SUM(sol.NetAmount) AS ProductNetSales,
        SUM(sol.Quantity) AS TotalSoldQuantity
    FROM sales.SalesOrder so
    JOIN sales.SalesOrderLine sol
        ON sol.SalesOrderID = so.SalesOrderID
    WHERE
        so.OrderStatusCode = 'DELIVERED'
    GROUP BY
        sol.ProductID
)
SELECT
    pdim.RootCategoryID,
    pdim.RootCategoryName,
    COALESCE(SUM(psa.ProductNetSales), 0.00) AS RootCategoryNetSales,
    COALESCE(SUM(psa.TotalSoldQuantity), 0) AS RootCategoryQuantitySold,
    CAST
    (
        COALESCE(SUM(psa.ProductNetSales), 0.00) * 100.0
        / NULLIF(SUM(COALESCE(SUM(psa.ProductNetSales), 0.00)) OVER (), 0.00)
        AS DECIMAL(18, 4)
    ) AS TotalSalesContributionPct
FROM reporting.v_dim_product_with_root_category pdim
LEFT JOIN ProductSalesAgg psa
    ON psa.ProductID = pdim.ProductID
GROUP BY
    pdim.RootCategoryID,
    pdim.RootCategoryName
ORDER BY
    RootCategoryNetSales DESC,
    RootCategoryQuantitySold DESC;