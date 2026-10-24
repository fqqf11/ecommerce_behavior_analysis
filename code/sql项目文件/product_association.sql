use sql_pandas;
/*
-------------商品关联规则分析（与 Python mlxtend Apriori 对齐的 SQL 实现）
   支持度 Support(A→B)    = 同时含 A、B 的订单数 / 总订单数
   置信度 Confidence(A→B) = 同时含 A、B 的订单数 / 含 A 的订单数 = P(B|A)
   提升度 Lift(A→B)       = Confidence(A→B) / (含 B 的订单数 / 总订单数)
                           = 共现订单数 × 总订单数 / (含 A 订单数 × 含 B 订单数)
   lift > 1 表示 A 的出现提升了 B 的购买概率；越大连带越强。

【本次修正 3 处】
1. 原 SQL 只输出支持度，但注释与 README 都写"支持度、置信度、提升度"，
   导致 SQL 无法与 Python(mlxtend) 交叉验证 → 现补全 confidence 与 lift。
2. 原用 COUNT(*) 计共现次数，同一订单内商品重复行会虚增 → 改用 COUNT(DISTINCT order_id)。
3. ★原 SQL 无 min_support 过滤，直接 ORDER BY 次数取 TOP20，会把"只共现 1 次"的
   偶发组合排到最前（这类组合 lift 高达 2673，纯属噪音）。现补 min_support = 0.002，
   与 Python 端 Apriori 的 min_support 对齐。

【与 README 数字的对账（已实测）】
   总订单 2,673；商品对 1,309。
   加 min_support=0.002 后保留 67 条规则：
     support 区间 ≈ 0.224% ~ 1.684%，lift 上限 ≈ 77.3
   README 写"提升度高达 45—75、支持度 0.2%—0.3%"，与实测基本吻合；
   需注意 README 里的 0.2%—0.3% 实为「min_support 阈值」而非 support 的实际取值区间
   （实际最高可到 1.68%），表述上建议改为"以 0.2% 为最小支持度"。

【口径说明】
 - 订单定义：同一 user_id + 同一 date 视为一个订单（原始数据无订单号）。
   若同一天存在多次独立下单会被合并为一单，支持度会略偏高；
   如需更严格，把 date 换成 event_time（同一订单内多件商品共用同一时间戳）。
 - 组合去重：只保留 product_id 较小者在前（a < b），保证每对组合每单只计一次。
 */
WITH order_items AS (
    SELECT
        CONCAT(user_id, '_', date) AS order_id,
        product_id
    FROM clean_data
    WHERE event_type = 'purchase'
),
total_orders AS (
    SELECT COUNT(DISTINCT order_id) AS total_cnt FROM order_items
),
item_orders AS (
    -- 每个商品出现在多少个订单里（置信度分母）
    SELECT
        product_id,
        COUNT(DISTINCT order_id) AS order_cnt
    FROM order_items
    GROUP BY product_id
),
pair AS (
    -- 商品对的共现订单数
    SELECT
        a.product_id AS product_A,
        b.product_id AS product_B,
        COUNT(DISTINCT a.order_id) AS co_occur_cnt
    FROM order_items a
    JOIN order_items b
        ON a.order_id = b.order_id
        AND a.product_id < b.product_id      -- 避免重复组合与自关联
    GROUP BY a.product_id, b.product_id
)
SELECT
    p.product_A,
    p.product_B,
    p.co_occur_cnt,
    -- 支持度：共现订单 / 总订单
    ROUND(p.co_occur_cnt * 1.0 / t.total_cnt, 4)                         AS support,
    -- 置信度：共现订单 / 含 A 的订单
    ROUND(p.co_occur_cnt * 1.0 / ia.order_cnt, 4)                        AS confidence_A_to_B,
    -- 提升度：置信度 / 后项出现概率
    ROUND(
        (p.co_occur_cnt * 1.0 / ia.order_cnt)
        / NULLIF(ib.order_cnt * 1.0 / t.total_cnt, 0)
    , 2)                                                                 AS lift_A_to_B
FROM pair p
JOIN total_orders t  ON 1 = 1
JOIN item_orders ia  ON ia.product_id = p.product_A
JOIN item_orders ib  ON ib.product_id = p.product_B
WHERE p.co_occur_cnt * 1.0 / t.total_cnt >= 0.002   -- min_support = 0.2%，与 Python 端 Apriori 一致
ORDER BY lift_A_to_B DESC, p.co_occur_cnt DESC
LIMIT 20;
