use sql_pandas;
/*
-------------转化漏斗多维度拆解计算整体漏斗转化率:计算各环节独立用户数、单步转化率、总转化率、流失率
-------------
 */
SELECT
    -- 分母：浏览独立用户
    COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END) AS pv_cnt,
    -- 分子：同时有浏览+加购的用户
    COUNT(DISTINCT CASE WHEN event_type = 'cart' AND user_id IN (SELECT DISTINCT user_id FROM clean_data WHERE event_type = 'view') THEN user_id END) AS cart_cnt,
    -- 分子：同时有浏览+购买的用户
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' AND user_id IN (SELECT DISTINCT user_id FROM clean_data WHERE event_type = 'view') THEN user_id END) AS buy_cnt,
    -- 转化率
    ROUND(
        COUNT(DISTINCT CASE WHEN event_type = 'cart' AND user_id IN (SELECT DISTINCT user_id FROM clean_data WHERE event_type = 'view') THEN user_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END), 0),
        4
    ) AS pv_to_cart,
    ROUND(
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' AND user_id IN (SELECT DISTINCT user_id FROM clean_data WHERE event_type = 'view') THEN user_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'cart' AND user_id IN (SELECT DISTINCT user_id FROM clean_data WHERE event_type = 'view') THEN user_id END), 0),
        4
    ) AS cart_to_buy,
    ROUND(
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' AND user_id IN (SELECT DISTINCT user_id FROM clean_data WHERE event_type = 'view') THEN user_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END), 0),
        4
    ) AS pv_to_buy
FROM clean_data;