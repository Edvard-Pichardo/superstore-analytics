/*
Archivo      : 09_logistics_analysis.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Análisis del desempeño logístico del negocio,
               considerando modos de envío, tiempos de entrega,
               volumen comercial, rentabilidad y cobertura de datos.
*/

USE superstore_analytics;


-- Desempeño general por modo de envío
-- Comparamos los modos de envío según utilización,
-- tiempos de entrega, ventas, beneficio y rentabilidad.

-- Los pedidos cuyo modo de envío no pudo recuperarse
-- se conservan explícitamente como 'Unknown'.
WITH rendimiento_envios AS
(
    SELECT
        COALESCE(
            vos.ship_mode,
            'Unknown'
        ) AS ship_mode,
        CASE
            WHEN vos.ship_mode IS NULL THEN 1
            ELSE 0
        END AS is_unknown_ship_mode,
        COUNT(*) AS total_orders,
        COUNT(DISTINCT vos.customer_id)
            AS distinct_customers,
        SUM(vos.total_order_lines)
            AS total_order_lines,
        SUM(vos.total_sales)
            AS total_sales,
        SUM(vos.total_quantity)
            AS total_quantity,
        SUM(vos.total_profit)
            AS total_profit,
        AVG(
            CASE
                WHEN vos.unknown_sales_lines = 0
                    THEN vos.total_sales
            END
        ) AS average_complete_order_value,
        -- Margen calculado únicamente con pedidos cuyas
        -- ventas y beneficios están completamente disponibles.
        SUM(
            CASE
                WHEN vos.unknown_sales_lines = 0
                 AND vos.unknown_profit_lines = 0
                    THEN vos.total_profit
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN vos.unknown_sales_lines = 0
                     AND vos.unknown_profit_lines = 0
                        THEN vos.total_sales
                END
            ),
            0
        ) * 100 AS comparable_profit_margin_percentage,
        -- Estadísticas de tiempo de envío.
        AVG(vos.shipping_days)
            AS average_shipping_days,
        MIN(vos.shipping_days)
            AS minimum_shipping_days,
        MAX(vos.shipping_days)
            AS maximum_shipping_days,
        -- Pedidos completos cuyo beneficio fue negativo.
        SUM(
            CASE
                WHEN vos.unknown_profit_lines = 0
                 AND vos.total_profit < 0
                    THEN 1
                ELSE 0
            END
        ) AS complete_loss_making_orders,
        SUM(
            CASE
                WHEN vos.unknown_sales_lines > 0
                    THEN 1
                ELSE 0
            END
        ) AS orders_with_unknown_sales,
        SUM(
            CASE
                WHEN vos.unknown_profit_lines > 0
                    THEN 1
                ELSE 0
            END
        ) AS orders_with_unknown_profit,
        SUM(vos.unknown_sales_lines)
            AS unknown_sales_lines,
        SUM(vos.unknown_quantity_lines)
            AS unknown_quantity_lines,
        SUM(vos.unknown_profit_lines)
            AS unknown_profit_lines
    FROM vw_order_summary AS vos
    GROUP BY
        COALESCE(
            vos.ship_mode,
            'Unknown'
        ),
        CASE
            WHEN vos.ship_mode IS NULL THEN 1
            ELSE 0
        END
),

ranking_envios AS
(
    SELECT
        re.*,
        -- Participación de cada modalidad sobre los pedidos.
        100.0
        *
        re.total_orders
        /
        NULLIF(
            SUM(re.total_orders) OVER (),
            0
        ) AS order_share_percentage,
        -- Participación sobre las ventas conocidas.
        100.0
        *
        re.total_sales
        /
        NULLIF(
            SUM(re.total_sales) OVER (),
            0
        ) AS sales_share_percentage,
        -- Ranking de utilización.
        DENSE_RANK() OVER
        (
            ORDER BY re.total_orders DESC
        ) AS usage_rank,
        -- Ranking de velocidad promedio.
        DENSE_RANK() OVER
        (
            ORDER BY re.average_shipping_days ASC
        ) AS shipping_speed_rank,
        -- Ranking por ventas.
        DENSE_RANK() OVER
        (
            ORDER BY re.total_sales DESC
        ) AS sales_rank,
        -- Ranking por beneficio.
        DENSE_RANK() OVER
        (
            ORDER BY re.total_profit DESC
        ) AS profit_rank
    FROM rendimiento_envios AS re
)

SELECT
    ship_mode,
    is_unknown_ship_mode,
    total_orders,
    ROUND(
        order_share_percentage,
        2
    ) AS order_share_percentage,
    distinct_customers,
    total_order_lines,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        sales_share_percentage,
        2
    ) AS sales_share_percentage,
    total_quantity,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        average_complete_order_value,
        2
    ) AS average_complete_order_value,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    minimum_shipping_days,
    maximum_shipping_days,
    usage_rank,
    shipping_speed_rank,
    sales_rank,
    profit_rank,
    -- Diferencia entre posición por ventas y beneficio.
    CAST(profit_rank AS SIGNED)
    -
    CAST(sales_rank AS SIGNED)
        AS sales_profit_rank_gap,
    complete_loss_making_orders,
    ROUND(
        100.0
        *
        complete_loss_making_orders
        /
        NULLIF(
            total_orders
            -
            orders_with_unknown_profit,
            0
        ),
        2
    ) AS complete_loss_making_order_percentage,
    -- Cobertura de ventas.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_sales_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS sales_coverage_percentage,
    -- Cobertura de cantidades.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_quantity_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS quantity_coverage_percentage,
    -- Cobertura de beneficio.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_profit_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS profit_coverage_percentage
FROM ranking_envios
ORDER BY
    is_unknown_ship_mode,
    usage_rank,
    ship_mode;




-- Distribución de pedidos entre los modos de envío.
SELECT
    COALESCE(
        ship_mode,
        'Unknown'
    ) AS ship_mode,
    CASE
        WHEN ship_mode IS NULL THEN 1
        ELSE 0
    END AS is_unknown_ship_mode,
    COUNT(*) AS total_orders,
    ROUND(
        100.0
        *
        COUNT(*)
        /
        NULLIF(
            SUM(COUNT(*)) OVER (),
            0
        ),
        2
    ) AS order_share_percentage,
    ROUND(
        AVG(shipping_days),
        2
    ) AS average_shipping_days,
    MIN(shipping_days)
        AS minimum_shipping_days,
    MAX(shipping_days)
        AS maximum_shipping_days
FROM vw_order_summary
GROUP BY
    COALESCE(
        ship_mode,
        'Unknown'
    ),
    CASE
        WHEN ship_mode IS NULL THEN 1
        ELSE 0
    END
ORDER BY
    is_unknown_ship_mode,
    total_orders DESC,
    ship_mode;




-- Validamos que los modos de envío conserven
-- todos los pedidos del modelo.
WITH pedidos_por_modo AS
(
    SELECT
        COALESCE(
            ship_mode,
            'Unknown'
        ) AS ship_mode,
        COUNT(*) AS total_orders
    FROM vw_order_summary
    GROUP BY
        COALESCE(
            ship_mode,
            'Unknown'
        )
)

SELECT
    SUM(total_orders)
        AS orders_by_ship_mode,
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS original_orders,
    SUM(total_orders)
    -
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS order_difference
FROM pedidos_por_modo;




-- Validamos la participación total de pedidos.
WITH participacion_envios AS
(
    SELECT
        COALESCE(
            ship_mode,
            'Unknown'
        ) AS ship_mode,
        COUNT(*) AS total_orders
    FROM vw_order_summary
    GROUP BY
        COALESCE(
            ship_mode,
            'Unknown'
        )
)

SELECT
    ROUND(
        100.0
        *
        SUM(total_orders)
        /
        NULLIF(
            (
                SELECT COUNT(*)
                FROM vw_order_summary
            ),
            0
        ),
        2
    ) AS total_order_share_percentage
FROM participacion_envios;




-- Distribución de los tiempos de envío
-- Clasificamos los pedidos según los días transcurridos
-- entre la fecha del pedido y la fecha de envío.
WITH clasificacion_envios AS
(
    SELECT
        vos.order_key,
        vos.customer_id,
        vos.ship_mode,
        vos.shipping_days,
        vos.total_order_lines,
        vos.total_sales,
        vos.total_quantity,
        vos.total_profit,
        vos.unknown_sales_lines,
        vos.unknown_quantity_lines,
        vos.unknown_profit_lines,
        CASE
            WHEN vos.shipping_days = 0
                THEN 'Mismo día'
            WHEN vos.shipping_days BETWEEN 1 AND 2
                THEN '1-2 días'
            WHEN vos.shipping_days BETWEEN 3 AND 4
                THEN '3-4 días'
            WHEN vos.shipping_days BETWEEN 5 AND 7
                THEN '5-7 días'
            ELSE '8+ días'
        END AS shipping_time_group,
        CASE
            WHEN vos.shipping_days = 0 THEN 1
            WHEN vos.shipping_days BETWEEN 1 AND 2 THEN 2
            WHEN vos.shipping_days BETWEEN 3 AND 4 THEN 3
            WHEN vos.shipping_days BETWEEN 5 AND 7 THEN 4
            ELSE 5
        END AS shipping_time_order
    FROM vw_order_summary AS vos
),

rendimiento_intervalos AS
(
    SELECT
        ce.shipping_time_group,
        ce.shipping_time_order,
        MIN(ce.shipping_days)
            AS minimum_shipping_days,
        MAX(ce.shipping_days)
            AS maximum_shipping_days,
        AVG(ce.shipping_days)
            AS average_shipping_days,
        COUNT(*) AS total_orders,
        COUNT(DISTINCT ce.customer_id)
            AS distinct_customers,
        SUM(ce.total_order_lines)
            AS total_order_lines,
        SUM(ce.total_sales)
            AS total_sales,
        SUM(ce.total_quantity)
            AS total_quantity,
        SUM(ce.total_profit)
            AS total_profit,
        AVG(
            CASE
                WHEN ce.unknown_sales_lines = 0
                    THEN ce.total_sales
            END
        ) AS average_complete_order_value,
        -- Calculamos el margen únicamente con pedidos
        -- cuyas ventas y beneficios están completos.
        SUM(
            CASE
                WHEN ce.unknown_sales_lines = 0
                 AND ce.unknown_profit_lines = 0
                    THEN ce.total_profit
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN ce.unknown_sales_lines = 0
                     AND ce.unknown_profit_lines = 0
                        THEN ce.total_sales
                END
            ),
            0
        ) * 100 AS comparable_profit_margin_percentage,
        -- Contamos pedidos completos con beneficio negativo.
        SUM(
            CASE
                WHEN ce.unknown_profit_lines = 0
                 AND ce.total_profit < 0
                    THEN 1
                ELSE 0
            END
        ) AS complete_loss_making_orders,
        SUM(
            CASE
                WHEN ce.unknown_sales_lines > 0
                    THEN 1
                ELSE 0
            END
        ) AS orders_with_unknown_sales,
        SUM(
            CASE
                WHEN ce.unknown_profit_lines > 0
                    THEN 1
                ELSE 0
            END
        ) AS orders_with_unknown_profit,
        SUM(ce.unknown_sales_lines)
            AS unknown_sales_lines,
        SUM(ce.unknown_quantity_lines)
            AS unknown_quantity_lines,
        SUM(ce.unknown_profit_lines)
            AS unknown_profit_lines
    FROM clasificacion_envios AS ce
    GROUP BY
        ce.shipping_time_group,
        ce.shipping_time_order
)

