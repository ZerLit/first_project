/* Проект «Разработка витрины и решение ad-hoc задач»
 * Цель проекта: подготовка витрины данных маркетплейса «ВсёТут»
 * и решение четырех ad hoc задач на её основе
 * 
 * Автор: Кобелев Максим Сергеевич
 * Дата: 18.07.2026
*/



/* Часть 1. Разработка витрины данных
 * Напишите ниже запрос для создания витрины данных
*/


WITH top_regions AS (
    -- Определяем три самых активных региона
    SELECT
        u.region
    FROM ds_ecom.orders AS o
    JOIN ds_ecom.users AS u
        ON o.buyer_id = u.buyer_id
    WHERE o.order_status IN ('Доставлено', 'Отменено')
    GROUP BY u.region
    ORDER BY COUNT(DISTINCT o.order_id) DESC
    LIMIT 3
),

order_costs AS (
    -- Считаем стоимость каждого заказа:
    -- товары + доставка
    SELECT
        oi.order_id,
        SUM(oi.price + oi.delivery_cost) AS order_cost
    FROM ds_ecom.order_items AS oi
    GROUP BY oi.order_id
),

payment_features AS (
    -- Собираем платёжные признаки на уровне одного заказа
    SELECT
        op.order_id,

        MAX(
            CASE
                WHEN op.payment_sequential = 1
                     AND op.payment_type = 'денежный перевод'
                THEN 1
                ELSE 0
            END
        ) AS used_money_transfer,

        MAX(
            CASE
                WHEN op.payment_installments > 1
                THEN 1
                ELSE 0
            END
        ) AS used_installments,

        MAX(
            CASE
                WHEN op.payment_type = 'промокод'
                THEN 1
                ELSE 0
            END
        ) AS used_promo

    FROM ds_ecom.order_payments AS op
    GROUP BY op.order_id
),

review_features AS (
    -- Собираем оценку на уровне одного заказа
    SELECT
        order_id,
        AVG(review_score::numeric) AS order_rating
    FROM ds_ecom.order_reviews
    GROUP BY order_id
),

product_user_features AS (
    SELECT
        u.user_id,
        u.region,

        -- Период активности
        MIN(o.order_purchase_ts) AS first_order_ts,
        MAX(o.order_purchase_ts) AS last_order_ts,

        MAX(o.order_purchase_ts)::date
            - MIN(o.order_purchase_ts)::date AS lifetime,

        -- Заказы
        COUNT(o.order_id) AS total_orders,

        ROUND(
            AVG(r.order_rating),
            2
        ) AS avg_order_rating,

        COUNT(r.order_id) AS num_orders_with_rating,

        COUNT(*) FILTER (
            WHERE o.order_status = 'Отменено'
        ) AS num_canceled_orders,

        ROUND(
            (
                COUNT(*) FILTER (
                    WHERE o.order_status = 'Отменено'
                )
            )::numeric
            / COUNT(*),
            4
        ) AS canceled_orders_ratio,

        -- Стоимость доставленных заказов
        COALESCE(
            SUM(oc.order_cost) FILTER (
                WHERE o.order_status = 'Доставлено'
            ),
            0
        ) AS total_order_costs,

        ROUND(
            AVG(oc.order_cost) FILTER (
                WHERE o.order_status = 'Доставлено'
            ),
            2
        ) AS avg_order_cost,

        -- Платёжные признаки
        SUM(
            COALESCE(p.used_installments, 0)
        ) AS num_installment_orders,

        SUM(
            COALESCE(p.used_promo, 0)
        ) AS num_orders_with_promo,

        MAX(
            COALESCE(p.used_money_transfer, 0)
        ) AS used_money_transfer,

        MAX(
            COALESCE(p.used_installments, 0)
        ) AS used_installments,

        MAX(
            CASE
                WHEN o.order_status = 'Отменено'
                THEN 1
                ELSE 0
            END
        ) AS used_cancel

    FROM ds_ecom.orders AS o

    JOIN ds_ecom.users AS u
        ON o.buyer_id = u.buyer_id

    JOIN top_regions AS tr
        ON u.region = tr.region

    LEFT JOIN order_costs AS oc
        ON o.order_id = oc.order_id

    LEFT JOIN payment_features AS p
        ON o.order_id = p.order_id

    LEFT JOIN review_features AS r
        ON o.order_id = r.order_id

    WHERE o.order_status IN ('Доставлено', 'Отменено')

    GROUP BY
        u.user_id,
        u.region
)

