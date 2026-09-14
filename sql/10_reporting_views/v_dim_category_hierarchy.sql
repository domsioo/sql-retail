/* reporting.v_dim_category_hierarchy - Category hierarchy flattened to root category

Definitions
- Reporting grain = 1 row per CategoryID
- Built with a recursive CTE starting from root categories (ParentCategoryID IS NULL)
- RootCategoryID / RootCategoryName are carried down the hierarchy to every descendant
- CategoryDepth = 0 for roots, 1 for children, 2 for grandchildren, etc.
- CategoryPathName = breadcrumb path from root to category
- PathID is used internally for cycle prevention and is not exposed in the final view

Output columns
- CategoryID
- CategoryName
- ParentCategoryID
- IsActive
- CategoryDepth
- RootCategoryID
- RootCategoryName
- CategoryPathName
*/

CREATE OR ALTER VIEW [reporting].[v_dim_category_hierarchy] 
AS
WITH CategoryHierarchy AS 
(
	SELECT
		c.CategoryID,
		c.CategoryName,
		c.ParentCategoryID,
		c.IsActive,
		0 AS CategoryDepth,
		c.CategoryID AS RootCategoryID,
		c.CategoryName AS RootCategoryName,
		CAST(c.CategoryName AS VARCHAR(MAX)) AS CategoryPathName,

		-- Cycle Prevention
		CAST('/' + CAST(c.CategoryID AS VARCHAR(20)) + '/' AS VARCHAR(MAX)) As PathID
	FROM ref.Category c
	WHERE c.ParentCategoryID IS NULL

	UNION ALL

	SELECT
		c.CategoryID,
		c.CategoryName,
		c.ParentCategoryID,
		c.IsActive,
		ch.CategoryDepth + 1 AS CategoryDepth,
		ch.RootCategoryID,
		ch.RootCategoryName,
		CAST(ch.CategoryPathName + ' > ' + c.CategoryName AS VARCHAR(MAX)) AS CategoryPathName,

		CAST(ch.PathID + CAST(c.CategoryID AS VARCHAR(20)) + '/' AS VARCHAR(MAX)) AS PathID
	FROM ref.Category c
	JOIN CategoryHierarchy ch
		ON ch.CategoryID = c.ParentCategoryID
	WHERE
		ch.PathID NOT LIKE '%/' + CAST(c.CategoryID AS VARCHAR(20)) + '/%'
)
SELECT
	CategoryID,
	CategoryName,
	ParentCategoryID,
	IsActive,
	CategoryDepth,
	RootCategoryID,
	RootCategoryName,
	CategoryPathName
FROM 
	CategoryHierarchy;
GO