SELECT
    shipping_time_group,
    minimum_shipping_days,
    maximum_shipping_days,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    total_orders,
    ROUND(
        100.0
        *
        total_orders
        /
        NULLIF(
            SUM(total_orders) OVER (),
            0
        ),
        2
    ) AS order_share_percentage,
    distinct_customers,
    total_order_lines,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        100.0
        *
        total_sales
        /
        NULLIF(
            SUM(total_sales) OVER (),
            0
        ),
        2
    ) AS sales_share_percentage,
    total_quantity,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        average_complete_order_value,
        2
    ) AS average_complete_order_value,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    complete_loss_making_orders,
    ROUND(
        100.0
        *
        complete_loss_making_orders
        /
        NULLIF(
            total_orders
            -
            orders_with_unknown_profit,
            0
        ),
        2
    ) AS complete_loss_making_order_percentage,
    -- Cobertura de ventas.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_sales_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS sales_coverage_percentage,
    -- Cobertura de cantidades.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_quantity_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS quantity_coverage_percentage,
    -- Cobertura de beneficio.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_profit_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS profit_coverage_percentage
FROM rendimiento_intervalos
ORDER BY shipping_time_order;




-- Distribución exacta de pedidos por días de envío.
SELECT
    shipping_days,
    COUNT(*) AS total_orders,
    ROUND(
        100.0
        *
        COUNT(*)
        /
        NULLIF(
            SUM(COUNT(*)) OVER (),
            0
        ),
        2
    ) AS order_share_percentage,
    ROUND(
        SUM(total_sales),
        2
    ) AS total_sales,
    ROUND(
        SUM(total_profit),
        2
    ) AS total_profit,
    ROUND(
        AVG(total_sales),
        2
    ) AS average_known_sales_per_order
FROM vw_order_summary
GROUP BY shipping_days
ORDER BY shipping_days;




-- Pedidos con tiempos de envío de ocho días o más.
SELECT
    order_key,
    order_id,
    order_date,
    ship_date,
    shipping_days,
    COALESCE(
        ship_mode,
        'Unknown'
    ) AS ship_mode,
    customer_id,
    customer_name,
    region,
    country,
    state,
    city,
    total_order_lines,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    unknown_sales_lines,
    unknown_profit_lines
FROM vw_order_summary
WHERE shipping_days >= 8
ORDER BY
    shipping_days DESC,
    order_date,
    order_key;




-- Validamos que la clasificación temporal conserve
-- todos los pedidos exactamente una vez.
WITH clasificacion_envios AS
(
    SELECT
        order_key,
        CASE
            WHEN shipping_days = 0
                THEN 'Mismo día'
            WHEN shipping_days BETWEEN 1 AND 2
                THEN '1-2 días'
            WHEN shipping_days BETWEEN 3 AND 4
                THEN '3-4 días'
            WHEN shipping_days BETWEEN 5 AND 7
                THEN '5-7 días'
            ELSE '8+ días'
        END AS shipping_time_group
    FROM vw_order_summary
)

SELECT
    COUNT(*) AS classified_orders,
    COUNT(DISTINCT order_key)
        AS unique_classified_orders,
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS original_orders,
    COUNT(*)
    -
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS order_difference,
    COUNT(*)
    -
    COUNT(DISTINCT order_key)
        AS duplicated_orders
FROM clasificacion_envios;




-- Relación entre modo de envío y tiempo real de envío
-- Cruzamos cada modalidad con los intervalos reales
-- de duración logística observados en los pedidos.
WITH clasificacion_envios AS
(
    SELECT
        vos.order_key,
        vos.customer_id,
        COALESCE(
            vos.ship_mode,
            'Unknown'
        ) AS ship_mode,
        CASE
            WHEN vos.ship_mode IS NULL THEN 1
            ELSE 0
        END AS is_unknown_ship_mode,
        vos.shipping_days,
        vos.total_order_lines,
        vos.total_sales,
        vos.total_quantity,
        vos.total_profit,
        vos.unknown_sales_lines,
        vos.unknown_quantity_lines,
        vos.unknown_profit_lines,
        CASE
            WHEN vos.shipping_days = 0
                THEN 'Mismo día'
            WHEN vos.shipping_days BETWEEN 1 AND 2
                THEN '1-2 días'
            WHEN vos.shipping_days BETWEEN 3 AND 4
                THEN '3-4 días'
            WHEN vos.shipping_days BETWEEN 5 AND 7
                THEN '5-7 días'
            ELSE '8+ días'
        END AS shipping_time_group,
        CASE
            WHEN vos.shipping_days = 0 THEN 1
            WHEN vos.shipping_days BETWEEN 1 AND 2 THEN 2
            WHEN vos.shipping_days BETWEEN 3 AND 4 THEN 3
            WHEN vos.shipping_days BETWEEN 5 AND 7 THEN 4
            ELSE 5
        END AS shipping_time_order
    FROM vw_order_summary AS vos
),

rendimiento_cruzado AS
(
    SELECT
        ce.ship_mode,
        ce.is_unknown_ship_mode,
        ce.shipping_time_group,
        ce.shipping_time_order,
        COUNT(*) AS total_orders,
        COUNT(DISTINCT ce.customer_id)
            AS distinct_customers,
        SUM(ce.total_order_lines)
            AS total_order_lines,
        SUM(ce.total_sales)
            AS total_sales,
        SUM(ce.total_quantity)
            AS total_quantity,
        SUM(ce.total_profit)
            AS total_profit,
        AVG(ce.shipping_days)
            AS average_shipping_days,
        -- Margen calculado únicamente con pedidos
        -- cuyas ventas y beneficios están completos.
        SUM(
            CASE
                WHEN ce.unknown_sales_lines = 0
                 AND ce.unknown_profit_lines = 0
                    THEN ce.total_profit
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN ce.unknown_sales_lines = 0
                     AND ce.unknown_profit_lines = 0
                        THEN ce.total_sales
                END
            ),
            0
        ) * 100 AS comparable_profit_margin_percentage,
        SUM(
            CASE
                WHEN ce.unknown_profit_lines = 0
                 AND ce.total_profit < 0
                    THEN 1
                ELSE 0
            END
        ) AS complete_loss_making_orders,
        SUM(ce.unknown_sales_lines)
            AS unknown_sales_lines,
        SUM(ce.unknown_quantity_lines)
            AS unknown_quantity_lines,
        SUM(ce.unknown_profit_lines)
            AS unknown_profit_lines
    FROM clasificacion_envios AS ce
    GROUP BY
        ce.ship_mode,
        ce.is_unknown_ship_mode,
        ce.shipping_time_group,
        ce.shipping_time_order
),

participacion AS
(
    SELECT
        rc.*,
        -- Participación del intervalo dentro de
        -- su propio modo de envío.
        100.0
        *
        rc.total_orders
        /
        NULLIF(
            SUM(rc.total_orders) OVER
            (
                PARTITION BY rc.ship_mode
            ),
            0
        ) AS within_ship_mode_order_percentage,
        -- Participación del modo dentro de cada
        -- intervalo temporal.
        100.0
        *
        rc.total_orders
        /
        NULLIF(
            SUM(rc.total_orders) OVER
            (
                PARTITION BY rc.shipping_time_group
            ),
            0
        ) AS within_time_group_order_percentage
    FROM rendimiento_cruzado AS rc
)

SELECT
    ship_mode,
    shipping_time_group,
    total_orders,
    ROUND(
        within_ship_mode_order_percentage,
        2
    ) AS within_ship_mode_order_percentage,
    ROUND(
        within_time_group_order_percentage,
        2
    ) AS within_time_group_order_percentage,
    distinct_customers,
    total_order_lines,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    total_quantity,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    complete_loss_making_orders,
    -- Cobertura de ventas.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_sales_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS sales_coverage_percentage,
    -- Cobertura de cantidades.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_quantity_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS quantity_coverage_percentage,
    -- Cobertura de beneficio.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_profit_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS profit_coverage_percentage
FROM participacion
ORDER BY
    is_unknown_ship_mode,
    ship_mode,
    shipping_time_order;




-- Distribución porcentual de tiempos dentro
-- de cada modo de envío.
WITH base_envios AS
(
    SELECT
        COALESCE(
            ship_mode,
            'Unknown'
        ) AS ship_mode,
        CASE
            WHEN ship_mode IS NULL THEN 1
            ELSE 0
        END AS is_unknown_ship_mode,
        shipping_days
    FROM vw_order_summary
)

SELECT
    ship_mode,
    COUNT(*) AS total_orders,
    ROUND(
        AVG(shipping_days),
        2
    ) AS average_shipping_days,
    MIN(shipping_days)
        AS minimum_shipping_days,
    MAX(shipping_days)
        AS maximum_shipping_days,
    SUM(
        CASE
            WHEN shipping_days = 0 THEN 1
            ELSE 0
        END
    ) AS same_day_orders,
    ROUND(
        100.0
        *
        SUM(
            CASE
                WHEN shipping_days = 0 THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0),
        2
    ) AS same_day_percentage,
    SUM(
        CASE
            WHEN shipping_days BETWEEN 1 AND 2 THEN 1
            ELSE 0
        END
    ) AS one_two_day_orders,
    ROUND(
        100.0
        *
        SUM(
            CASE
                WHEN shipping_days BETWEEN 1 AND 2 THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0),
        2
    ) AS one_two_day_percentage,
    SUM(
        CASE
            WHEN shipping_days BETWEEN 3 AND 4 THEN 1
            ELSE 0
        END
    ) AS three_four_day_orders,
    ROUND(
        100.0
        *
        SUM(
            CASE
                WHEN shipping_days BETWEEN 3 AND 4 THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0),
        2
    ) AS three_four_day_percentage,
    SUM(
        CASE
            WHEN shipping_days BETWEEN 5 AND 7 THEN 1
            ELSE 0
        END
    ) AS five_seven_day_orders,
    ROUND(
        100.0
        *
        SUM(
            CASE
                WHEN shipping_days BETWEEN 5 AND 7 THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0),
        2
    ) AS five_seven_day_percentage,
    SUM(
        CASE
            WHEN shipping_days >= 8 THEN 1
            ELSE 0
        END
    ) AS eight_plus_day_orders,
    ROUND(
        100.0
        *
        SUM(
            CASE
                WHEN shipping_days >= 8 THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0),
        2
    ) AS eight_plus_day_percentage
FROM base_envios
GROUP BY
    ship_mode,
    is_unknown_ship_mode
ORDER BY
    is_unknown_ship_mode,
    average_shipping_days,
    ship_mode;




-- Comprobamos la distribución temporal observada
-- de los pedidos clasificados como Same Day.
SELECT
    shipping_days,
    COUNT(*) AS total_orders,
    ROUND(
        100.0
        *
        COUNT(*)
        /
        NULLIF(
            SUM(COUNT(*)) OVER (),
            0
        ),
        2
    ) AS order_share_percentage
FROM vw_order_summary
WHERE ship_mode = 'Same Day'
GROUP BY shipping_days
ORDER BY shipping_days;




-- Validamos que los intervalos temporales representen
-- el 100% de los pedidos dentro de cada modo de envío.
WITH clasificacion AS
(
    SELECT
        COALESCE(
            ship_mode,
            'Unknown'
        ) AS ship_mode,
        CASE
            WHEN shipping_days = 0
                THEN 'Mismo día'
            WHEN shipping_days BETWEEN 1 AND 2
                THEN '1-2 días'
            WHEN shipping_days BETWEEN 3 AND 4
                THEN '3-4 días'
            WHEN shipping_days BETWEEN 5 AND 7
                THEN '5-7 días'
            ELSE '8+ días'
        END AS shipping_time_group
    FROM vw_order_summary
),