SELECT *
FROM product_user_features
ORDER BY
    region,
    user_id;


/* Часть 2. Решение ad hoc задач
 * Для каждой задачи напишите отдельный запрос.
 * После каждой задачи оставьте краткий комментарий с выводами по полученным результатам.
*/

/* Задача 1. Сегментация пользователей 
 * Разделите пользователей на группы по количеству совершённых ими заказов.
 * Подсчитайте для каждой группы общее количество пользователей,
 * среднее количество заказов, среднюю стоимость заказа.
 * 
 * Выделите такие сегменты:
 * - 1 заказ — сегмент 1 заказ
 * - от 2 до 5 заказов — сегмент 2-5 заказов
 * - от 6 до 10 заказов — сегмент 6-10 заказов
 * - 11 и более заказов — сегмент 11 и более заказов
*/


WITH top_regions AS (
    -- Определяем три самых активных региона
    SELECT
        u.region
    FROM ds_ecom.orders AS o
    JOIN ds_ecom.users AS u
        ON o.buyer_id = u.buyer_id
    WHERE o.order_status IN ('Доставлено', 'Отменено')
    GROUP BY u.region
    ORDER BY COUNT(DISTINCT o.order_id) DESC
    LIMIT 3
),

order_costs AS (
    -- Считаем стоимость каждого заказа:
    -- товары + доставка
    SELECT
        oi.order_id,
        SUM(oi.price + oi.delivery_cost) AS order_cost
    FROM ds_ecom.order_items AS oi
    GROUP BY oi.order_id
),

payment_features AS (
    -- Собираем платёжные признаки на уровне одного заказа
    SELECT
        op.order_id,

        MAX(
            CASE
                WHEN op.payment_sequential = 1
                     AND op.payment_type = 'денежный перевод'
                    THEN 1
                ELSE 0
            END
        ) AS used_money_transfer,

        MAX(
            CASE
                WHEN op.payment_installments > 1
                    THEN 1
                ELSE 0
            END
        ) AS used_installments,

        MAX(
            CASE
                WHEN op.payment_type = 'промокод'
                    THEN 1
                ELSE 0
            END
        ) AS used_promo

    FROM ds_ecom.order_payments AS op
    GROUP BY op.order_id
),

review_features AS (
    -- Собираем оценку на уровне одного заказа
    SELECT
        order_id,
        AVG(review_score::numeric) AS order_rating
    FROM ds_ecom.order_reviews
    GROUP BY order_id
),

product_user_features AS (
    SELECT
        u.user_id,
        u.region,

        -- Период активности
        MIN(o.order_purchase_ts) AS first_order_ts,
        MAX(o.order_purchase_ts) AS last_order_ts,

        MAX(o.order_purchase_ts)::date
            - MIN(o.order_purchase_ts)::date AS lifetime,

        -- Заказы
        COUNT(o.order_id) AS total_orders,

        ROUND(
            AVG(r.order_rating),
            2
        ) AS avg_order_rating,

        COUNT(r.order_id) AS num_orders_with_rating,

        COUNT(*) FILTER (
            WHERE o.order_status = 'Отменено'
        ) AS num_canceled_orders,

        ROUND(
            (
                COUNT(*) FILTER (
                    WHERE o.order_status = 'Отменено'
                )
            )::numeric
            / COUNT(*),
            4
        ) AS canceled_orders_ratio,

        -- Стоимость доставленных заказов
        COALESCE(
            SUM(oc.order_cost) FILTER (
                WHERE o.order_status = 'Доставлено'
            ),
            0
        ) AS total_order_costs,

        ROUND(
            AVG(oc.order_cost) FILTER (
                WHERE o.order_status = 'Доставлено'
            ),
            2
        ) AS avg_order_cost,

        -- Платёжные признаки
        SUM(
            COALESCE(p.used_installments, 0)
        ) AS num_installment_orders,

        SUM(
            COALESCE(p.used_promo, 0)
        ) AS num_orders_with_promo,

        MAX(
            COALESCE(p.used_money_transfer, 0)
        ) AS used_money_transfer,

        MAX(
            COALESCE(p.used_installments, 0)
        ) AS used_installments,

        MAX(
            CASE
                WHEN o.order_status = 'Отменено'
                    THEN 1
                ELSE 0
            END
        ) AS used_cancel

    FROM ds_ecom.orders AS o

    JOIN ds_ecom.users AS u
        ON o.buyer_id = u.buyer_id

    JOIN top_regions AS tr
        ON u.region = tr.region

    LEFT JOIN order_costs AS oc
        ON o.order_id = oc.order_id

    LEFT JOIN payment_features AS p
        ON o.order_id = p.order_id

    LEFT JOIN review_features AS r
        ON o.order_id = r.order_id

    WHERE o.order_status IN ('Доставлено', 'Отменено')

    GROUP BY
        u.user_id,
        u.region
),

