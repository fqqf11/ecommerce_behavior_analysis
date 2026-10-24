use sql_pandas;
/*
  -------------同期群留存分析:按用户首次活跃月份分组（同期群），看这群人在后续第 1~N 个月是否还活跃，衡量用户粘性、拉新质量，判断运营活动是否有长效价值。
  -------------
 */

WITH user_first_month AS (
    -- 步骤1：计算每个用户的首次活跃月份
    SELECT
        user_id,
        DATE_FORMAT(MIN(date), '%Y-%m') AS first_month
    FROM clean_data
    GROUP BY user_id
),
user_months AS (
    -- 步骤2：关联原表，计算每条记录距离首次活跃的月数
    SELECT
        a.user_id,
        b.first_month,
        TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(b.first_month, '-01'), '%Y-%m-%d'),
                             STR_TO_DATE(CONCAT(DATE_FORMAT(a.date, '%Y-%m'), '-01'), '%Y-%m-%d')) AS month_offset
    FROM clean_data a
    LEFT JOIN user_first_month b ON a.user_id = b.user_id
),
cohort_data AS (
    -- 步骤3：按首次月份+间隔月数，统计留存用户数
    SELECT
        first_month,
        month_offset,
        COUNT(DISTINCT user_id) AS user_cnt
    FROM user_months
    GROUP BY first_month, month_offset
)
-- 步骤4：计算留存率（除以第0个月的用户数）
SELECT
    first_month,
    MAX(CASE WHEN month_offset = 0 THEN user_cnt END) AS month0_users,
    ROUND(MAX(CASE WHEN month_offset = 1 THEN user_cnt END) / MAX(CASE WHEN month_offset = 0 THEN user_cnt END), 4) AS month1_retention,
    ROUND(MAX(CASE WHEN month_offset = 2 THEN user_cnt END) / MAX(CASE WHEN month_offset = 0 THEN user_cnt END), 4) AS month2_retention,
    ROUND(MAX(CASE WHEN month_offset = 3 THEN user_cnt END) / MAX(CASE WHEN month_offset = 0 THEN user_cnt END), 4) AS month3_retention,
    ROUND(MAX(CASE WHEN month_offset = 4 THEN user_cnt END) / MAX(CASE WHEN month_offset = 0 THEN user_cnt END), 4) AS month4_retention
FROM cohort_data
GROUP BY first_month
ORDER BY first_month;