resumen AS
(
    SELECT
        ship_mode,
        shipping_time_group,
        COUNT(*) AS total_orders
    FROM clasificacion
    GROUP BY
        ship_mode,
        shipping_time_group
),

participacion AS
(
    SELECT
        r.*,
        100.0
        *
        r.total_orders
        /
        NULLIF(
            SUM(r.total_orders) OVER
            (
                PARTITION BY r.ship_mode
            ),
            0
        ) AS order_share_percentage
    FROM resumen AS r
)

SELECT
    ship_mode,
    SUM(total_orders) AS total_orders,
    ROUND(
        SUM(order_share_percentage),
        2
    ) AS total_percentage
FROM participacion
GROUP BY ship_mode
ORDER BY ship_mode;




-- Desempeño logístico por región
-- Comparamos los tiempos de envío de cada región contra
-- el comportamiento logístico global del negocio.
WITH referencia_global AS
(
    SELECT
        AVG(shipping_days)
            AS global_average_shipping_days
    FROM vw_order_summary
),

rendimiento_regional AS
(
    SELECT
        vos.region,
        COUNT(*) AS total_orders,
        COUNT(DISTINCT vos.customer_id)
            AS distinct_customers,
        SUM(vos.total_order_lines)
            AS total_order_lines,
        AVG(vos.shipping_days)
            AS average_shipping_days,
        MIN(vos.shipping_days)
            AS minimum_shipping_days,
        MAX(vos.shipping_days)
            AS maximum_shipping_days,
        STDDEV_POP(vos.shipping_days)
            AS shipping_days_stddev,
        -- Pedidos enviados el mismo día.
        SUM(
            CASE
                WHEN vos.shipping_days = 0 THEN 1
                ELSE 0
            END
        ) AS same_day_orders,
        -- Pedidos enviados en un máximo de dos días.
        SUM(
            CASE
                WHEN vos.shipping_days <= 2 THEN 1
                ELSE 0
            END
        ) AS two_day_or_less_orders,
        -- Pedidos con los mayores tiempos observados.
        SUM(
            CASE
                WHEN vos.shipping_days >= 8 THEN 1
                ELSE 0
            END
        ) AS eight_plus_day_orders,
        SUM(vos.total_sales)
            AS total_sales,
        SUM(vos.total_profit)
            AS total_profit,
        SUM(
            CASE
                WHEN vos.unknown_profit_lines = 0
                 AND vos.total_profit < 0
                    THEN 1
                ELSE 0
            END
        ) AS complete_loss_making_orders,
        SUM(
            CASE
                WHEN vos.unknown_profit_lines > 0
                    THEN 1
                ELSE 0
            END
        ) AS orders_with_unknown_profit,
        SUM(vos.unknown_sales_lines)
            AS unknown_sales_lines,
        SUM(vos.unknown_profit_lines)
            AS unknown_profit_lines
    FROM vw_order_summary AS vos
    GROUP BY vos.region
),

comparacion_regional AS
(
    SELECT
        rr.*,
        rg.global_average_shipping_days,
        -- Ranking desde la región más rápida
        -- hasta la región más lenta.
        DENSE_RANK() OVER
        (
            ORDER BY rr.average_shipping_days ASC
        ) AS shipping_speed_rank,
        -- Ranking según frecuencia de envíos de ocho días o más.
        DENSE_RANK() OVER
        (
            ORDER BY
                100.0
                *
                rr.eight_plus_day_orders
                /
                NULLIF(rr.total_orders, 0) DESC
        ) AS long_shipping_rank
    FROM rendimiento_regional AS rr
    CROSS JOIN referencia_global AS rg
)