segmented_users AS (
    -- Присваиваем каждому пользователю сегмент
    SELECT
        user_id,
        region,
        total_orders,
        avg_order_cost,

        CASE
            WHEN total_orders = 1
                THEN '1 заказ'

            WHEN total_orders BETWEEN 2 AND 5
                THEN '2-5 заказов'

            WHEN total_orders BETWEEN 6 AND 10
                THEN '6-10 заказов'

            ELSE '11 и более заказов'
        END AS order_segment

    FROM product_user_features
)

SELECT
    order_segment,

    -- Количество пользователей в сегменте
    COUNT(*) AS total_users,

    -- Среднее количество заказов
    ROUND(
        AVG(total_orders)::numeric,
        2
    ) AS avg_orders,

    -- Средняя стоимость заказа
    ROUND(
        AVG(avg_order_cost)::numeric,
        2
    ) AS avg_order_cost

FROM segmented_users

GROUP BY order_segment

ORDER BY
    CASE order_segment
        WHEN '1 заказ' THEN 1
        WHEN '2-5 заказов' THEN 2
        WHEN '6-10 заказов' THEN 3
        WHEN '11 и более заказов' THEN 4
    END;
/* Напишите краткий комментарий с выводами по результатам задачи 1.
 * 
*/
/* Вывод:
 * Подавляющее большинство клиентов совершили только один заказ —
 * в этот сегмент вошли 60 516 пользователей.
 *
 * Повторные покупки встречаются значительно реже:
 * в сегменте 2–5 заказов находится 1 965 пользователей,
 * а клиентов с шестью и более заказами практически нет.
 *
 * Средняя стоимость заказа снижается по мере роста количества заказов:
 * с 3 323,27 рубля у клиентов с одним заказом
 * до 1 244,80 рубля у клиента с 11 и более заказами.
 *
 * Однако сегменты с шестью и более заказами содержат слишком мало
 * пользователей, поэтому делать по ним устойчивые выводы пока нельзя.
 * Основная точка роста маркетплейса — увеличение числа повторных покупок.
 */


/* Задача 2. Ранжирование пользователей 
 * Отсортируйте пользователей, сделавших 3 заказа и более, по убыванию среднего чека покупки.  
 * Выведите 15 пользователей с самым большим средним чеком среди указанной группы.
*/


WITH top_regions AS (
    -- Определяем три самых активных региона
    SELECT
        u.region
    FROM ds_ecom.orders AS o
    JOIN ds_ecom.users AS u
        ON o.buyer_id = u.buyer_id
    WHERE o.order_status IN ('Доставлено', 'Отменено')
    GROUP BY u.region
    ORDER BY COUNT(DISTINCT o.order_id) DESC
    LIMIT 3
),

order_costs AS (
    -- Считаем стоимость каждого заказа:
    -- товары + доставка
    SELECT
        oi.order_id,
        SUM(oi.price + oi.delivery_cost) AS order_cost
    FROM ds_ecom.order_items AS oi
    GROUP BY oi.order_id
),

