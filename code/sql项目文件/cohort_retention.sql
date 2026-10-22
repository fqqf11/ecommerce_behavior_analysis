use sql_pandas;
/*
 -------------同期群留存分析:按用户首次访问日期分组（同期群），看这群人在后续第 1、3、7、30 天的留存情况，衡量用户粘性、拉新质量，判断运营活动是否有长效价值。
 -------------
 */

WITH user_first_date AS (
    -- 步骤1：计算每个用户的首次访问日期
    SELECT
        user_id,
        MIN(date) AS first_date
    FROM clean_data
    GROUP BY user_id
),
user_days AS (
    -- 步骤2：关联原表，计算每条记录距离首次访问的天数
    SELECT
        a.user_id,
        b.first_date,
        DATEDIFF(a.date, b.first_date) AS days_since_first
    FROM clean_data a
    LEFT JOIN user_first_date b ON a.user_id = b.user_id
),
cohort_data AS (
    -- 步骤3：按首次日期+间隔天数，统计留存用户数
    SELECT
        first_date,
        days_since_first,
        COUNT(DISTINCT user_id) AS user_cnt
    FROM user_days
    GROUP BY first_date, days_since_first
)
-- 步骤4：计算留存率（除以第0天的用户数）+ 关键节点输出
SELECT
    first_date,
    MAX(CASE WHEN days_since_first = 0 THEN user_cnt END) AS day0_users,
    ROUND(MAX(CASE WHEN days_since_first = 1 THEN user_cnt END) / MAX(CASE WHEN days_since_first = 0 THEN user_cnt END), 4) AS day1_retention,
    ROUND(MAX(CASE WHEN days_since_first = 3 THEN user_cnt END) / MAX(CASE WHEN days_since_first = 0 THEN user_cnt END), 4) AS day3_retention,
    ROUND(MAX(CASE WHEN days_since_first = 7 THEN user_cnt END) / MAX(CASE WHEN days_since_first = 0 THEN user_cnt END), 4) AS day7_retention,
    ROUND(MAX(CASE WHEN days_since_first = 30 THEN user_cnt END) / MAX(CASE WHEN days_since_first = 0 THEN user_cnt END), 4) AS day30_retention
FROM cohort_data
GROUP BY first_date
ORDER BY first_date;