SELECT
    region,
    total_orders,
    distinct_customers,
    total_order_lines,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    ROUND(
        global_average_shipping_days,
        2
    ) AS global_average_shipping_days,
    -- Diferencia respecto al promedio global.
    ROUND(
        average_shipping_days
        -
        global_average_shipping_days,
        2
    ) AS shipping_days_vs_global_average,
    minimum_shipping_days,
    maximum_shipping_days,
    ROUND(
        shipping_days_stddev,
        2
    ) AS shipping_days_stddev,
    shipping_speed_rank,
    same_day_orders,
    ROUND(
        100.0
        *
        same_day_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS same_day_percentage,
    two_day_or_less_orders,
    ROUND(
        100.0
        *
        two_day_or_less_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS two_day_or_less_percentage,
    eight_plus_day_orders,
    ROUND(
        100.0
        *
        eight_plus_day_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS eight_plus_day_percentage,
    long_shipping_rank,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    complete_loss_making_orders,
    ROUND(
        100.0
        *
        complete_loss_making_orders
        /
        NULLIF(
            total_orders
            -
            orders_with_unknown_profit,
            0
        ),
        2
    ) AS complete_loss_making_order_percentage,
    -- Cobertura de ventas.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_sales_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS sales_coverage_percentage,
    -- Cobertura de beneficio.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_profit_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS profit_coverage_percentage
FROM comparacion_regional
ORDER BY
    shipping_speed_rank,
    region;




-- Regiones cuyo tiempo promedio de envío
-- supera el promedio global del negocio.
WITH referencia_global AS
(
    SELECT
        AVG(shipping_days)
            AS global_average_shipping_days
    FROM vw_order_summary
),

rendimiento_regional AS
(
    SELECT
        region,
        COUNT(*) AS total_orders,
        AVG(shipping_days)
            AS average_shipping_days,
        STDDEV_POP(shipping_days)
            AS shipping_days_stddev,
        SUM(
            CASE
                WHEN shipping_days >= 8 THEN 1
                ELSE 0
            END
        ) AS eight_plus_day_orders,
        SUM(total_sales)
            AS total_sales,
        SUM(total_profit)
            AS total_profit
    FROM vw_order_summary
    GROUP BY region
)

SELECT
    rr.region,
    rr.total_orders,
    ROUND(
        rr.average_shipping_days,
        2
    ) AS average_shipping_days,
    ROUND(
        rg.global_average_shipping_days,
        2
    ) AS global_average_shipping_days,
    ROUND(
        rr.average_shipping_days
        -
        rg.global_average_shipping_days,
        2
    ) AS shipping_days_above_average,
    ROUND(
        rr.shipping_days_stddev,
        2
    ) AS shipping_days_stddev,
    rr.eight_plus_day_orders,
    ROUND(
        100.0
        *
        rr.eight_plus_day_orders
        /
        NULLIF(rr.total_orders, 0),
        2
    ) AS eight_plus_day_percentage,
    ROUND(
        rr.total_sales,
        2
    ) AS total_sales,
    ROUND(
        rr.total_profit,
        2
    ) AS total_profit
FROM rendimiento_regional AS rr
CROSS JOIN referencia_global AS rg
WHERE rr.average_shipping_days
      >
      rg.global_average_shipping_days
ORDER BY
    shipping_days_above_average DESC,
    rr.total_orders DESC,
    rr.region;




-- Distribución exacta de días de envío dentro
-- de cada región.
SELECT
    region,
    shipping_days,
    COUNT(*) AS total_orders,
    ROUND(
        100.0
        *
        COUNT(*)
        /
        NULLIF(
            SUM(COUNT(*)) OVER
            (
                PARTITION BY region
            ),
            0
        ),
        2
    ) AS regional_order_percentage
FROM vw_order_summary
GROUP BY
    region,
    shipping_days
ORDER BY
    region,
    shipping_days;




-- Validamos que la agregación regional conserve
-- todos los pedidos del modelo.
WITH pedidos_regionales AS
(
    SELECT
        region,
        COUNT(*) AS total_orders
    FROM vw_order_summary
    GROUP BY region
)

SELECT
    COUNT(*) AS total_regions,
    SUM(total_orders)
        AS regional_orders,
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS original_orders,
    SUM(total_orders)
    -
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS order_difference
FROM pedidos_regionales;




-- Desempeño logístico por país
-- Comparamos los países según velocidad de envío,
-- variabilidad, frecuencia de envíos largos y uso
-- de modalidades de envío desconocidas.
WITH referencia_global AS
(
    SELECT
        AVG(shipping_days)
            AS global_average_shipping_days,
        STDDEV_POP(shipping_days)
            AS global_shipping_days_stddev
    FROM vw_order_summary
),

rendimiento_paises AS
(
    SELECT
        vos.country,
        COUNT(*) AS total_orders,
        COUNT(DISTINCT vos.customer_id)
            AS distinct_customers,
        COUNT(DISTINCT vos.state)
            AS distinct_states,
        COUNT(DISTINCT vos.city)
            AS distinct_cities,
        SUM(vos.total_order_lines)
            AS total_order_lines,
        AVG(vos.shipping_days)
            AS average_shipping_days,
        MIN(vos.shipping_days)
            AS minimum_shipping_days,
        MAX(vos.shipping_days)
            AS maximum_shipping_days,
        STDDEV_POP(vos.shipping_days)
            AS shipping_days_stddev,
        SUM(
            CASE
                WHEN vos.shipping_days = 0 THEN 1
                ELSE 0
            END
        ) AS same_day_orders,
        SUM(
            CASE
                WHEN vos.shipping_days <= 2 THEN 1
                ELSE 0
            END
        ) AS two_day_or_less_orders,
        SUM(
            CASE
                WHEN vos.shipping_days >= 8 THEN 1
                ELSE 0
            END
        ) AS eight_plus_day_orders,
        SUM(
            CASE
                WHEN vos.ship_mode IS NULL THEN 1
                ELSE 0
            END
        ) AS unknown_ship_mode_orders,
        SUM(vos.total_sales)
            AS total_sales,
        SUM(vos.total_profit)
            AS total_profit,
        SUM(
            CASE
                WHEN vos.unknown_profit_lines = 0
                 AND vos.total_profit < 0
                    THEN 1
                ELSE 0
            END
        ) AS complete_loss_making_orders,
        SUM(
            CASE
                WHEN vos.unknown_profit_lines > 0
                    THEN 1
                ELSE 0
            END
        ) AS orders_with_unknown_profit,
        SUM(vos.unknown_sales_lines)
            AS unknown_sales_lines,
        SUM(vos.unknown_profit_lines)
            AS unknown_profit_lines
    FROM vw_order_summary AS vos
    GROUP BY vos.country
),

comparacion_paises AS
(
    SELECT
        rp.*,
        rg.global_average_shipping_days,
        rg.global_shipping_days_stddev,
        DENSE_RANK() OVER
        (
            ORDER BY rp.average_shipping_days ASC
        ) AS shipping_speed_rank,
        DENSE_RANK() OVER
        (
            ORDER BY rp.shipping_days_stddev ASC
        ) AS shipping_consistency_rank,
        DENSE_RANK() OVER
        (
            ORDER BY
                100.0
                *
                rp.eight_plus_day_orders
                /
                NULLIF(rp.total_orders, 0) DESC
        ) AS long_shipping_rank
    FROM rendimiento_paises AS rp
    CROSS JOIN referencia_global AS rg
)

SELECT
    country,
    total_orders,
    distinct_customers,
    distinct_states,
    distinct_cities,
    total_order_lines,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    ROUND(
        global_average_shipping_days,
        2
    ) AS global_average_shipping_days,
    -- Diferencia del país frente al promedio global.
    ROUND(
        average_shipping_days
        -
        global_average_shipping_days,
        2
    ) AS shipping_days_vs_global_average,
    minimum_shipping_days,
    maximum_shipping_days,
    ROUND(
        shipping_days_stddev,
        2
    ) AS shipping_days_stddev,
    ROUND(
        global_shipping_days_stddev,
        2
    ) AS global_shipping_days_stddev,
    shipping_speed_rank,
    shipping_consistency_rank,
    same_day_orders,
    ROUND(
        100.0
        *
        same_day_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS same_day_percentage,
    two_day_or_less_orders,
    ROUND(
        100.0
        *
        two_day_or_less_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS two_day_or_less_percentage,
    eight_plus_day_orders,
    ROUND(
        100.0
        *
        eight_plus_day_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS eight_plus_day_percentage,
    long_shipping_rank,
    unknown_ship_mode_orders,
    ROUND(
        100.0
        *
        unknown_ship_mode_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS unknown_ship_mode_percentage,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    complete_loss_making_orders,
    ROUND(
        100.0
        *
        complete_loss_making_orders
        /
        NULLIF(
            total_orders
            -
            orders_with_unknown_profit,
            0
        ),
        2
    ) AS complete_loss_making_order_percentage,
    -- Cobertura de ventas.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_sales_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS sales_coverage_percentage,
    -- Cobertura de beneficio.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_profit_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS profit_coverage_percentage
FROM comparacion_paises
ORDER BY
    shipping_speed_rank,
    country;




-- Países cuyo tiempo promedio de envío
-- supera el promedio global del negocio.
WITH referencia_global AS
(
    SELECT
        AVG(shipping_days)
            AS global_average_shipping_days
    FROM vw_order_summary
),

rendimiento_paises AS
(
    SELECT
        country,
        COUNT(*) AS total_orders,
        AVG(shipping_days)
            AS average_shipping_days,
        STDDEV_POP(shipping_days)
            AS shipping_days_stddev,
        SUM(
            CASE
                WHEN shipping_days >= 8 THEN 1
                ELSE 0
            END
        ) AS eight_plus_day_orders,
        SUM(total_sales)
            AS total_sales,
        SUM(total_profit)
            AS total_profit
    FROM vw_order_summary
    GROUP BY country
)

SELECT
    rp.country,
    rp.total_orders,
    ROUND(
        rp.average_shipping_days,
        2
    ) AS average_shipping_days,
    ROUND(
        rg.global_average_shipping_days,
        2
    ) AS global_average_shipping_days,
    ROUND(
        rp.average_shipping_days
        -
        rg.global_average_shipping_days,
        2
    ) AS shipping_days_above_average,
    ROUND(
        rp.shipping_days_stddev,
        2
    ) AS shipping_days_stddev,
    rp.eight_plus_day_orders,
    ROUND(
        100.0
        *
        rp.eight_plus_day_orders
        /
        NULLIF(rp.total_orders, 0),
        2
    ) AS eight_plus_day_percentage,
    ROUND(
        rp.total_sales,
        2
    ) AS total_sales,
    ROUND(
        rp.total_profit,
        2
    ) AS total_profit
FROM rendimiento_paises AS rp
CROSS JOIN referencia_global AS rg
WHERE rp.average_shipping_days
      >
      rg.global_average_shipping_days
ORDER BY
    shipping_days_above_average DESC,
    rp.total_orders DESC,
    rp.country;




-- Distribución exacta de días de envío
-- dentro de cada país.
SELECT
    country,
    shipping_days,
    COUNT(*) AS total_orders,
    ROUND(
        100.0
        *
        COUNT(*)
        /
        NULLIF(
            SUM(COUNT(*)) OVER
            (
                PARTITION BY country
            ),
            0
        ),
        2
    ) AS country_order_percentage
FROM vw_order_summary
GROUP BY
    country,
    shipping_days
ORDER BY
    country,
    shipping_days;




-- Distribución de modos de envío dentro
-- de cada país.
SELECT
    country,
    COALESCE(
        ship_mode,
        'Unknown'
    ) AS ship_mode,
    COUNT(*) AS total_orders,
    ROUND(
        100.0
        *
        COUNT(*)
        /
        NULLIF(
            SUM(COUNT(*)) OVER
            (
                PARTITION BY country
            ),
            0
        ),
        2
    ) AS country_ship_mode_percentage,
    ROUND(
        AVG(shipping_days),
        2
    ) AS average_shipping_days
FROM vw_order_summary
GROUP BY
    country,
    COALESCE(
        ship_mode,
        'Unknown'
    )
ORDER BY
    country,
    total_orders DESC,
    ship_mode;




-- Validamos que la agregación por país
-- conserve todos los pedidos del modelo.
WITH pedidos_paises AS
(
    SELECT
        country,
        COUNT(*) AS total_orders
    FROM vw_order_summary
    GROUP BY country
)

SELECT
    COUNT(*) AS total_countries,
    SUM(total_orders)
        AS country_orders,
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS original_orders,
    SUM(total_orders)
    -
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS order_difference
FROM pedidos_paises;




-- Evolución anual del desempeño logístico
-- Analizamos cómo cambian los tiempos de envío,
-- su variabilidad y la distribución de pedidos
-- rápidos y de larga duración entre los años.
WITH rendimiento_anual AS
(
    SELECT
        YEAR(vos.order_date)
            AS order_year,
        COUNT(*) AS total_orders,
        COUNT(DISTINCT vos.customer_id)
            AS distinct_customers,
        AVG(vos.shipping_days)
            AS average_shipping_days,
        MIN(vos.shipping_days)
            AS minimum_shipping_days,
        MAX(vos.shipping_days)
            AS maximum_shipping_days,
        STDDEV_POP(vos.shipping_days)
            AS shipping_days_stddev,
        SUM(
            CASE
                WHEN vos.shipping_days = 0 THEN 1
                ELSE 0
            END
        ) AS same_day_orders,
        SUM(
            CASE
                WHEN vos.shipping_days <= 2 THEN 1
                ELSE 0
            END
        ) AS two_day_or_less_orders,
        SUM(
            CASE
                WHEN vos.shipping_days >= 8 THEN 1
                ELSE 0
            END
        ) AS eight_plus_day_orders,
        SUM(
            CASE
                WHEN vos.ship_mode IS NULL THEN 1
                ELSE 0
            END
        ) AS unknown_ship_mode_orders,
        SUM(vos.total_sales)
            AS total_sales,
        SUM(vos.total_profit)
            AS total_profit
    FROM vw_order_summary AS vos
    GROUP BY YEAR(vos.order_date)
),

metricas_anuales AS
(
    SELECT
        ra.*,
        100.0
        *
        ra.same_day_orders
        /
        NULLIF(ra.total_orders, 0)
            AS same_day_percentage,
        100.0
        *
        ra.two_day_or_less_orders
        /
        NULLIF(ra.total_orders, 0)
            AS two_day_or_less_percentage,
        100.0
        *
        ra.eight_plus_day_orders
        /
        NULLIF(ra.total_orders, 0)
            AS eight_plus_day_percentage,
        100.0
        *
        ra.unknown_ship_mode_orders
        /
        NULLIF(ra.total_orders, 0)
            AS unknown_ship_mode_percentage
    FROM rendimiento_anual AS ra
),

comparacion_anual AS
(
    SELECT
        ma.*,
        LAG(ma.total_orders) OVER
        (
            ORDER BY ma.order_year
        ) AS previous_year_orders,
        LAG(ma.average_shipping_days) OVER
        (
            ORDER BY ma.order_year
        ) AS previous_year_average_shipping_days,
        LAG(ma.shipping_days_stddev) OVER
        (
            ORDER BY ma.order_year
        ) AS previous_year_shipping_days_stddev,
        LAG(ma.same_day_percentage) OVER
        (
            ORDER BY ma.order_year
        ) AS previous_year_same_day_percentage,
        LAG(ma.two_day_or_less_percentage) OVER
        (
            ORDER BY ma.order_year
        ) AS previous_year_two_day_or_less_percentage,
        LAG(ma.eight_plus_day_percentage) OVER
        (
            ORDER BY ma.order_year
        ) AS previous_year_eight_plus_day_percentage,
        LAG(ma.unknown_ship_mode_percentage) OVER
        (
            ORDER BY ma.order_year
        ) AS previous_year_unknown_ship_mode_percentage
    FROM metricas_anuales AS ma
)

SELECT
    order_year,
    total_orders,
    distinct_customers,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    minimum_shipping_days,
    maximum_shipping_days,
    ROUND(
        shipping_days_stddev,
        2
    ) AS shipping_days_stddev,
    same_day_orders,
    ROUND(
        same_day_percentage,
        2
    ) AS same_day_percentage,
    two_day_or_less_orders,
    ROUND(
        two_day_or_less_percentage,
        2
    ) AS two_day_or_less_percentage,
    eight_plus_day_orders,
    ROUND(
        eight_plus_day_percentage,
        2
    ) AS eight_plus_day_percentage,
    unknown_ship_mode_orders,
    ROUND(
        unknown_ship_mode_percentage,
        2
    ) AS unknown_ship_mode_percentage,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    -- Variación anual en el volumen de pedidos.
    ROUND(
        100.0
        *
        (
            total_orders
            -
            previous_year_orders
        )
        /
        NULLIF(previous_year_orders, 0),
        2
    ) AS yoy_order_growth_percentage,
    -- Un valor negativo representa una reducción
    -- del tiempo promedio de envío.
    ROUND(
        average_shipping_days
        -
        previous_year_average_shipping_days,
        2
    ) AS yoy_average_shipping_days_change,
    -- Cambio anual en la variabilidad logística.
    ROUND(
        shipping_days_stddev
        -
        previous_year_shipping_days_stddev,
        2
    ) AS yoy_shipping_stddev_change,
    -- Cambios expresados en puntos porcentuales.
    ROUND(
        same_day_percentage
        -
        previous_year_same_day_percentage,
        2
    ) AS yoy_same_day_change_points,
    ROUND(
        two_day_or_less_percentage
        -
        previous_year_two_day_or_less_percentage,
        2
    ) AS yoy_two_day_or_less_change_points,
    ROUND(
        eight_plus_day_percentage
        -
        previous_year_eight_plus_day_percentage,
        2
    ) AS yoy_eight_plus_day_change_points,
    ROUND(
        unknown_ship_mode_percentage
        -
        previous_year_unknown_ship_mode_percentage,
        2
    ) AS yoy_unknown_ship_mode_change_points
FROM comparacion_anual
ORDER BY order_year;




-- Clasificamos la evolución logística de cada año
-- respecto al año inmediatamente anterior.
WITH rendimiento_anual AS
(
    SELECT
        YEAR(order_date)
            AS order_year,
        COUNT(*) AS total_orders,
        AVG(shipping_days)
            AS average_shipping_days,
        STDDEV_POP(shipping_days)
            AS shipping_days_stddev,
        100.0
        *
        SUM(
            CASE
                WHEN shipping_days <= 2 THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0)
            AS two_day_or_less_percentage,
        100.0
        *
        SUM(
            CASE
                WHEN shipping_days >= 8 THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0)
            AS eight_plus_day_percentage
    FROM vw_order_summary
    GROUP BY YEAR(order_date)
),

comparacion AS
(
    SELECT
        ra.*,
        LAG(ra.average_shipping_days) OVER
        (
            ORDER BY ra.order_year
        ) AS previous_average_shipping_days,
        LAG(ra.shipping_days_stddev) OVER
        (
            ORDER BY ra.order_year
        ) AS previous_shipping_days_stddev,
        LAG(ra.two_day_or_less_percentage) OVER
        (
            ORDER BY ra.order_year
        ) AS previous_two_day_or_less_percentage,
        LAG(ra.eight_plus_day_percentage) OVER
        (
            ORDER BY ra.order_year
        ) AS previous_eight_plus_day_percentage
    FROM rendimiento_anual AS ra
)

SELECT
    order_year,
    total_orders,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    ROUND(
        average_shipping_days
        -
        previous_average_shipping_days,
        2
    ) AS average_shipping_days_change,
    ROUND(
        two_day_or_less_percentage,
        2
    ) AS two_day_or_less_percentage,
    ROUND(
        two_day_or_less_percentage
        -
        previous_two_day_or_less_percentage,
        2
    ) AS two_day_or_less_change_points,
    ROUND(
        eight_plus_day_percentage,
        2
    ) AS eight_plus_day_percentage,
    ROUND(
        eight_plus_day_percentage
        -
        previous_eight_plus_day_percentage,
        2
    ) AS eight_plus_day_change_points,
    ROUND(
        shipping_days_stddev,
        2
    ) AS shipping_days_stddev,
    CASE
        WHEN previous_average_shipping_days IS NULL
            THEN 'Año base'
        WHEN average_shipping_days
                < previous_average_shipping_days
         AND two_day_or_less_percentage
                > previous_two_day_or_less_percentage
         AND eight_plus_day_percentage
                < previous_eight_plus_day_percentage
            THEN 'Mejora logística consistente'
        WHEN average_shipping_days
                > previous_average_shipping_days
         AND two_day_or_less_percentage
                < previous_two_day_or_less_percentage
         AND eight_plus_day_percentage
                > previous_eight_plus_day_percentage
            THEN 'Deterioro logístico consistente'
        ELSE 'Evolución mixta'
    END AS logistics_evolution
FROM comparacion
ORDER BY order_year;




-- Evolución anual de la utilización
-- de cada modo de envío.
SELECT
    YEAR(order_date)
        AS order_year,
    COALESCE(
        ship_mode,
        'Unknown'
    ) AS ship_mode,
    COUNT(*) AS total_orders,
    ROUND(
        100.0
        *
        COUNT(*)
        /
        NULLIF(
            SUM(COUNT(*)) OVER
            (
                PARTITION BY YEAR(order_date)
            ),
            0
        ),
        2
    ) AS annual_ship_mode_percentage,
    ROUND(
        AVG(shipping_days),
        2
    ) AS average_shipping_days
FROM vw_order_summary
GROUP BY
    YEAR(order_date),
    COALESCE(
        ship_mode,
        'Unknown'
    )
ORDER BY
    order_year,
    total_orders DESC,
    ship_mode;




-- Validamos la cobertura anual del análisis logístico.
SELECT
    COUNT(
        DISTINCT YEAR(order_date)
    ) AS observed_years,
    MIN(
        YEAR(order_date)
    ) AS first_year,
    MAX(
        YEAR(order_date)
    ) AS last_year,
    COUNT(*) AS total_orders
FROM vw_order_summary;




-- Validamos que la agregación anual conserve
-- todos los pedidos del modelo.
WITH pedidos_anuales AS
(
    SELECT
        YEAR(order_date)
            AS order_year,
        COUNT(*) AS total_orders
    FROM vw_order_summary
    GROUP BY YEAR(order_date)
)

SELECT
    SUM(total_orders)
        AS annual_orders,
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS original_orders,
    SUM(total_orders)
    -
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS order_difference
FROM pedidos_anuales;




-- Evolución mensual y estacionalidad logística
-- Analizamos el comportamiento logístico de cada mes
-- observado en el periodo completo del dataset.
WITH rendimiento_mensual AS
(
    SELECT
        YEAR(vos.order_date)
            AS order_year,
        MONTH(vos.order_date)
            AS order_month,
        DATE_FORMAT(
            vos.order_date,
            '%Y-%m'
        ) AS order_year_month,
        COUNT(*) AS total_orders,
        COUNT(DISTINCT vos.customer_id)
            AS distinct_customers,
        AVG(vos.shipping_days)
            AS average_shipping_days,
        MIN(vos.shipping_days)
            AS minimum_shipping_days,
        MAX(vos.shipping_days)
            AS maximum_shipping_days,
        STDDEV_POP(vos.shipping_days)
            AS shipping_days_stddev,
        SUM(
            CASE
                WHEN vos.shipping_days = 0 THEN 1
                ELSE 0
            END
        ) AS same_day_orders,
        SUM(
            CASE
                WHEN vos.shipping_days <= 2 THEN 1
                ELSE 0
            END
        ) AS two_day_or_less_orders,
        SUM(
            CASE
                WHEN vos.shipping_days >= 8 THEN 1
                ELSE 0
            END
        ) AS eight_plus_day_orders,
        SUM(
            CASE
                WHEN vos.ship_mode IS NULL THEN 1
                ELSE 0
            END
        ) AS unknown_ship_mode_orders,
        SUM(vos.total_sales)
            AS total_sales,
        SUM(vos.total_profit)
            AS total_profit
    FROM vw_order_summary AS vos
    GROUP BY
        YEAR(vos.order_date),
        MONTH(vos.order_date),
        DATE_FORMAT(
            vos.order_date,
            '%Y-%m'
        )
),

metricas_mensuales AS
(
    SELECT
        rm.*,
        100.0
        *
        rm.same_day_orders
        /
        NULLIF(rm.total_orders, 0)
            AS same_day_percentage,
        100.0
        *
        rm.two_day_or_less_orders
        /
        NULLIF(rm.total_orders, 0)
            AS two_day_or_less_percentage,
        100.0
        *
        rm.eight_plus_day_orders
        /
        NULLIF(rm.total_orders, 0)
            AS eight_plus_day_percentage,
        100.0
        *
        rm.unknown_ship_mode_orders
        /
        NULLIF(rm.total_orders, 0)
            AS unknown_ship_mode_percentage
    FROM rendimiento_mensual AS rm
),

comparacion_mensual AS
(
    SELECT
        mm.*,
        LAG(mm.average_shipping_days) OVER
        (
            ORDER BY
                mm.order_year,
                mm.order_month
        ) AS previous_month_average_shipping_days,
        LAG(mm.two_day_or_less_percentage) OVER
        (
            ORDER BY
                mm.order_year,
                mm.order_month
        ) AS previous_month_two_day_or_less_percentage,
        LAG(mm.eight_plus_day_percentage) OVER
        (
            ORDER BY
                mm.order_year,
                mm.order_month
        ) AS previous_month_eight_plus_day_percentage
    FROM metricas_mensuales AS mm
)

SELECT
    order_year,
    order_month,
    order_year_month,
    total_orders,
    distinct_customers,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    minimum_shipping_days,
    maximum_shipping_days,
    ROUND(
        shipping_days_stddev,
        2
    ) AS shipping_days_stddev,
    same_day_orders,
    ROUND(
        same_day_percentage,
        2
    ) AS same_day_percentage,
    two_day_or_less_orders,
    ROUND(
        two_day_or_less_percentage,
        2
    ) AS two_day_or_less_percentage,
    eight_plus_day_orders,
    ROUND(
        eight_plus_day_percentage,
        2
    ) AS eight_plus_day_percentage,
    unknown_ship_mode_orders,
    ROUND(
        unknown_ship_mode_percentage,
        2
    ) AS unknown_ship_mode_percentage,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    -- Cambio frente al mes inmediatamente anterior.
    ROUND(
        average_shipping_days
        -
        previous_month_average_shipping_days,
        2
    ) AS mom_average_shipping_days_change,
    ROUND(
        two_day_or_less_percentage
        -
        previous_month_two_day_or_less_percentage,
        2
    ) AS mom_two_day_or_less_change_points,
    ROUND(
        eight_plus_day_percentage
        -
        previous_month_eight_plus_day_percentage,
        2
    ) AS mom_eight_plus_day_change_points
FROM comparacion_mensual
ORDER BY
    order_year,
    order_month;




-- Analizamos la estacionalidad logística
-- agrupando el mismo mes de distintos años.
WITH estacionalidad AS
(
    SELECT
        MONTH(order_date)
            AS calendar_month,
        CASE MONTH(order_date)
            WHEN 1 THEN 'Enero'
            WHEN 2 THEN 'Febrero'
            WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril'
            WHEN 5 THEN 'Mayo'
            WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio'
            WHEN 8 THEN 'Agosto'
            WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre'
            WHEN 11 THEN 'Noviembre'
            WHEN 12 THEN 'Diciembre'
        END AS month_name,
        COUNT(
            DISTINCT YEAR(order_date)
        ) AS observed_years,
        COUNT(*) AS total_orders,
        AVG(shipping_days)
            AS average_shipping_days,
        MIN(shipping_days)
            AS minimum_shipping_days,
        MAX(shipping_days)
            AS maximum_shipping_days,
        STDDEV_POP(shipping_days)
            AS shipping_days_stddev,
        SUM(
            CASE
                WHEN shipping_days = 0 THEN 1
                ELSE 0
            END
        ) AS same_day_orders,
        SUM(
            CASE
                WHEN shipping_days <= 2 THEN 1
                ELSE 0
            END
        ) AS two_day_or_less_orders,
        SUM(
            CASE
                WHEN shipping_days >= 8 THEN 1
                ELSE 0
            END
        ) AS eight_plus_day_orders,
        SUM(
            CASE
                WHEN ship_mode IS NULL THEN 1
                ELSE 0
            END
        ) AS unknown_ship_mode_orders
    FROM vw_order_summary
    GROUP BY
        MONTH(order_date),
        CASE MONTH(order_date)
            WHEN 1 THEN 'Enero'
            WHEN 2 THEN 'Febrero'
            WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril'
            WHEN 5 THEN 'Mayo'
            WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio'
            WHEN 8 THEN 'Agosto'
            WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre'
            WHEN 11 THEN 'Noviembre'
            WHEN 12 THEN 'Diciembre'
        END
),

ranking_estacional AS
(
    SELECT
        e.*,
        DENSE_RANK() OVER
        (
            ORDER BY e.average_shipping_days ASC
        ) AS shipping_speed_rank,
        DENSE_RANK() OVER
        (
            ORDER BY
                100.0
                *
                e.eight_plus_day_orders
                /
                NULLIF(e.total_orders, 0) DESC
        ) AS long_shipping_rank
    FROM estacionalidad AS e
)

SELECT
    calendar_month,
    month_name,
    observed_years,
    total_orders,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    minimum_shipping_days,
    maximum_shipping_days,
    ROUND(
        shipping_days_stddev,
        2
    ) AS shipping_days_stddev,
    shipping_speed_rank,
    same_day_orders,
    ROUND(
        100.0
        *
        same_day_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS same_day_percentage,
    two_day_or_less_orders,
    ROUND(
        100.0
        *
        two_day_or_less_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS two_day_or_less_percentage,
    eight_plus_day_orders,
    ROUND(
        100.0
        *
        eight_plus_day_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS eight_plus_day_percentage,
    long_shipping_rank,
    unknown_ship_mode_orders,
    ROUND(
        100.0
        *
        unknown_ship_mode_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS unknown_ship_mode_percentage
FROM ranking_estacional
ORDER BY calendar_month;




-- Ranking de meses según tiempo promedio de envío.
SELECT
    MONTH(order_date)
        AS calendar_month,
    CASE MONTH(order_date)
        WHEN 1 THEN 'Enero'
        WHEN 2 THEN 'Febrero'
        WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Mayo'
        WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio'
        WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre'
        WHEN 11 THEN 'Noviembre'
        WHEN 12 THEN 'Diciembre'
    END AS month_name,
    COUNT(*) AS total_orders,
    ROUND(
        AVG(shipping_days),
        2
    ) AS average_shipping_days,
    ROUND(
        STDDEV_POP(shipping_days),
        2
    ) AS shipping_days_stddev,
    ROUND(
        100.0
        *
        SUM(
            CASE
                WHEN shipping_days >= 8 THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0),
        2
    ) AS eight_plus_day_percentage
FROM vw_order_summary
GROUP BY
    MONTH(order_date),
    CASE MONTH(order_date)
        WHEN 1 THEN 'Enero'
        WHEN 2 THEN 'Febrero'
        WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Mayo'
        WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio'
        WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre'
        WHEN 11 THEN 'Noviembre'
        WHEN 12 THEN 'Diciembre'
    END
ORDER BY
    average_shipping_days DESC,
    eight_plus_day_percentage DESC,
    calendar_month;




-- Validamos la cobertura de los meses del calendario.
SELECT
    MONTH(order_date)
        AS calendar_month,
    COUNT(
        DISTINCT YEAR(order_date)
    ) AS observed_years,
    COUNT(*) AS total_orders
FROM vw_order_summary
GROUP BY MONTH(order_date)
ORDER BY calendar_month;




-- Validamos la cantidad de meses calendario
-- y combinaciones año-mes observadas.
SELECT
    COUNT(
        DISTINCT MONTH(order_date)
    ) AS calendar_months,
    COUNT(
        DISTINCT DATE_FORMAT(
            order_date,
            '%Y-%m'
        )
    ) AS observed_year_months
FROM vw_order_summary;




-- Relación entre tiempo de envío y desempeño comercial
-- Comparamos los intervalos logísticos según valor de pedido,
-- ventas, beneficio, margen y frecuencia de pérdidas.

-- Este análisis identifica asociaciones entre las variables;
-- no demuestra causalidad entre tiempo de envío y rentabilidad.
WITH pedidos_clasificados AS
(
    SELECT
        vos.order_key,
        vos.customer_id,
        vos.shipping_days,
        vos.total_order_lines,
        vos.total_sales,
        vos.total_quantity,
        vos.total_profit,
        vos.unknown_sales_lines,
        vos.unknown_quantity_lines,
        vos.unknown_profit_lines,
        CASE
            WHEN vos.shipping_days = 0
                THEN 'Mismo día'
            WHEN vos.shipping_days BETWEEN 1 AND 2
                THEN '1-2 días'
            WHEN vos.shipping_days BETWEEN 3 AND 4
                THEN '3-4 días'
            WHEN vos.shipping_days BETWEEN 5 AND 7
                THEN '5-7 días'
            ELSE '8+ días'
        END AS shipping_time_group,
        CASE
            WHEN vos.shipping_days = 0 THEN 1
            WHEN vos.shipping_days BETWEEN 1 AND 2 THEN 2
            WHEN vos.shipping_days BETWEEN 3 AND 4 THEN 3
            WHEN vos.shipping_days BETWEEN 5 AND 7 THEN 4
            ELSE 5
        END AS shipping_time_order
    FROM vw_order_summary AS vos
),

referencia_global AS
(
    SELECT
        AVG(
            CASE
                WHEN unknown_sales_lines = 0
                    THEN total_sales
            END
        ) AS global_average_complete_order_value,
        SUM(
            CASE
                WHEN unknown_sales_lines = 0
                 AND unknown_profit_lines = 0
                    THEN total_profit
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN unknown_sales_lines = 0
                     AND unknown_profit_lines = 0
                        THEN total_sales
                END
            ),
            0
        ) * 100
            AS global_comparable_profit_margin_percentage
    FROM pedidos_clasificados
),

rendimiento_intervalos AS
(
    SELECT
        pc.shipping_time_group,
        pc.shipping_time_order,
        COUNT(*) AS total_orders,
        COUNT(DISTINCT pc.customer_id)
            AS distinct_customers,
        SUM(pc.total_order_lines)
            AS total_order_lines,
        SUM(pc.total_sales)
            AS total_sales,
        SUM(pc.total_quantity)
            AS total_quantity,
        SUM(pc.total_profit)
            AS total_profit,
        AVG(
            CASE
                WHEN pc.unknown_sales_lines = 0
                    THEN pc.total_sales
            END
        ) AS average_complete_order_value,
        AVG(
            CASE
                WHEN pc.unknown_profit_lines = 0
                    THEN pc.total_profit
            END
        ) AS average_complete_order_profit,
        SUM(
            CASE
                WHEN pc.unknown_sales_lines = 0
                 AND pc.unknown_profit_lines = 0
                    THEN pc.total_profit
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN pc.unknown_sales_lines = 0
                     AND pc.unknown_profit_lines = 0
                        THEN pc.total_sales
                END
            ),
            0
        ) * 100
            AS comparable_profit_margin_percentage,
        SUM(
            CASE
                WHEN pc.unknown_profit_lines = 0
                 AND pc.total_profit < 0
                    THEN 1
                ELSE 0
            END
        ) AS complete_loss_making_orders,
        SUM(
            CASE
                WHEN pc.unknown_sales_lines > 0
                    THEN 1
                ELSE 0
            END
        ) AS orders_with_unknown_sales,
        SUM(
            CASE
                WHEN pc.unknown_profit_lines > 0
                    THEN 1
                ELSE 0
            END
        ) AS orders_with_unknown_profit,
        SUM(pc.unknown_sales_lines)
            AS unknown_sales_lines,
        SUM(pc.unknown_quantity_lines)
            AS unknown_quantity_lines,
        SUM(pc.unknown_profit_lines)
            AS unknown_profit_lines
    FROM pedidos_clasificados AS pc
    GROUP BY
        pc.shipping_time_group,
        pc.shipping_time_order
),

comparacion AS
(
    SELECT
        ri.*,
        rg.global_average_complete_order_value,
        rg.global_comparable_profit_margin_percentage,
        DENSE_RANK() OVER
        (
            ORDER BY ri.average_complete_order_value DESC
        ) AS average_order_value_rank,
        DENSE_RANK() OVER
        (
            ORDER BY
                ri.comparable_profit_margin_percentage DESC
        ) AS profitability_rank
    FROM rendimiento_intervalos AS ri
    CROSS JOIN referencia_global AS rg
)

SELECT
    shipping_time_group,
    total_orders,
    ROUND(
        100.0
        *
        total_orders
        /
        NULLIF(
            SUM(total_orders) OVER (),
            0
        ),
        2
    ) AS order_share_percentage,
    distinct_customers,
    total_order_lines,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    total_quantity,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        average_complete_order_value,
        2
    ) AS average_complete_order_value,
    ROUND(
        global_average_complete_order_value,
        2
    ) AS global_average_complete_order_value,
    ROUND(
        average_complete_order_value
        -
        global_average_complete_order_value,
        2
    ) AS order_value_vs_global_average,
    ROUND(
        average_complete_order_profit,
        2
    ) AS average_complete_order_profit,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    ROUND(
        global_comparable_profit_margin_percentage,
        2
    ) AS global_comparable_profit_margin_percentage,
    ROUND(
        comparable_profit_margin_percentage
        -
        global_comparable_profit_margin_percentage,
        2
    ) AS margin_vs_global_average_points,
    average_order_value_rank,
    profitability_rank,
    complete_loss_making_orders,
    ROUND(
        100.0
        *
        complete_loss_making_orders
        /
        NULLIF(
            total_orders
            -
            orders_with_unknown_profit,
            0
        ),
        2
    ) AS complete_loss_making_order_percentage,
    -- Cobertura de ventas.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_sales_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS sales_coverage_percentage,
    -- Cobertura de cantidades.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_quantity_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS quantity_coverage_percentage,
    -- Cobertura de beneficio.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_profit_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS profit_coverage_percentage
FROM comparacion
ORDER BY shipping_time_order;




-- Analizamos ventas y rentabilidad para cada
-- duración exacta de envío observada.
SELECT
    shipping_days,
    COUNT(*) AS total_orders,
    ROUND(
        100.0
        *
        COUNT(*)
        /
        NULLIF(
            SUM(COUNT(*)) OVER (),
            0
        ),
        2
    ) AS order_share_percentage,
    ROUND(
        AVG(
            CASE
                WHEN unknown_sales_lines = 0
                    THEN total_sales
            END
        ),
        2
    ) AS average_complete_order_value,
    ROUND(
        AVG(
            CASE
                WHEN unknown_profit_lines = 0
                    THEN total_profit
            END
        ),
        2
    ) AS average_complete_order_profit,
    ROUND(
        SUM(
            CASE
                WHEN unknown_sales_lines = 0
                 AND unknown_profit_lines = 0
                    THEN total_profit
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN unknown_sales_lines = 0
                     AND unknown_profit_lines = 0
                        THEN total_sales
                END
            ),
            0
        ) * 100,
        2
    ) AS comparable_profit_margin_percentage,
    SUM(
        CASE
            WHEN unknown_profit_lines = 0
             AND total_profit < 0
                THEN 1
            ELSE 0
        END
    ) AS complete_loss_making_orders,
    ROUND(
        100.0
        *
        SUM(
            CASE
                WHEN unknown_profit_lines = 0
                 AND total_profit < 0
                    THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN unknown_profit_lines = 0
                        THEN 1
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS complete_loss_making_order_percentage
FROM vw_order_summary
GROUP BY shipping_days
ORDER BY shipping_days;




-- Comparamos pedidos de hasta dos días contra
-- pedidos con tiempos de ocho días o más.
WITH extremos_logisticos AS
(
    SELECT
        CASE
            WHEN shipping_days <= 2
                THEN '0-2 días'
            WHEN shipping_days >= 8
                THEN '8+ días'
        END AS logistics_group,
        total_sales,
        total_profit,
        unknown_sales_lines,
        unknown_profit_lines
    FROM vw_order_summary
    WHERE shipping_days <= 2
       OR shipping_days >= 8
)

SELECT
    logistics_group,
    COUNT(*) AS total_orders,
    ROUND(
        AVG(
            CASE
                WHEN unknown_sales_lines = 0
                    THEN total_sales
            END
        ),
        2
    ) AS average_complete_order_value,
    ROUND(
        AVG(
            CASE
                WHEN unknown_profit_lines = 0
                    THEN total_profit
            END
        ),
        2
    ) AS average_complete_order_profit,
    ROUND(
        SUM(
            CASE
                WHEN unknown_sales_lines = 0
                 AND unknown_profit_lines = 0
                    THEN total_profit
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN unknown_sales_lines = 0
                     AND unknown_profit_lines = 0
                        THEN total_sales
                END
            ),
            0
        ) * 100,
        2
    ) AS comparable_profit_margin_percentage,
    ROUND(
        100.0
        *
        SUM(
            CASE
                WHEN unknown_profit_lines = 0
                 AND total_profit < 0
                    THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN unknown_profit_lines = 0
                        THEN 1
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS complete_loss_making_order_percentage
FROM extremos_logisticos
GROUP BY logistics_group
ORDER BY
    CASE logistics_group
        WHEN '0-2 días' THEN 1
        ELSE 2
    END;




-- Validamos que todos los pedidos pertenezcan
-- exactamente a un intervalo logístico.
WITH clasificacion AS
(
    SELECT
        order_key,
        CASE
            WHEN shipping_days = 0
                THEN 'Mismo día'
            WHEN shipping_days BETWEEN 1 AND 2
                THEN '1-2 días'
            WHEN shipping_days BETWEEN 3 AND 4
                THEN '3-4 días'
            WHEN shipping_days BETWEEN 5 AND 7
                THEN '5-7 días'
            ELSE '8+ días'
        END AS shipping_time_group
    FROM vw_order_summary
)

SELECT
    COUNT(*) AS classified_orders,
    COUNT(DISTINCT order_key)
        AS unique_orders,
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS original_orders,
    COUNT(*)
    -
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS order_difference,
    COUNT(*)
    -
    COUNT(DISTINCT order_key)
        AS duplicated_orders
FROM clasificacion;




-- Relación entre modo de envío y región
-- Comparamos el desempeño de una misma modalidad
-- entre las distintas regiones del negocio.
WITH referencia_modalidad AS
(
    SELECT
        COALESCE(
            ship_mode,
            'Unknown'
        ) AS ship_mode,
        AVG(shipping_days)
            AS ship_mode_average_shipping_days
    FROM vw_order_summary
    GROUP BY
        COALESCE(
            ship_mode,
            'Unknown'
        )
),

rendimiento_region_modalidad AS
(
    SELECT
        vos.region,
        COALESCE(
            vos.ship_mode,
            'Unknown'
        ) AS ship_mode,
        CASE
            WHEN vos.ship_mode IS NULL THEN 1
            ELSE 0
        END AS is_unknown_ship_mode,
        COUNT(*) AS total_orders,
        COUNT(DISTINCT vos.customer_id)
            AS distinct_customers,
        SUM(vos.total_order_lines)
            AS total_order_lines,
        AVG(vos.shipping_days)
            AS average_shipping_days,
        MIN(vos.shipping_days)
            AS minimum_shipping_days,
        MAX(vos.shipping_days)
            AS maximum_shipping_days,
        STDDEV_POP(vos.shipping_days)
            AS shipping_days_stddev,
        SUM(
            CASE
                WHEN vos.shipping_days = 0 THEN 1
                ELSE 0
            END
        ) AS same_day_orders,
        SUM(
            CASE
                WHEN vos.shipping_days <= 2 THEN 1
                ELSE 0
            END
        ) AS two_day_or_less_orders,
        SUM(
            CASE
                WHEN vos.shipping_days >= 8 THEN 1
                ELSE 0
            END
        ) AS eight_plus_day_orders,
        SUM(vos.total_sales)
            AS total_sales,
        SUM(vos.total_quantity)
            AS total_quantity,
        SUM(vos.total_profit)
            AS total_profit,
        -- Margen calculado con pedidos cuyas ventas
        -- y beneficios están completamente disponibles.
        SUM(
            CASE
                WHEN vos.unknown_sales_lines = 0
                 AND vos.unknown_profit_lines = 0
                    THEN vos.total_profit
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN vos.unknown_sales_lines = 0
                     AND vos.unknown_profit_lines = 0
                        THEN vos.total_sales
                END
            ),
            0
        ) * 100 AS comparable_profit_margin_percentage,
        SUM(
            CASE
                WHEN vos.unknown_profit_lines = 0
                 AND vos.total_profit < 0
                    THEN 1
                ELSE 0
            END
        ) AS complete_loss_making_orders,
        SUM(
            CASE
                WHEN vos.unknown_profit_lines > 0
                    THEN 1
                ELSE 0
            END
        ) AS orders_with_unknown_profit,
        SUM(vos.unknown_sales_lines)
            AS unknown_sales_lines,
        SUM(vos.unknown_quantity_lines)
            AS unknown_quantity_lines,
        SUM(vos.unknown_profit_lines)
            AS unknown_profit_lines
    FROM vw_order_summary AS vos
    GROUP BY
        vos.region,
        COALESCE(
            vos.ship_mode,
            'Unknown'
        ),
        CASE
            WHEN vos.ship_mode IS NULL THEN 1
            ELSE 0
        END
),

comparacion AS
(
    SELECT
        rrm.*,
        rm.ship_mode_average_shipping_days,
        -- Participación de la modalidad dentro
        -- de la región correspondiente.
        100.0
        *
        rrm.total_orders
        /
        NULLIF(
            SUM(rrm.total_orders) OVER
            (
                PARTITION BY rrm.region
            ),
            0
        ) AS regional_ship_mode_percentage,
        -- Participación de la región dentro de
        -- todos los pedidos de esa modalidad.
        100.0
        *
        rrm.total_orders
        /
        NULLIF(
            SUM(rrm.total_orders) OVER
            (
                PARTITION BY rrm.ship_mode
            ),
            0
        ) AS ship_mode_region_percentage,
        -- Ranking regional para una misma modalidad.
        DENSE_RANK() OVER
        (
            PARTITION BY rrm.ship_mode
            ORDER BY rrm.average_shipping_days ASC
        ) AS regional_speed_rank_within_ship_mode
    FROM rendimiento_region_modalidad AS rrm
    INNER JOIN referencia_modalidad AS rm
        ON rm.ship_mode = rrm.ship_mode
)

SELECT
    region,
    ship_mode,
    is_unknown_ship_mode,
    total_orders,
    ROUND(
        regional_ship_mode_percentage,
        2
    ) AS regional_ship_mode_percentage,
    ROUND(
        ship_mode_region_percentage,
        2
    ) AS ship_mode_region_percentage,
    distinct_customers,
    total_order_lines,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    ROUND(
        ship_mode_average_shipping_days,
        2
    ) AS ship_mode_average_shipping_days,
    -- Diferencia respecto al promedio global
    -- de la misma modalidad.
    ROUND(
        average_shipping_days
        -
        ship_mode_average_shipping_days,
        2
    ) AS shipping_days_vs_ship_mode_average,
    minimum_shipping_days,
    maximum_shipping_days,
    ROUND(
        shipping_days_stddev,
        2
    ) AS shipping_days_stddev,
    regional_speed_rank_within_ship_mode,
    same_day_orders,
    ROUND(
        100.0
        *
        same_day_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS same_day_percentage,
    two_day_or_less_orders,
    ROUND(
        100.0
        *
        two_day_or_less_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS two_day_or_less_percentage,
    eight_plus_day_orders,
    ROUND(
        100.0
        *
        eight_plus_day_orders
        /
        NULLIF(total_orders, 0),
        2
    ) AS eight_plus_day_percentage,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    total_quantity,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    complete_loss_making_orders,
    ROUND(
        100.0
        *
        complete_loss_making_orders
        /
        NULLIF(
            total_orders
            -
            orders_with_unknown_profit,
            0
        ),
        2
    ) AS complete_loss_making_order_percentage,
    -- Cobertura de ventas.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_sales_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS sales_coverage_percentage,
    -- Cobertura de cantidades.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_quantity_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS quantity_coverage_percentage,
    -- Cobertura de beneficio.
    ROUND(
        100.0
        *
        (
            total_order_lines
            -
            unknown_profit_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS profit_coverage_percentage
FROM comparacion
ORDER BY
    is_unknown_ship_mode,
    ship_mode,
    regional_speed_rank_within_ship_mode,
    region;




-- Detectamos combinaciones región-modalidad cuyo tiempo
-- promedio supera al promedio global de esa modalidad.
WITH referencia_modalidad AS
(
    SELECT
        COALESCE(
            ship_mode,
            'Unknown'
        ) AS ship_mode,
        AVG(shipping_days)
            AS ship_mode_average_shipping_days
    FROM vw_order_summary
    GROUP BY
        COALESCE(
            ship_mode,
            'Unknown'
        )
),

rendimiento AS
(
    SELECT
        region,
        COALESCE(
            ship_mode,
            'Unknown'
        ) AS ship_mode,
        COUNT(*) AS total_orders,
        AVG(shipping_days)
            AS average_shipping_days,
        STDDEV_POP(shipping_days)
            AS shipping_days_stddev,
        SUM(
            CASE
                WHEN shipping_days >= 8 THEN 1
                ELSE 0
            END
        ) AS eight_plus_day_orders
    FROM vw_order_summary
    GROUP BY
        region,
        COALESCE(
            ship_mode,
            'Unknown'
        )
)

SELECT
    r.region,
    r.ship_mode,
    r.total_orders,
    ROUND(
        r.average_shipping_days,
        2
    ) AS average_shipping_days,
    ROUND(
        rm.ship_mode_average_shipping_days,
        2
    ) AS ship_mode_average_shipping_days,
    ROUND(
        r.average_shipping_days
        -
        rm.ship_mode_average_shipping_days,
        2
    ) AS shipping_days_above_ship_mode_average,
    ROUND(
        r.shipping_days_stddev,
        2
    ) AS shipping_days_stddev,
    r.eight_plus_day_orders,
    ROUND(
        100.0
        *
        r.eight_plus_day_orders
        /
        NULLIF(r.total_orders, 0),
        2
    ) AS eight_plus_day_percentage
FROM rendimiento AS r
INNER JOIN referencia_modalidad AS rm
    ON rm.ship_mode = r.ship_mode
WHERE r.average_shipping_days
      >
      rm.ship_mode_average_shipping_days
ORDER BY
    shipping_days_above_ship_mode_average DESC,
    r.total_orders DESC,
    r.ship_mode,
    r.region;




-- Comparamos el tiempo de una misma modalidad
-- entre los distintos países.
WITH referencia_modalidad AS
(
    SELECT
        COALESCE(
            ship_mode,
            'Unknown'
        ) AS ship_mode,
        AVG(shipping_days)
            AS ship_mode_average_shipping_days
    FROM vw_order_summary
    GROUP BY
        COALESCE(
            ship_mode,
            'Unknown'
        )
),

rendimiento_pais_modalidad AS
(
    SELECT
        country,
        COALESCE(
            ship_mode,
            'Unknown'
        ) AS ship_mode,
        COUNT(*) AS total_orders,
        AVG(shipping_days)
            AS average_shipping_days,
        STDDEV_POP(shipping_days)
            AS shipping_days_stddev,
        SUM(
            CASE
                WHEN shipping_days <= 2 THEN 1
                ELSE 0
            END
        ) AS two_day_or_less_orders,
        SUM(
            CASE
                WHEN shipping_days >= 8 THEN 1
                ELSE 0
            END
        ) AS eight_plus_day_orders
    FROM vw_order_summary
    GROUP BY
        country,
        COALESCE(
            ship_mode,
            'Unknown'
        )
)

SELECT
    rpm.country,
    rpm.ship_mode,
    rpm.total_orders,
    ROUND(
        rpm.average_shipping_days,
        2
    ) AS average_shipping_days,
    ROUND(
        rm.ship_mode_average_shipping_days,
        2
    ) AS ship_mode_average_shipping_days,
    ROUND(
        rpm.average_shipping_days
        -
        rm.ship_mode_average_shipping_days,
        2
    ) AS shipping_days_vs_ship_mode_average,
    ROUND(
        rpm.shipping_days_stddev,
        2
    ) AS shipping_days_stddev,
    ROUND(
        100.0
        *
        rpm.two_day_or_less_orders
        /
        NULLIF(rpm.total_orders, 0),
        2
    ) AS two_day_or_less_percentage,
    ROUND(
        100.0
        *
        rpm.eight_plus_day_orders
        /
        NULLIF(rpm.total_orders, 0),
        2
    ) AS eight_plus_day_percentage,
    DENSE_RANK() OVER
    (
        PARTITION BY rpm.ship_mode
        ORDER BY rpm.average_shipping_days ASC
    ) AS country_speed_rank_within_ship_mode
FROM rendimiento_pais_modalidad AS rpm
INNER JOIN referencia_modalidad AS rm
    ON rm.ship_mode = rpm.ship_mode
ORDER BY
    rpm.ship_mode,
    country_speed_rank_within_ship_mode,
    rpm.country;




-- Matriz de tiempo promedio por región
-- y modo de envío.
SELECT
    region,
    ROUND(
        AVG(
            CASE
                WHEN ship_mode = 'Same Day'
                    THEN shipping_days
            END
        ),
        2
    ) AS same_day_average_days,
    ROUND(
        AVG(
            CASE
                WHEN ship_mode = 'First Class'
                    THEN shipping_days
            END
        ),
        2
    ) AS first_class_average_days,
    ROUND(
        AVG(
            CASE
                WHEN ship_mode = 'Second Class'
                    THEN shipping_days
            END
        ),
        2
    ) AS second_class_average_days,
    ROUND(
        AVG(
            CASE
                WHEN ship_mode = 'Standard Class'
                    THEN shipping_days
            END
        ),
        2
    ) AS standard_class_average_days,
    ROUND(
        AVG(
            CASE
                WHEN ship_mode IS NULL
                    THEN shipping_days
            END
        ),
        2
    ) AS unknown_average_days
FROM vw_order_summary
GROUP BY region
ORDER BY region;




-- Validamos que la combinación región-modalidad
-- conserve todos los pedidos del modelo.
WITH region_modalidad AS
(
    SELECT
        region,
        COALESCE(
            ship_mode,
            'Unknown'
        ) AS ship_mode,
        COUNT(*) AS total_orders
    FROM vw_order_summary
    GROUP BY
        region,
        COALESCE(
            ship_mode,
            'Unknown'
        )
)
SELECT
    COUNT(*) AS observed_region_ship_mode_combinations,
    SUM(total_orders)
        AS classified_orders,
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS original_orders,
    SUM(total_orders)
    -
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS order_difference
FROM region_modalidad;




-- Validación y conciliación logística global
-- Comprobamos que las principales dimensiones utilizadas
-- durante el análisis reproduzcan los totales del negocio.
WITH referencia_global AS
(
    SELECT
        COUNT(*) AS total_orders,
        SUM(total_order_lines)
            AS total_order_lines,
        SUM(total_sales)
            AS total_sales,
        SUM(total_quantity)
            AS total_quantity,
        SUM(total_profit)
            AS total_profit
    FROM vw_order_summary
),

por_modo_envio AS
(
    SELECT
        COALESCE(
            ship_mode,
            'Unknown'
        ) AS logistics_group,
        COUNT(*) AS total_orders,
        SUM(total_order_lines)
            AS total_order_lines,
        SUM(total_sales)
            AS total_sales,
        SUM(total_quantity)
            AS total_quantity,
        SUM(total_profit)
            AS total_profit
    FROM vw_order_summary
    GROUP BY
        COALESCE(
            ship_mode,
            'Unknown'
        )
),

por_intervalo AS
(
    SELECT
        CASE
            WHEN shipping_days = 0
                THEN 'Mismo día'
            WHEN shipping_days BETWEEN 1 AND 2
                THEN '1-2 días'
            WHEN shipping_days BETWEEN 3 AND 4
                THEN '3-4 días'
            WHEN shipping_days BETWEEN 5 AND 7
                THEN '5-7 días'
            ELSE '8+ días'
        END AS logistics_group,
        COUNT(*) AS total_orders,
        SUM(total_order_lines)
            AS total_order_lines,
        SUM(total_sales)
            AS total_sales,
        SUM(total_quantity)
            AS total_quantity,
        SUM(total_profit)
            AS total_profit
    FROM vw_order_summary
    GROUP BY
        CASE
            WHEN shipping_days = 0
                THEN 'Mismo día'
            WHEN shipping_days BETWEEN 1 AND 2
                THEN '1-2 días'
            WHEN shipping_days BETWEEN 3 AND 4
                THEN '3-4 días'
            WHEN shipping_days BETWEEN 5 AND 7
                THEN '5-7 días'
            ELSE '8+ días'
        END
),

por_region AS
(
    SELECT
        region AS logistics_group,
        COUNT(*) AS total_orders,
        SUM(total_order_lines)
            AS total_order_lines,
        SUM(total_sales)
            AS total_sales,
        SUM(total_quantity)
            AS total_quantity,
        SUM(total_profit)
            AS total_profit
    FROM vw_order_summary
    GROUP BY region
),

por_pais AS
(
    SELECT
        country AS logistics_group,
        COUNT(*) AS total_orders,
        SUM(total_order_lines)
            AS total_order_lines,
        SUM(total_sales)
            AS total_sales,
        SUM(total_quantity)
            AS total_quantity,
        SUM(total_profit)
            AS total_profit
    FROM vw_order_summary
    GROUP BY country
),

por_anio AS
(
    SELECT
        YEAR(order_date)
            AS order_year,
        COUNT(*) AS total_orders,
        SUM(total_order_lines)
            AS total_order_lines,
        SUM(total_sales)
            AS total_sales,
        SUM(total_quantity)
            AS total_quantity,
        SUM(total_profit)
            AS total_profit
    FROM vw_order_summary
    GROUP BY YEAR(order_date)
),

resumen_niveles AS
(
    SELECT
        'Ship Mode' AS analysis_level,
        COUNT(*) AS observed_groups,
        SUM(total_orders)
            AS total_orders,
        SUM(total_order_lines)
            AS total_order_lines,
        SUM(total_sales)
            AS total_sales,
        SUM(total_quantity)
            AS total_quantity,
        SUM(total_profit)
            AS total_profit
    FROM por_modo_envio

    UNION ALL

    SELECT
        'Shipping Time Group',
        COUNT(*),
        SUM(total_orders),
        SUM(total_order_lines),
        SUM(total_sales),
        SUM(total_quantity),
        SUM(total_profit)
    FROM por_intervalo

    UNION ALL

    SELECT
        'Region',
        COUNT(*),
        SUM(total_orders),
        SUM(total_order_lines),
        SUM(total_sales),
        SUM(total_quantity),
        SUM(total_profit)
    FROM por_region

    UNION ALL

    SELECT
        'Country',
        COUNT(*),
        SUM(total_orders),
        SUM(total_order_lines),
        SUM(total_sales),
        SUM(total_quantity),
        SUM(total_profit)
    FROM por_pais

    UNION ALL

    SELECT
        'Year',
        COUNT(*),
        SUM(total_orders),
        SUM(total_order_lines),
        SUM(total_sales),
        SUM(total_quantity),
        SUM(total_profit)
    FROM por_anio
)

SELECT
    rn.analysis_level,
    rn.observed_groups,
    rn.total_orders,
    rg.total_orders
        AS global_orders,
    rn.total_orders
    -
    rg.total_orders
        AS order_difference,
    rn.total_order_lines,
    rg.total_order_lines
        AS global_order_lines,
    rn.total_order_lines
    -
    rg.total_order_lines
        AS order_line_difference,
    ROUND(
        rn.total_sales,
        6
    ) AS total_sales,
    ROUND(
        rg.total_sales,
        6
    ) AS global_sales,
    ROUND(
        rn.total_sales
        -
        rg.total_sales,
        6
    ) AS sales_difference,
    rn.total_quantity,
    rg.total_quantity
        AS global_quantity,
    rn.total_quantity
    -
    rg.total_quantity
        AS quantity_difference,
    ROUND(
        rn.total_profit,
        6
    ) AS total_profit,
    ROUND(
        rg.total_profit,
        6
    ) AS global_profit,
    ROUND(
        rn.total_profit
        -
        rg.total_profit,
        6
    ) AS profit_difference
FROM resumen_niveles AS rn
CROSS JOIN referencia_global AS rg
ORDER BY
    CASE rn.analysis_level
        WHEN 'Ship Mode' THEN 1
        WHEN 'Shipping Time Group' THEN 2
        WHEN 'Region' THEN 3
        WHEN 'Country' THEN 4
        WHEN 'Year' THEN 5
    END;




-- Validamos la coherencia entre las fechas
-- y el tiempo de envío calculado.
SELECT
    COUNT(*) AS total_orders,
    SUM(
        CASE
            WHEN ship_date < order_date THEN 1
            ELSE 0
        END
    ) AS orders_with_invalid_dates,
    SUM(
        CASE
            WHEN shipping_days < 0 THEN 1
            ELSE 0
        END
    ) AS orders_with_negative_shipping_days,
    SUM(
        CASE
            WHEN shipping_days
                 <>
                 DATEDIFF(
                     ship_date,
                     order_date
                 )
                THEN 1
            ELSE 0
        END
    ) AS shipping_day_mismatches,
    MIN(shipping_days)
        AS minimum_shipping_days,
    MAX(shipping_days)
        AS maximum_shipping_days,
    ROUND(
        AVG(shipping_days),
        2
    ) AS average_shipping_days
FROM vw_order_summary;




-- Verificamos los modos de envío conocidos
-- y contabilizamos los valores desconocidos.
WITH resumen_modos_envio AS
(
    SELECT
        COALESCE(
            ship_mode,
            'Unknown'
        ) AS normalized_ship_mode,
        COUNT(*) AS total_orders
    FROM vw_order_summary
    GROUP BY
        COALESCE(
            ship_mode,
            'Unknown'
        )
),

participacion_modos_envio AS
(
    SELECT
        normalized_ship_mode,
        total_orders,
        100.0
        *
        total_orders
        /
        NULLIF(
            SUM(total_orders) OVER (),
            0
        ) AS order_share_percentage
    FROM resumen_modos_envio
)

SELECT
    normalized_ship_mode AS ship_mode,
    total_orders,
    ROUND(
        order_share_percentage,
        2
    ) AS order_share_percentage
FROM participacion_modos_envio
ORDER BY
    CASE normalized_ship_mode
        WHEN 'Standard Class' THEN 1
        WHEN 'Second Class' THEN 2
        WHEN 'First Class' THEN 3
        WHEN 'Same Day' THEN 4
        WHEN 'Unknown' THEN 5
        ELSE 6
    END,
    normalized_ship_mode;




-- Resumen ejecutivo final del desempeño logístico.
SELECT
    COUNT(*) AS total_orders,
    ROUND(
        AVG(shipping_days),
        2
    ) AS average_shipping_days,
    MIN(shipping_days)
        AS minimum_shipping_days,
    MAX(shipping_days)
        AS maximum_shipping_days,
    ROUND(
        STDDEV_POP(shipping_days),
        2
    ) AS shipping_days_stddev,
    SUM(
        CASE
            WHEN shipping_days = 0 THEN 1
            ELSE 0
        END
    ) AS same_day_orders,
    ROUND(
        100.0
        *
        SUM(
            CASE
                WHEN shipping_days = 0 THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0),
        2
    ) AS same_day_percentage,
    SUM(
        CASE
            WHEN shipping_days <= 2 THEN 1
            ELSE 0
        END
    ) AS two_day_or_less_orders,
    ROUND(
        100.0
        *
        SUM(
            CASE
                WHEN shipping_days <= 2 THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0),
        2
    ) AS two_day_or_less_percentage,
    SUM(
        CASE
            WHEN shipping_days >= 8 THEN 1
            ELSE 0
        END
    ) AS eight_plus_day_orders,
    ROUND(
        100.0
        *
        SUM(
            CASE
                WHEN shipping_days >= 8 THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0),
        2
    ) AS eight_plus_day_percentage,
    SUM(
        CASE
            WHEN ship_mode IS NULL THEN 1
            ELSE 0
        END
    ) AS unknown_ship_mode_orders,
    ROUND(
        100.0
        *
        SUM(
            CASE
                WHEN ship_mode IS NULL THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0),
        2
    ) AS unknown_ship_mode_percentage,
    ROUND(
        SUM(total_sales),
        2
    ) AS total_sales,
    ROUND(
        SUM(total_profit),
        2
    ) AS total_profit
FROM vw_order_summary;




-- Validamos el periodo temporal utilizado
-- durante todo el análisis logístico.
SELECT
    MIN(order_date)
        AS first_order_date,
    MAX(order_date)
        AS last_order_date,
    COUNT(
        DISTINCT YEAR(order_date)
    ) AS observed_years,
    COUNT(
        DISTINCT DATE_FORMAT(
            order_date,
            '%Y-%m'
        )
    ) AS observed_year_months
FROM vw_order_summary;