payment_features AS (
    -- Собираем платёжные признаки на уровне одного заказа
    SELECT
        op.order_id,

        MAX(
            CASE
                WHEN op.payment_sequential = 1
                     AND op.payment_type = 'денежный перевод'
                    THEN 1
                ELSE 0
            END
        ) AS used_money_transfer,

        MAX(
            CASE
                WHEN op.payment_installments > 1
                    THEN 1
                ELSE 0
            END
        ) AS used_installments,

        MAX(
            CASE
                WHEN op.payment_type = 'промокод'
                    THEN 1
                ELSE 0
            END
        ) AS used_promo

    FROM ds_ecom.order_payments AS op
    GROUP BY op.order_id
),

review_features AS (
    -- Собираем оценку на уровне одного заказа
    SELECT
        order_id,
        AVG(review_score::numeric) AS order_rating
    FROM ds_ecom.order_reviews
    GROUP BY order_id
),

product_user_features AS (
    SELECT
        u.user_id,
        u.region,

        -- Период активности
        MIN(o.order_purchase_ts) AS first_order_ts,
        MAX(o.order_purchase_ts) AS last_order_ts,

        MAX(o.order_purchase_ts)::date
            - MIN(o.order_purchase_ts)::date AS lifetime,

        -- Заказы
        COUNT(o.order_id) AS total_orders,

        ROUND(
            AVG(r.order_rating),
            2
        ) AS avg_order_rating,

        COUNT(r.order_id) AS num_orders_with_rating,

        COUNT(*) FILTER (
            WHERE o.order_status = 'Отменено'
        ) AS num_canceled_orders,

        ROUND(
            (
                COUNT(*) FILTER (
                    WHERE o.order_status = 'Отменено'
                )
            )::numeric
            / COUNT(*),
            4
        ) AS canceled_orders_ratio,

        -- Стоимость доставленных заказов
        COALESCE(
            SUM(oc.order_cost) FILTER (
                WHERE o.order_status = 'Доставлено'
            ),
            0
        ) AS total_order_costs,

        ROUND(
            AVG(oc.order_cost) FILTER (
                WHERE o.order_status = 'Доставлено'
            ),
            2
        ) AS avg_order_cost,

        -- Платёжные признаки
        SUM(
            COALESCE(p.used_installments, 0)
        ) AS num_installment_orders,

        SUM(
            COALESCE(p.used_promo, 0)
        ) AS num_orders_with_promo,

        MAX(
            COALESCE(p.used_money_transfer, 0)
        ) AS used_money_transfer,

        MAX(
            COALESCE(p.used_installments, 0)
        ) AS used_installments,

        MAX(
            CASE
                WHEN o.order_status = 'Отменено'
                    THEN 1
                ELSE 0
            END
        ) AS used_cancel

    FROM ds_ecom.orders AS o

    JOIN ds_ecom.users AS u
        ON o.buyer_id = u.buyer_id

    JOIN top_regions AS tr
        ON u.region = tr.region

    LEFT JOIN order_costs AS oc
        ON o.order_id = oc.order_id

    LEFT JOIN payment_features AS p
        ON o.order_id = p.order_id

    LEFT JOIN review_features AS r
        ON o.order_id = r.order_id

    WHERE o.order_status IN ('Доставлено', 'Отменено')

    GROUP BY
        u.user_id,
        u.region
)

SELECT
    user_id,
    region,
    total_orders,
    avg_order_cost
FROM product_user_features
WHERE total_orders >= 3
  AND avg_order_cost IS NOT NULL
ORDER BY
    avg_order_cost DESC,
    user_id,
    region
LIMIT 15;

/* Напишите краткий комментарий с выводами по результатам задачи 2.
 * 
*/

/* Вывод:
 * Максимальный средний чек среди пользователей с тремя заказами и более
 * составляет 14 716,67 рубля. Этот пользователь совершил три заказа
 * в Санкт-Петербурге.
 *
 * В топ-15 вошли 9 пользователей из Москвы, 4 из Санкт-Петербурга
 * и 2 из Новосибирской области. Таким образом, среди пользователей
 * с высоким средним чеком преобладают клиенты из Москвы.
 *
 * Большинство пользователей в рейтинге совершили ровно три заказа.
 * Средний чек в топ-15 находится в диапазоне от 5 526,67
 * до 14 716,67 рубля.
 *
 * Этих клиентов можно рассматривать как перспективную аудиторию
 * для программ лояльности и персонализированных предложений,
 * направленных на удержание покупателей с высоким средним чеком.
 */


