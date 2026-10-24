use sql_pandas;
/*
-------------RFM 用户价值分层（NTILE 5 档打分 + R/F/M 三维 8 类）
    与 `output/report_v2/分析报告.md` 第七节、以及 Python 侧
    `RFM用户分层.ipynb` 使用完全相同的口径，可三方对账。

【口径定义】
  R = 最近一次购买距「数据截止日」的天数            → 越小越好，按 recency DESC 分箱（间隔小→高分）
  F = 购买订单数 = COUNT(DISTINCT event_time)       → 同一订单内多件商品共用时间戳，去重即订单数
  M = 累计消费金额 SUM(price)                       → 越大越好，按 monetary ASC 分箱（金额大→高分）

  三者各自 NTILE(5) 等样本分箱得 1–5 分，再以「>= 4 分」为高、其余为低，组合成标准 8 类。

【期望值（基于 clean_2019.csv，2575 名购买用户，可用于对账）】
  R 均值 ≈ 13.02 天 | F 均值 ≈ 1.05 单 | M 均值 ≈ 22.86
  重要价值  198 人(7.69%)  消费占比 18.79%
  重要保持  274 人(10.64%) 消费占比 23.11%
  重要发展  186 人(7.22%)  消费占比 16.62%
  重要挽留  372 人(14.45%) 消费占比 29.24%
  一般价值  251 人(9.75%)  消费占比  2.02%
  一般保持  307 人(11.92%) 消费占比  2.45%
  一般发展  395 人(15.34%) 消费占比  3.29%
  一般挽留  592 人(22.99%) 消费占比  4.47%
  ⇒ 高价值层（重要价值+重要保持）= 472 人(18.33%)，贡献 41.9% 消费
  ⇒ 只买过 1 单的用户 2454 人（95.3%）

【与历史版本的差异（务必知悉）】
  早期版本存在两处口径问题，本版已修正：
  1. F 原用 COUNT(*)：本数据中"一次购买事件 = 一行 = 一件商品"，
     一单多件会被算成多次购买（实测 F 均值虚高：1.526 vs 真实订单 1.054，约 1.45 倍）→ 已改 COUNT(DISTINCT event_time)。
  2. M_score 原已计算但未参与分层（CASE 只用了 R、F），M 维度被浪费 → 本版改为 R/F/M 三维 8 类。
  因此本脚本结果与旧版 `output/data/rfm_segment.csv`（4 类、高价值仅 10 人）**不再一致**，
  旧数据已废弃，请以本脚本与 report_v2 为准。
 */
WITH user_rfm_raw AS (
    -- 步骤1：聚合每个用户的 R/F/M 原始指标
    SELECT
        user_id,
        DATEDIFF(
            (SELECT MAX(event_time) FROM clean_data WHERE event_type = 'purchase'),
            MAX(event_time)
        ) AS recency,
        COUNT(DISTINCT event_time) AS frequency,   -- 订单数（非商品件数）
        SUM(price) AS monetary
    FROM clean_data
    WHERE event_type = 'purchase'
    GROUP BY user_id
),
user_rfm_score AS (
    -- 步骤2：等样本分箱打分（1-5 分，每档用户数大致相同）
    SELECT
        user_id,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency   DESC) AS R_score,   -- 间隔越小分越高
        NTILE(5) OVER (ORDER BY frequency ASC)  AS F_score,   -- 订单越多分越高
        NTILE(5) OVER (ORDER BY monetary  ASC)  AS M_score    -- 金额越高分越高
    FROM user_rfm_raw
),
user_rfm_label AS (
    -- 步骤3：R/F/M 各自以 4 分为界划高/低，组合成标准 8 类
    SELECT
        *,
        CASE
            WHEN R_score >= 4 AND F_score >= 4 AND M_score >= 4 THEN '重要价值'
            WHEN R_score <  4 AND F_score >= 4 AND M_score >= 4 THEN '重要保持'
            WHEN R_score >= 4 AND F_score <  4 AND M_score >= 4 THEN '重要发展'
            WHEN R_score <  4 AND F_score <  4 AND M_score >= 4 THEN '重要挽留'
            WHEN R_score >= 4 AND F_score >= 4 AND M_score <  4 THEN '一般价值'
            WHEN R_score <  4 AND F_score >= 4 AND M_score <  4 THEN '一般保持'
            WHEN R_score >= 4 AND F_score <  4 AND M_score <  4 THEN '一般发展'
            WHEN R_score <  4 AND F_score <  4 AND M_score <  4 THEN '一般挽留'
            ELSE '未分类'
        END AS user_type
    FROM user_rfm_score
)
-- 步骤4：统计各分层的人数、消费及占比
SELECT
    user_type                                                  AS 用户类型,
    COUNT(*)                                                   AS 用户数,
    ROUND(AVG(recency), 2)                                     AS 平均R_天数,
    ROUND(AVG(frequency), 2)                                   AS 平均F_订单数,
    ROUND(SUM(monetary), 2)                                    AS 消费总金额,
    ROUND(AVG(monetary), 2)                                    AS 人均消费,
    ROUND(COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (), 4)           AS 人数占比,
    ROUND(SUM(monetary) * 1.0 / SUM(SUM(monetary)) OVER (), 4) AS 消费占比
FROM user_rfm_label
GROUP BY user_type
ORDER BY 消费占比 DESC;
