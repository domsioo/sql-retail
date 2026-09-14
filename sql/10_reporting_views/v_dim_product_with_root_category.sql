/* reporting.v_dim_product_with_root_category - Product dimension with leaf and root category mapping

Definitions
- Reporting grain = 1 row per ProductID
- Base entity = ref.Product
- Leaf category comes from ref.Product.CategoryID joined to reporting.v_dim_category_hierarchy.CategoryID
- Root category comes from reporting.v_dim_category_hierarchy.RootCategoryID / RootCategoryName
- INNER JOIN is used because product-to-category mapping is required in this model

Output columns
- ProductID
- SKU
- ProductName
- Brand
- IsActive
- CreatedAt
- LeafCategoryID
- LeafCategoryName
- RootCategoryID
- RootCategoryName
- CategoryDepth
- CategoryPathName
*/

CREATE OR ALTER VIEW [reporting].[v_dim_product_with_root_category] 
AS
SELECT 
	p.ProductID,
	p.SKU,
	p.ProductName,
	p.Brand,
	p.IsActive,
	p.CreatedAt,

	ch.CategoryID AS LeafCategoryID,
	ch.CategoryName AS LeafCategoryName,
	ch.RootCategoryID,
	ch.RootCategoryName,
	ch.CategoryDepth,
	ch.CategoryPathName
FROM ref.[Product] p
JOIN reporting.v_dim_category_hierarchy ch
	ON ch.CategoryID = p.CategoryID
GO