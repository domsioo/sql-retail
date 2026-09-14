/* reporting.v_audit_return_anomaly_summary - Return anomaly counts by anomaly type

Definitions
- Base metadata = reporting.v_audit_return_anomaly_catalog
- Base detail = reporting.v_audit_return_anomalies
- Reporting grain = 1 row per anomaly type
- AnomaliesCount = total anomaly rows for the anomaly type
- AffectedReturns = DISTINCT ReturnID count for the anomaly type
- AffectedReturnLines = DISTINCT ReturnLineID count for the anomaly type
- LEFT JOIN to the catalog ensures zero-count anomaly types still appear

Output columns
- SortOrder
- AnomalyType
- AnomalyGrain
- Severity
- AnomaliesCount
- AffectedReturns
- AffectedReturnLines
*/

CREATE OR ALTER VIEW [reporting].[v_audit_return_anomaly_summary] AS
SELECT
    arac.SortOrder,
    arac.AnomalyType,
    arac.AnomalyGrain,
    arac.Severity,
    COUNT(ara.ReturnID) AS AnomaliesCount,
    COUNT(DISTINCT ara.ReturnID) AS AffectedReturns,
    COUNT(DISTINCT ara.ReturnLineID) AS AffectedReturnLines
FROM reporting.v_audit_return_anomaly_catalog arac
LEFT JOIN reporting.v_audit_return_anomalies ara
    ON ara.AnomalyType = arac.AnomalyType
GROUP BY
    arac.SortOrder,
    arac.AnomalyType,
    arac.AnomalyGrain,
    arac.Severity
GO