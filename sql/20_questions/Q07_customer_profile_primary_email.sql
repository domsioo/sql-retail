/* Q7 - Customer profile with primary email + verification + data-quality flags

Definitions
- Answered via reporting view: reporting.v_dim_customer_profile
- Reporting grain = 1 row per customer
- Base entity = crm.Customer
- FullName = CONCAT(FirstName, ' ', LastName)
- CustomerCreatedAt = crm.Customer.CreatedAt
- SelectedEmailAddress is chosen deterministically from crm.CustomerEmail using this priority:
    1) IsPrimary = 1 AND IsVerified = 1
    2) IsVerified = 1
    3) IsPrimary = 1
    4) any remaining email
- Tie-breakers for selected email:
    VerifiedAt DESC,
    CreatedAt DESC,
    CustomerEmailID DESC
- Primary email status flags are derived from all email rows for the customer:
    HasMultiplePrimaryEmails = 1 when PrimaryEmailCount > 1
    HasNoPrimaryEmail = 1 when PrimaryEmailCount = 0
    HasNoEmail = 1 when EmailCount = 0
- Exactly one primary email can be inferred when:
    HasNoPrimaryEmail = 0
    AND HasMultiplePrimaryEmails = 0
- SelectedEmailIsVerified is the verified flag for the chosen email
- OUTER APPLY is used upstream so customers with no email are still returned

Output columns
- CustomerID
- CustomerNK
- FullName
- PrimaryEmailAddress
- PrimaryEmailIsVerified
- CustomerCreatedAt
- IsActive
- PrimaryEmailCount
- PrimaryEmailStatus
- HasMultiplePrimaryEmails
- HasNoPrimaryEmail
- HasNoEmail
*/

SELECT
    CustomerID,
    CustomerNK,
    FullName,
    SelectedEmailAddress AS PrimaryEmailAddress,
    SelectedEmailIsVerified AS PrimaryEmailIsVerified,
    CustomerCreatedAt,
    IsActive,
    PrimaryEmailCount,
    CASE
        WHEN HasNoEmail = 1 THEN 'NO_EMAIL'
        WHEN HasMultiplePrimaryEmails = 1 THEN 'MULTIPLE_PRIMARY_EMAILS'
        WHEN HasNoPrimaryEmail = 1 THEN 'NO_PRIMARY_EMAIL'
        ELSE 'EXACTLY_ONE_PRIMARY_EMAIL'
    END AS PrimaryEmailStatus,
    HasMultiplePrimaryEmails,
    HasNoPrimaryEmail,
    HasNoEmail
FROM reporting.v_dim_customer_profile
ORDER BY
    CustomerID;