use sql_pandas;
/*
-------------RFM 用户价值分群(从R（最近购买间隔）、F（购买频次）、M（消费金额）三个维度，把用户分成 8 类（重要价值、重要发展、重要保持、重要挽留等），统计每类用户的人数占比、消费贡献，给出对应运营策略)
-------------
 */
WITH user_rfm_raw AS (
    -- 步骤1：聚合每个用户的R/F/M原始指标
    SELECT
        user_id,
        -- R：最近一次购买距离截止日的天数
        DATEDIFF((SELECT MAX(event_time) FROM clean_data WHERE event_type = 'purchase'), MAX(event_time)) AS recency,
        -- F：购买总次数
        COUNT(*) AS frequency,
        -- M：消费总金额
        SUM(price) AS monetary
    FROM clean_data
    WHERE event_type = 'purchase'
    GROUP BY user_id
),
user_rfm_score AS (
    -- 步骤2：等样本分箱打分（1-5分，每档用户数大致相同）
    SELECT
        user_id,
        recency,
        frequency,
        monetary,
        -- R打分：间隔天数越小，分数越高 → 倒序分箱
        NTILE(5) OVER (ORDER BY recency DESC) AS R_score,
        -- F打分：购买次数越多，分数越高 → 正序分箱
        NTILE(5) OVER (ORDER BY frequency ASC) AS F_score,
        -- M打分：消费金额越高，分数越高 → 正序分箱
        NTILE(5) OVER (ORDER BY monetary ASC) AS M_score
    FROM user_rfm_raw
),
user_rfm_label AS (
    -- 步骤3：4类用户分层（规则保持不变）
    SELECT
        *,
        CASE
            WHEN R_score >= 4 AND F_score >= 4 THEN '重要价值用户'
            WHEN R_score >= 4 AND F_score < 4 THEN '重要发展用户'
            WHEN R_score < 4 AND F_score >= 4 THEN '重要保持用户'
            WHEN R_score < 4 AND F_score < 4 THEN '重要挽留用户'
            ELSE '一般用户'
        END AS user_type
    FROM user_rfm_score
)
-- 步骤4：统计各分层的人数、消费及占比
SELECT
    user_type,
    COUNT(*) AS 用户数,
    ROUND(SUM(monetary), 2) AS 消费总金额,
    ROUND(COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (), 4) AS 人数占比,
    ROUND(SUM(monetary) * 1.0 / SUM(SUM(monetary)) OVER (), 4) AS 消费占比
FROM user_rfm_label
GROUP BY user_type
ORDER BY 消费占比 DESC;