use sql_pandas;
/*
-------------转化漏斗：各环节独立用户数、单步转化率、整体转化率

【口径定义（必须与 Python notebook「转化漏斗分析.ipynb」完全一致，
   否则 README 里"双工具交叉验证一致"的说法不成立）】

  pv_cnt        = 浏览独立用户数   |view|            = 18,621
  cart_cnt      = 加购独立用户数   |cart|            =  5,878
  buy_cnt       = 购买独立用户数   |purchase|        =  2,575
  buy_and_cart  = 购买且加购用户数 |purchase ∩ cart| =  2,324

  浏览→加购转化率 = cart_cnt / pv_cnt            ≈ 31.57%
  加购→购买转化率 = buy_and_cart / cart_cnt      ≈ 39.54%
  整体转化率      = buy_cnt / pv_cnt             ≈ 13.83%

【本次修正】
1. ★整体转化率口径错了：原代码把分子写成「购买∩加购」，会漏掉"未加购直接购买"
   的用户（本数据中为 251 人，占购买用户 9.75%），导致整体转化率被低估为 12.48%，
   正确值应为 购买UV / 浏览UV = 13.83%。
2. pv_cnt 原命名暗示 PV（行为条数），实际统计的是 UV（去重用户），已更名为 view_uv。
3. 增加流失率与"跳过加购""加购未购"两组人群规模，便于直接落到运营动作。

【口径说明（避坑）】
  - 浏览→加购 用的是"加购UV/浏览UV"，属于行业常用「加购率」定义，不要求加购用户一定浏览过；
  - 加购→购买 是"购物车转化率"，分母为加购用户、分子为其中最终购买的人数；
  - 因为是三种不同口径，三者相乘不等于整体转化率，这是正常现象（部分用户跳过购物车直接下单），
    如被追问需能解释这一点。
 */
WITH user_tag AS (
    -- 一次扫描，按用户打全浏览 / 加购 / 购买标签
    SELECT
        user_id,
        MAX(CASE WHEN event_type = 'view'     THEN 1 ELSE 0 END) AS has_view,
        MAX(CASE WHEN event_type = 'cart'     THEN 1 ELSE 0 END) AS has_cart,
        MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS has_buy
    FROM clean_data
    GROUP BY user_id
)
SELECT
    -- ① 各环节独立用户数
    SUM(has_view)                                                     AS view_uv,
    SUM(has_cart)                                                     AS cart_uv,
    SUM(has_buy)                                                      AS buy_uv,
    SUM(CASE WHEN has_buy = 1 AND has_cart = 1 THEN 1 ELSE 0 END)     AS buy_and_cart_uv,

    -- ② 环节转化率
    ROUND(SUM(has_cart) * 1.0 / NULLIF(SUM(has_view), 0), 4)          AS pv_to_cart,
    ROUND(SUM(CASE WHEN has_buy = 1 AND has_cart = 1 THEN 1 ELSE 0 END)
          * 1.0 / NULLIF(SUM(has_cart), 0), 4)                        AS cart_to_buy,
    ROUND(SUM(has_buy) * 1.0 / NULLIF(SUM(has_view), 0), 4)           AS pv_to_buy,

    -- ③ 流失率
    ROUND(1 - SUM(has_cart) * 1.0 / NULLIF(SUM(has_view), 0), 4)      AS view_loss_rate,
    ROUND(1 - SUM(CASE WHEN has_buy = 1 AND has_cart = 1 THEN 1 ELSE 0 END)
              * 1.0 / NULLIF(SUM(has_cart), 0), 4)                    AS cart_loss_rate,

    -- ④ 可直接落运营动作的人群规模
    SUM(CASE WHEN has_cart = 1 AND has_buy = 0 THEN 1 ELSE 0 END)     AS cart_not_buy_uv,   -- 加购未购（高意向召回池）
    SUM(CASE WHEN has_cart = 0 AND has_buy = 1 THEN 1 ELSE 0 END)     AS buy_without_cart_uv -- 跳过购物车直接下单
FROM user_tag;
