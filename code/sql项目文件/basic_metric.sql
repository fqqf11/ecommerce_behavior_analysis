use sql_pandas;
/* =============================================
   数据一致性校验：和Python清洗后结果核对
   ============================================= */
SELECT
    COUNT(*) AS total_rows,           -- 总数据条数
    COUNT(DISTINCT user_id) AS total_users,  -- 总用户数
    COUNT(DISTINCT product_id) AS total_items, -- 总商品数
    COUNT(DISTINCT category_id) AS total_cats -- 总品类数
FROM clean_data;
##联合索引
    -- 联合索引（仅执行一次，重复执行会报错）
-- 时段/日期流量查询专用索引
ALTER TABLE clean_data ADD INDEX idx_event_time (event_type, hour, date);
-- 分品类分析专用索引
ALTER TABLE clean_data ADD INDEX idx_cat_event (category_id, event_type);
-- 分商品分析专用索引
ALTER TABLE clean_data ADD INDEX idx_prod_event (product_id, event_type);
-- 用户维度聚合专用索引
ALTER TABLE clean_data ADD INDEX idx_user_event (user_id, event_type);
/* =============================================
   模块1：时段PV/UV统计
   功能：按小时维度统计浏览量、独立用户数，定位用户活跃高峰
   ============================================= */
SELECT hour,
    COUNT(*) AS pv,                -- 浏览次数（PV）
    COUNT(DISTINCT user_id) AS uv  -- 独立浏览用户数（UV）
FROM clean_data
WHERE event_type = 'view'         -- 仅统计浏览行为
GROUP BY hour
ORDER BY hour;
##每日流量与人均浏览量
#统计每日流量规模，计算人均浏览页数
SELECT
    date,
    COUNT(*) AS pv,                          -- 每日浏览PV
    COUNT(DISTINCT user_id) AS uv,           -- 每日浏览UV
    COUNT(*) / COUNT(DISTINCT user_id) AS avg_page_view  -- 人均浏览量 = PV / UV
FROM clean_data
WHERE event_type = 'view'
GROUP BY date
ORDER BY date;
##用户维度加购率
#浏览用户中，产生加购行为的用户占比（分母 = 浏览独立用户）
/*SELECT
    -- 分母：总浏览独立用户数
    COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END) AS total_view_uv,
    -- 分子：有加购行为的浏览用户数（同时具备浏览+加购行为）
    COUNT(DISTINCT CASE
        WHEN event_type = 'cart'
        AND user_id IN (SELECT DISTINCT user_id FROM clean_data WHERE event_type = 'view')
        THEN user_id
    END) AS cart_user_num,
    -- 计算加购率，保留4位小数
    ROUND(
        COUNT(DISTINCT CASE
            WHEN event_type = 'cart'
            AND user_id IN (SELECT DISTINCT user_id FROM clean_data WHERE event_type = 'view')
            THEN user_id
        END)
        /
        COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END),
        4
    ) AS cart_rate
FROM clean_data;
  */
##用户维度购买转化率
#浏览用户中最终下单购买的用户占比，与加购率统一分母，保证指标可比
/*SELECT
    -- 分母：总浏览独立用户数（与加购率复用口径）
    COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END) AS total_view_uv,
    -- 分子：有购买行为的浏览用户数（同时具备浏览+购买行为）
    COUNT(DISTINCT CASE
        WHEN event_type = 'purchase'
        AND user_id IN (SELECT DISTINCT user_id FROM clean_data WHERE event_type = 'view')
        THEN user_id
    END) AS purchase_user_num,
    -- 计算购买转化率，保留4位小数
    ROUND(
        COUNT(DISTINCT CASE
            WHEN event_type = 'purchase'
            AND user_id IN (SELECT DISTINCT user_id FROM clean_data WHERE event_type = 'view')
            THEN user_id
        END)
        /
        COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END),
        4
    ) AS purchase_rate
FROM clean_data;
  */
