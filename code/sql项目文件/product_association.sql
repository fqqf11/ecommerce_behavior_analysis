use sql_pandas;
/*
 -------------商品关联规则分析:挖掘用户订单中经常一起购买的商品组合，输出支持度、置信度、提升度高的关联规则，用于凑单推荐、详情页关联推荐、购物车推荐，提升客单价。
 -------------
 */
WITH order_items AS (
    -- 构建购物篮：用户+同一天视为一个订单
    SELECT
        CONCAT(user_id, '_', date) AS order_id,
        product_id
    FROM clean_data
    WHERE event_type = 'purchase'
)
SELECT
    a.product_id AS product_A,
    b.product_id AS product_B,
    COUNT(*) AS co_occur_cnt, -- 共同出现次数
    ROUND(COUNT(*) * 1.0 / (SELECT COUNT(DISTINCT order_id) FROM order_items), 4) AS support -- 支持度，保留4位小数
FROM order_items a
JOIN order_items b
    ON a.order_id = b.order_id
    AND a.product_id < b.product_id -- 避免重复组合
GROUP BY a.product_id, b.product_id
ORDER BY co_occur_cnt DESC
LIMIT 20;