/* Задача 3. Статистика по регионам. 
 * Для каждого региона подсчитайте:
 * - общее число клиентов и заказов;
 * - среднюю стоимость одного заказа;
 * - долю заказов, которые были куплены в рассрочку;
 * - долю заказов, которые были куплены с использованием промокодов;
 * - долю пользователей, совершивших отмену заказа хотя бы один раз.
*/



WITH top_regions AS (
    -- Определяем три самых активных региона
    SELECT
        u.region
    FROM ds_ecom.orders AS o
    JOIN ds_ecom.users AS u
        ON o.buyer_id = u.buyer_id
    WHERE o.order_status IN ('Доставлено', 'Отменено')
    GROUP BY u.region
    ORDER BY COUNT(DISTINCT o.order_id) DESC
    LIMIT 3
),

order_costs AS (
    -- Считаем стоимость каждого заказа:
    -- товары + доставка
    SELECT
        oi.order_id,
        SUM(oi.price + oi.delivery_cost) AS order_cost
    FROM ds_ecom.order_items AS oi
    GROUP BY oi.order_id
),

payment_features AS (
    -- Собираем платёжные признаки на уровне одного заказа
    SELECT
        op.order_id,

        MAX(
            CASE
                WHEN op.payment_sequential = 1
                     AND op.payment_type = 'денежный перевод'
                    THEN 1
                ELSE 0
            END
        ) AS used_money_transfer,

        MAX(
            CASE
                WHEN op.payment_installments > 1
                    THEN 1
                ELSE 0
            END
        ) AS used_installments,

        MAX(
            CASE
                WHEN op.payment_type = 'промокод'
                    THEN 1
                ELSE 0
            END
        ) AS used_promo

    FROM ds_ecom.order_payments AS op
    GROUP BY op.order_id
),

review_features AS (
    -- Собираем оценку на уровне одного заказа
    SELECT
        order_id,
        AVG(review_score::numeric) AS order_rating
    FROM ds_ecom.order_reviews
    GROUP BY order_id
),

product_user_features AS (
    SELECT
        u.user_id,
        u.region,

        -- Период активности
        MIN(o.order_purchase_ts) AS first_order_ts,
        MAX(o.order_purchase_ts) AS last_order_ts,

        MAX(o.order_purchase_ts)::date
            - MIN(o.order_purchase_ts)::date AS lifetime,

        -- Заказы
        COUNT(o.order_id) AS total_orders,

        ROUND(
            AVG(r.order_rating),
            2
        ) AS avg_order_rating,

        COUNT(r.order_id) AS num_orders_with_rating,

        COUNT(*) FILTER (
            WHERE o.order_status = 'Отменено'
        ) AS num_canceled_orders,

        ROUND(
            (
                COUNT(*) FILTER (
                    WHERE o.order_status = 'Отменено'
                )
            )::numeric
            / COUNT(*),
            4
        ) AS canceled_orders_ratio,

        -- Стоимость доставленных заказов
        COALESCE(
            SUM(oc.order_cost) FILTER (
                WHERE o.order_status = 'Доставлено'
            ),
            0
        ) AS total_order_costs,

        ROUND(
            AVG(oc.order_cost) FILTER (
                WHERE o.order_status = 'Доставлено'
            ),
            2
        ) AS avg_order_cost,

        -- Платёжные признаки
        SUM(
            COALESCE(p.used_installments, 0)
        ) AS num_installment_orders,

        SUM(
            COALESCE(p.used_promo, 0)
        ) AS num_orders_with_promo,

        MAX(
            COALESCE(p.used_money_transfer, 0)
        ) AS used_money_transfer,

        MAX(
            COALESCE(p.used_installments, 0)
        ) AS used_installments,

        MAX(
            CASE
                WHEN o.order_status = 'Отменено'
                    THEN 1
                ELSE 0
            END
        ) AS used_cancel

    FROM ds_ecom.orders AS o

    JOIN ds_ecom.users AS u
        ON o.buyer_id = u.buyer_id

    JOIN top_regions AS tr
        ON u.region = tr.region

    LEFT JOIN order_costs AS oc
        ON o.order_id = oc.order_id

    LEFT JOIN payment_features AS p
        ON o.order_id = p.order_id

    LEFT JOIN review_features AS r
        ON o.order_id = r.order_id

    WHERE o.order_status IN ('Доставлено', 'Отменено')

    GROUP BY
        u.user_id,
        u.region
)