#性能优化
/* =============================================
   模块2：加购率 + 购买转化率 替换为 CTE 聚合写法
   功能：将两个独立查询合并为一个 CTE 查询，只扫描一次表，同时出两个指标
   ============================================= */
WITH user_behavior_tag AS (
    -- 先按用户聚合，一次性打全行为标签，仅扫描一次全表
    SELECT
        user_id,
        MAX(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) AS has_view,
        MAX(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END) AS has_cart,
        MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS has_purchase
    FROM clean_data
    GROUP BY user_id
)
SELECT
    -- 公共分母：浏览独立用户数
    SUM(has_view) AS total_view_uv,
    -- 加购率相关
    SUM(CASE WHEN has_view = 1 AND has_cart = 1 THEN 1 ELSE 0 END) AS cart_user_num,
    ROUND(SUM(CASE WHEN has_view = 1 AND has_cart = 1 THEN 1 ELSE 0 END) * 1.0 / SUM(has_view), 4) AS cart_rate,
    -- 购买转化率相关
    SUM(CASE WHEN has_view = 1 AND has_purchase = 1 THEN 1 ELSE 0 END) AS purchase_user_num,
    ROUND(SUM(CASE WHEN has_view = 1 AND has_purchase = 1 THEN 1 ELSE 0 END) * 1.0 / SUM(has_view), 4) AS purchase_rate
FROM user_behavior_tag;
/* =============================================
   模块3：分品类购买转化率
   功能：各品类下，浏览过该品类的用户的购买转化率
   ============================================= */
SELECT
    category_id,
    -- 分母：该品类的浏览独立用户数
    COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END) AS cat_view_uv,
    -- 分子：该品类的购买独立用户数
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS cat_buy_uv,
    -- 计算转化率，分母为0时返回0，避免空值（对齐Python fillna(0)逻辑）
    ROUND(
    IFNULL(
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END), 0),
        0
    ),
    6
) AS convert_rate
FROM clean_data
GROUP BY category_id
ORDER BY convert_rate DESC, cat_view_uv DESC
/* =============================================
   3.2：零转化品类统计
   功能：统计有浏览但无购买的品类占比，定位长尾优化空间
   ============================================= */
SELECT
    COUNT(*) AS total_category,          -- 有浏览的总品类数
    SUM(CASE WHEN cat_buy_uv = 0 THEN 1 ELSE 0 END) AS zero_convert_cat,  -- 零转化品类数
    ROUND(SUM(CASE WHEN cat_buy_uv = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS zero_convert_rate  -- 零转化品类占比
FROM (
    SELECT
        category_id,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS cat_buy_uv
    FROM clean_data
    GROUP BY category_id
) t;

/* =============================================
   模块4：TOP10 商品统计
   ============================================= */

##4.1销量 TOP10 商品
# 4.1.1:按订单数统计（反映商品整体销量规模）
SELECT
    product_id,
    COUNT(*) AS sale_count  -- 购买订单行数
FROM clean_data
WHERE event_type = 'purchase'
GROUP BY product_id
ORDER BY sale_count DESC
LIMIT 10;
#4.1.2.按购买人数统计（反映商品受众覆盖广度）
SELECT
    product_id,
    COUNT(DISTINCT user_id) AS buy_user_count  -- 购买独立用户数
FROM clean_data
WHERE event_type = 'purchase'
GROUP BY product_id
ORDER BY buy_user_count DESC
LIMIT 10;
##4.2浏览量 TOP10 商品
SELECT
    product_id,
    COUNT(*) AS click_count  -- 商品浏览次数
FROM clean_data
WHERE event_type = 'view'
GROUP BY product_id
ORDER BY click_count DESC
LIMIT 10;
##4.3销量 TOP10 品类
SELECT
    category_id,
    COUNT(*) AS sale_count  -- 品类订单销量
FROM clean_data
WHERE event_type = 'purchase'
GROUP BY category_id
ORDER BY sale_count DESC
LIMIT 10;