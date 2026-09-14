/* reporting.v_dim_customer_profile - Customer profile dimension with deterministic selected email

Definitions
- Reporting grain = 1 row per customer
- Base entity = crm.Customer
- EmailCount = total number of crm.CustomerEmail rows for the customer
- PrimaryEmailCount = number of emails where IsPrimary = 1
- VerifiedEmailCount = number of emails where IsVerified = 1
- HasMultiplePrimaryEmails = 1 when PrimaryEmailCount > 1
- HasNoPrimaryEmail = 1 when PrimaryEmailCount = 0
- HasNoEmail = 1 when EmailCount = 0
- Selected email is chosen deterministically using this priority:
    1) IsPrimary = 1 AND IsVerified = 1
    2) IsVerified = 1
    3) IsPrimary = 1
    4) any remaining email
- Tie-breakers:
    VerifiedAt DESC,
    CreatedAt DESC,
    CustomerEmailID DESC
- OUTER APPLY is used so customers with no email are still returned

Output columns
- CustomerID
- CustomerNK
- FullName
- CustomerCreatedAt
- IsActive
- EmailCount
- PrimaryEmailCount
- VerifiedEmailCount
- HasMultiplePrimaryEmails
- HasNoPrimaryEmail
- HasNoEmail
- SelectedEmailAddress
- SelectedEmailID
- SelectedEmailIsPrimary
- SelectedEmailIsVerified
- SelectedEmailVerifiedAt
- SelectedEmailCreatedAt
- EmailBucketRule
*/

CREATE OR ALTER VIEW [reporting].[v_dim_customer_profile] AS
WITH EmailAgg AS 
(
	SELECT
		c.CustomerID,
		COUNT(ce.CustomerEmailID) AS EmailCount,
		SUM(CASE WHEN ce.IsPrimary = 1 THEN 1 ELSE 0 END) AS PrimaryEmailCount,
		SUM(CASE WHEN ce.IsVerified = 1 THEN 1 ELSE 0 END) AS VerifiedEmailCount
	FROM crm.Customer c
	LEFT JOIN crm.CustomerEmail ce
		ON c.CustomerID = ce.CustomerID
	GROUP BY
		c.CustomerID
)
SELECT
	c.CustomerID,
	c.CustomerNK,
	CONCAT(c.FirstName, ' ', c.LastName) AS FullName,
	c.CreatedAt AS CustomerCreatedAt,
	c.IsActive,

	COALESCE(ea.EmailCount, 0) AS EmailCount,
	COALESCE(ea.PrimaryEmailCount, 0) AS PrimaryEmailCount,
	COALESCE(ea.VerifiedEmailCount, 0) AS VerifiedEmailCount,

	CASE WHEN COALESCE(ea.PrimaryEmailCount, 0) > 1 THEN 1 ELSE 0 END AS HasMultiplePrimaryEmails,
	CASE WHEN COALESCE(ea.PrimaryEmailCount, 0) = 0 THEN 1 ELSE 0 END AS HasNoPrimaryEmail,
	CASE WHEN COALESCE(ea.EmailCount, 0) = 0 THEN 1 ELSE 0 END AS HasNoEmail,

	er.EmailAddress AS SelectedEmailAddress,
	er.CustomerEmailID AS SelectedEmailID,
	er.IsPrimary AS SelectedEmailIsPrimary,
	er.IsVerified AS SelectedEmailIsVerified,
	er.VerifiedAt AS SelectedEmailVerifiedAt,
	er.CreatedAt AS SelectedEmailCreatedAt,
	er.EmailBucket AS EmailBucketRule
FROM crm.Customer c
LEFT JOIN EmailAgg ea
	ON ea.CustomerID = c.CustomerID
OUTER APPLY
(
	SELECT TOP 1
		ce.CustomerEmailID,
		ce.EmailAddress,
		ce.IsPrimary,
		ce.IsVerified,
		ce.VerifiedAt,
		ce.CreatedAt,
		EmailBucket =
			CASE 
				WHEN ce.IsPrimary = 1 AND ce.IsVerified = 1 THEN 1
				WHEN ce.IsVerified = 1 THEN 2
				WHEN ce.IsPrimary = 1 THEN 3
				ELSE 4
			END
	FROM crm.CustomerEmail ce
	WHERE ce.CustomerID = c.CustomerID
	ORDER BY
		EmailBucket ASC,
		ce.VerifiedAt DESC,
		ce.CreatedAt DESC,
		ce.CustomerEmailID DESC
) as er;
GO