SELECT
    region,

    -- Общее количество клиентов
    COUNT(*) AS total_clients,

    -- Общее количество заказов
    SUM(total_orders) AS total_orders,

    -- Средняя стоимость одного доставленного заказа
    ROUND(
        SUM(total_order_costs)::numeric
        / NULLIF(
            SUM(total_orders - num_canceled_orders),
            0
        ),
        2
    ) AS avg_order_cost,

    -- Доля заказов, оплаченных в рассрочку
    ROUND(
        SUM(num_installment_orders)::numeric
        / NULLIF(SUM(total_orders), 0),
        4
    ) AS installment_orders_ratio,

    -- Доля заказов с использованием промокода
    ROUND(
        SUM(num_orders_with_promo)::numeric
        / NULLIF(SUM(total_orders), 0),
        4
    ) AS promo_orders_ratio,

    -- Доля клиентов, совершивших хотя бы одну отмену
    ROUND(
        SUM(used_cancel)::numeric
        / NULLIF(COUNT(*), 0),
        4
    ) AS users_with_cancel_ratio

FROM product_user_features

GROUP BY region

ORDER BY total_orders DESC;

/* Напишите краткий комментарий с выводами по результатам задачи 3.
 * 
*/

/* Вывод:
 * Москва лидирует по количеству клиентов и заказов.
 * Самый высокий средний чек и наибольшая доля рассрочки —
 * в Санкт-Петербурге.
 * Промокоды используются редко, а доля клиентов с отменами
 * во всех регионах не превышает 1%.
 */

/* Задача 4. Активность пользователей по первому месяцу заказа в 2023 году
 * Разбейте пользователей на группы в зависимости от того, в какой месяц 2023 года они совершили первый заказ.
 * Для каждой группы посчитайте:
 * - общее количество клиентов, число заказов и среднюю стоимость одного заказа;
 * - средний рейтинг заказа;
 * - долю пользователей, использующих денежные переводы при оплате;
 * - среднюю продолжительность активности пользователя.
*/




WITH top_regions AS (
    SELECT
        u.region
    FROM ds_ecom.orders AS o
    JOIN ds_ecom.users AS u
        ON o.buyer_id = u.buyer_id
    WHERE o.order_status IN ('Доставлено', 'Отменено')
    GROUP BY u.region
    ORDER BY COUNT(DISTINCT o.order_id) DESC
    LIMIT 3
),

order_costs AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.delivery_cost) AS order_cost
    FROM ds_ecom.order_items AS oi
    GROUP BY oi.order_id
),

payment_features AS (
    SELECT
        op.order_id,

        MAX(
            CASE
                WHEN op.payment_sequential = 1
                     AND op.payment_type = 'денежный перевод'
                    THEN 1
                ELSE 0
            END
        ) AS used_money_transfer,

        MAX(
            CASE
                WHEN op.payment_installments > 1
                    THEN 1
                ELSE 0
            END
        ) AS used_installments,

        MAX(
            CASE
                WHEN op.payment_type = 'промокод'
                    THEN 1
                ELSE 0
            END
        ) AS used_promo

    FROM ds_ecom.order_payments AS op
    GROUP BY op.order_id
),

review_features AS (
    SELECT
        order_id,

        AVG(
            CASE
                WHEN review_score > 5
                    THEN review_score::numeric / 10
                ELSE review_score::numeric
            END
        ) AS order_rating

    FROM ds_ecom.order_reviews
    GROUP BY order_id
),

