/* Q22 - Refund turnaround time (avg + median) by return reason

Definitions
- Reporting grain = 1 row per ReturnReasonCode
- Included rows = refunded return lines only, where:
    sales.ReturnLine.RefundStatusCode = 'REFUNDED'
    AND sales.ReturnLine.RefundedAt IS NOT NULL
- Turnaround = DATEDIFF(MINUTE, sales.ReturnHeader.CreatedAt, sales.ReturnLine.RefundedAt) / 1440.0
- Grain of turnaround measurement = return line
- AverageRefundDays = AVG(RefundDays)
- MedianRefundDays = PERCENTILE_CONT(0.5) within each ReturnReasonCode partition
- RefundedReturnLines = count of refunded return lines in the reason bucket

Output columns
- ReturnReasonCode
- ReasonName
- RefundedReturnLines
- AverageRefundDays
- MedianRefundDays
*/

WITH ReturnLineRefundTimes AS
(
    SELECT
        rh.ReturnReasonCode,
        rr.ReasonName,
        DATEDIFF(MINUTE, rh.CreatedAt, rl.RefundedAt) / 1440.0 AS RefundDays
    FROM sales.ReturnHeader rh
    JOIN sales.ReturnLine rl
        ON rl.ReturnID = rh.ReturnID
    JOIN ref.ReturnReason rr
        ON rr.ReturnReasonCode = rh.ReturnReasonCode
    WHERE
        rl.RefundStatusCode = 'REFUNDED'
        AND rl.RefundedAt IS NOT NULL
),
WithMedian AS
(
    SELECT
        rlrt.ReturnReasonCode,
        rlrt.ReasonName,
        rlrt.RefundDays,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rlrt.RefundDays ASC)
            OVER (PARTITION BY rlrt.ReturnReasonCode) AS MedianRefundDays
    FROM ReturnLineRefundTimes rlrt
)
SELECT
    wm.ReturnReasonCode,
    wm.ReasonName,
    COUNT(*) AS RefundedReturnLines,
    CAST(AVG(wm.RefundDays) AS DECIMAL(18, 2)) AS AverageRefundDays,
    CAST(MAX(wm.MedianRefundDays) AS DECIMAL(18, 2)) AS MedianRefundDays
FROM WithMedian wm
GROUP BY
    wm.ReturnReasonCode,
    wm.ReasonName
ORDER BY
    AverageRefundDays ASC,
    wm.ReturnReasonCode;