product_user_features AS (
    SELECT
        u.user_id,
        u.region,

        MIN(o.order_purchase_ts) AS first_order_ts,
        MAX(o.order_purchase_ts) AS last_order_ts,

        MAX(o.order_purchase_ts)::date
            - MIN(o.order_purchase_ts)::date AS lifetime,

        COUNT(o.order_id) AS total_orders,

        ROUND(
            AVG(r.order_rating),
            2
        ) AS avg_order_rating,

        COUNT(r.order_id) AS num_orders_with_rating,

        COUNT(*) FILTER (
            WHERE o.order_status = 'Отменено'
        ) AS num_canceled_orders,

        ROUND(
            COUNT(*) FILTER (
                WHERE o.order_status = 'Отменено'
            )::numeric
            / COUNT(*),
            4
        ) AS canceled_orders_ratio,

        COALESCE(
            SUM(oc.order_cost) FILTER (
                WHERE o.order_status = 'Доставлено'
            ),
            0
        ) AS total_order_costs,

        ROUND(
            AVG(oc.order_cost) FILTER (
                WHERE o.order_status = 'Доставлено'
            ),
            2
        ) AS avg_order_cost,

        SUM(
            COALESCE(p.used_installments, 0)
        ) AS num_installment_orders,

        SUM(
            COALESCE(p.used_promo, 0)
        ) AS num_orders_with_promo,

        MAX(
            COALESCE(p.used_money_transfer, 0)
        ) AS used_money_transfer,

        MAX(
            COALESCE(p.used_installments, 0)
        ) AS used_installments,

        MAX(
            CASE
                WHEN o.order_status = 'Отменено'
                    THEN 1
                ELSE 0
            END
        ) AS used_cancel

    FROM ds_ecom.orders AS o

    JOIN ds_ecom.users AS u
        ON o.buyer_id = u.buyer_id

    JOIN top_regions AS tr
        ON u.region = tr.region

    LEFT JOIN order_costs AS oc
        ON o.order_id = oc.order_id

    LEFT JOIN payment_features AS p
        ON o.order_id = p.order_id

    LEFT JOIN review_features AS r
        ON o.order_id = r.order_id

    WHERE o.order_status IN ('Доставлено', 'Отменено')

    GROUP BY
        u.user_id,
        u.region
)

SELECT
    DATE_TRUNC(
        'month',
        first_order_ts
    )::date AS first_order_month,

    COUNT(*) AS total_clients,

    SUM(total_orders) AS total_orders,

    ROUND(
        SUM(total_order_costs)::numeric
        / NULLIF(
            SUM(total_orders - num_canceled_orders),
            0
        ),
        2
    ) AS avg_order_cost,

    ROUND(
        SUM(
            avg_order_rating * num_orders_with_rating
        )
        / NULLIF(
            SUM(num_orders_with_rating),
            0
        ),
        2
    ) AS avg_order_rating,

    ROUND(
        SUM(used_money_transfer)::numeric
        / NULLIF(COUNT(*), 0),
        4
    ) AS money_transfer_users_ratio,

    ROUND(
        AVG(lifetime)::numeric,
        2
    ) AS avg_lifetime

FROM product_user_features

WHERE first_order_ts >= DATE '2023-01-01'
  AND first_order_ts < DATE '2024-01-01'

GROUP BY
    DATE_TRUNC('month', first_order_ts)

ORDER BY
    first_order_month;

 /* Вывод:
 * В данных обнаружилась проблема: оценки записаны сразу в двух шкалах —
 * от 1 до 5 и от 10 до 50. После приведения к единой шкале средний рейтинг
 * составляет примерно 4,0–4,3.
 *
 * Число новых клиентов росло почти весь год и достигло максимума в ноябре.
 * Доля пользователей с денежными переводами оставалась стабильной —
 * около 19–22%.
 *
 * И отдельно пару слов от меня: какой мудак решил сделать такую градацию значений? Я час потратил, вырывая из головы волосы пытаясь понять в чем проблема.
 * Из-за этого средний рейтинг сначала получался около 15 вместо ожидаемых 1–5.
 */
