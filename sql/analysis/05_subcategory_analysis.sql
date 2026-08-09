/*
Archivo      : 05_subcategory_analysis.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Análisis comparativo del desempeño de las
               subcategorías de productos, considerando
               ventas, beneficio, margen, participación
               y cobertura de información.
*/

USE superstore_analytics;

-- Comparación y ranking de subcategorías
-- Comparamos las subcategorías del negocio según:
-- 1. Ventas conocidas.
-- 2. Beneficio conocido.
-- 3. Margen comparable.
-- 4. Participación dentro del negocio.
-- 5. Participación dentro de su propia categoría.

-- También conservamos indicadores de cobertura para
-- interpretar correctamente las métricas obtenidas.
WITH comparacion_subcategorias AS
(
    SELECT
        vsp.category,
        vsp.sub_category,
        -- Actividad comercial.
        vsp.total_orders,
        vsp.total_order_lines,
        vsp.distinct_customers,
        vsp.distinct_products,
        -- Métricas comerciales.
        vsp.total_sales,
        vsp.total_quantity,
        vsp.total_profit,
        vsp.average_line_discount,
        vsp.comparable_profit_margin_percentage,
        -- Pérdidas.
        vsp.loss_making_lines,
        -- Cobertura.
        vsp.unknown_sales_lines,
        vsp.unknown_quantity_lines,
        vsp.unknown_profit_lines,
        -- Participación global
        -- Participación de la subcategoría sobre todas
        -- las ventas conocidas del negocio.
        100.0
        *
        vsp.total_sales
        /
        NULLIF(
            SUM(vsp.total_sales) OVER (),
            0
        ) AS global_sales_share_percentage,
        -- Participación sobre el beneficio total conocido.
        100.0
        *
        vsp.total_profit
        /
        NULLIF(
            SUM(vsp.total_profit) OVER (),
            0
        ) AS global_profit_share_percentage,
        -- Participación dentro de la categoría
        100.0
        *
        vsp.total_sales
        /
        NULLIF(
            SUM(vsp.total_sales) OVER (
                PARTITION BY vsp.category
            ),
            0
        ) AS category_sales_share_percentage,
        -- Rankings globales
        DENSE_RANK() OVER (
            ORDER BY vsp.total_sales DESC
        ) AS global_sales_rank,

        DENSE_RANK() OVER (
            ORDER BY vsp.total_profit DESC
        ) AS global_profit_rank,

        DENSE_RANK() OVER (
            ORDER BY
                vsp.comparable_profit_margin_percentage DESC
        ) AS global_margin_rank,
        -- Ranking dentro de cada categoría
        DENSE_RANK() OVER (
            PARTITION BY vsp.category
            ORDER BY vsp.total_sales DESC
        ) AS category_sales_rank

    FROM vw_subcategory_performance AS vsp
)

SELECT
    category,
    sub_category,

    total_orders,
    total_order_lines,
    distinct_customers,
    distinct_products,

    ROUND(total_sales, 2)
        AS total_sales,

    total_quantity,

    ROUND(total_profit, 2)
        AS total_profit,

    ROUND(
        average_line_discount,
        4
    ) AS average_line_discount,

    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    -- Participación global.
    ROUND(
        global_sales_share_percentage,
        2
    ) AS global_sales_share_percentage,

    ROUND(
        global_profit_share_percentage,
        2
    ) AS global_profit_share_percentage,
    -- Participación dentro de la categoría.
    ROUND(
        category_sales_share_percentage,
        2
    ) AS category_sales_share_percentage,
    -- Rankings.
    global_sales_rank,
    global_profit_rank,
    global_margin_rank,
    category_sales_rank,
    -- Diferencia entre ranking de ventas y beneficio.
    -- Se convierten a SIGNED porque DENSE_RANK()
    -- devuelve valores BIGINT UNSIGNED.
    CAST(global_profit_rank AS SIGNED)
    -
    CAST(global_sales_rank AS SIGNED)
        AS sales_profit_rank_gap,
    -- Líneas con pérdidas.
    loss_making_lines,

    ROUND(
        100.0
        *
        loss_making_lines
        /
        NULLIF(
            total_order_lines - unknown_profit_lines,
            0
        ),
        2
    ) AS known_loss_making_line_percentage,
    -- Coberura de ventas.
    ROUND(
        100.0
        *
        (
            total_order_lines - unknown_sales_lines
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
            total_order_lines - unknown_quantity_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS quantity_coverage_percentage,
    -- Cobertura de beneficios.
    ROUND(
        100.0
        *
        (
            total_order_lines - unknown_profit_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS profit_coverage_percentage

FROM comparacion_subcategorias

ORDER BY
    global_sales_rank,
    category,
    sub_category;




-- Validación de cantidad de subcategorías
SELECT
    (SELECT COUNT(*) FROM sub_categories)
        AS subcategorias_modelo,

    (SELECT COUNT(*) FROM vw_subcategory_performance)
        AS subcategorias_analizadas,

    (SELECT COUNT(*) FROM vw_subcategory_performance)
    -
    (SELECT COUNT(*) FROM sub_categories)
        AS diferencia;

    


-- Validación de participación por categoría
WITH participacion AS
(
    SELECT
        category,
        sub_category,

        100.0
        *
        total_sales
        /
        NULLIF(
            SUM(total_sales) OVER (
                PARTITION BY category
            ),
            0
        ) AS sales_share

    FROM vw_subcategory_performance
)

SELECT
    category,

    ROUND(
        SUM(sales_share),
        2
    ) AS category_sales_share_total

FROM participacion

GROUP BY category

ORDER BY category;






-- Alto volumen frente a rentabilidad
-- Comparamos cada subcategoría contra dos referencias:
-- 1. Venta promedio entre todas las subcategorías.
-- 2. Margen comparable promedio entre todas las subcategorías.

-- Esto permite construir cuatro perfiles:
-- Alto volumen  + Alta rentabilidad
-- Alto volumen  + Baja rentabilidad
-- Bajo volumen  + Alta rentabilidad
-- Bajo volumen  + Baja rentabilidad

WITH referencias AS
(
    SELECT
        AVG(total_sales)
            AS average_subcategory_sales,

        AVG(comparable_profit_margin_percentage)
            AS average_subcategory_margin

    FROM vw_subcategory_performance
),

clasificacion AS
(
    SELECT
        vsp.category,
        vsp.sub_category,

        vsp.total_orders,
        vsp.total_order_lines,
        vsp.distinct_customers,
        vsp.distinct_products,

        vsp.total_sales,
        vsp.total_quantity,
        vsp.total_profit,

        vsp.average_line_discount,
        vsp.comparable_profit_margin_percentage,

        vsp.loss_making_lines,

        vsp.unknown_sales_lines,
        vsp.unknown_profit_lines,

        r.average_subcategory_sales,
        r.average_subcategory_margin,
        -- Clasificación comercial
        CASE
            -- Si no existe margen comparable, evitamos
            -- asignar una clasificación financiera.
            WHEN vsp.comparable_profit_margin_percentage IS NULL
                THEN 'Sin margen comparable'

            WHEN vsp.total_sales >= r.average_subcategory_sales
             AND vsp.comparable_profit_margin_percentage
                    >= r.average_subcategory_margin
                THEN 'Alto volumen - Alta rentabilidad'

            WHEN vsp.total_sales >= r.average_subcategory_sales
             AND vsp.comparable_profit_margin_percentage
                    < r.average_subcategory_margin
                THEN 'Alto volumen - Baja rentabilidad'

            WHEN vsp.total_sales < r.average_subcategory_sales
             AND vsp.comparable_profit_margin_percentage
                    >= r.average_subcategory_margin
                THEN 'Bajo volumen - Alta rentabilidad'

            ELSE 'Bajo volumen - Baja rentabilidad'
        END AS performance_profile

    FROM vw_subcategory_performance AS vsp

    CROSS JOIN referencias AS r
)

SELECT
    category,
    sub_category,

    performance_profile,

    total_orders,
    total_order_lines,
    distinct_customers,
    distinct_products,

    ROUND(total_sales, 2)
        AS total_sales,

    ROUND(
        average_subcategory_sales,
        2
    ) AS sales_benchmark,
    -- Diferencia respecto a la venta promedio
    -- de las subcategorías.
    ROUND(
        total_sales - average_subcategory_sales,
        2
    ) AS sales_vs_benchmark,

    total_quantity,

    ROUND(total_profit, 2)
        AS total_profit,

    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,

    ROUND(
        average_subcategory_margin,
        2
    ) AS margin_benchmark,
    -- Diferencia en puntos porcentuales respecto
    -- al margen promedio.
    ROUND(
        comparable_profit_margin_percentage
        -
        average_subcategory_margin,
        2
    ) AS margin_vs_benchmark_points,

    ROUND(
        average_line_discount,
        4
    ) AS average_line_discount,
    -- Porcentaje de líneas con beneficio conocido
    -- cuyo resultado fue negativo.
    ROUND(
        100.0
        *
        loss_making_lines
        /
        NULLIF(
            total_order_lines - unknown_profit_lines,
            0
        ),
        2
    ) AS known_loss_making_line_percentage,
    -- Cobertura de ventas.
    ROUND(
        100.0
        *
        (
            total_order_lines - unknown_sales_lines
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
            total_order_lines - unknown_profit_lines
        )
        /
        NULLIF(total_order_lines, 0),
        2
    ) AS profit_coverage_percentage

FROM clasificacion

ORDER BY
    CASE performance_profile
        WHEN 'Alto volumen - Baja rentabilidad' THEN 1
        WHEN 'Alto volumen - Alta rentabilidad' THEN 2
        WHEN 'Bajo volumen - Baja rentabilidad' THEN 3
        WHEN 'Bajo volumen - Alta rentabilidad' THEN 4
        ELSE 5
    END,
    total_sales DESC;




-- Subcategorías de alto volumen y baja rentabilidad
WITH referencias AS
(
    SELECT
        AVG(total_sales)
            AS average_subcategory_sales,

        AVG(comparable_profit_margin_percentage)
            AS average_subcategory_margin

    FROM vw_subcategory_performance
)

SELECT
    vsp.category,
    vsp.sub_category,

    ROUND(vsp.total_sales, 2)
        AS total_sales,

    ROUND(vsp.total_profit, 2)
        AS total_profit,

    ROUND(
        vsp.comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,

    ROUND(
        vsp.average_line_discount,
        4
    ) AS average_line_discount,

    vsp.loss_making_lines,

    ROUND(
        100.0
        *
        vsp.loss_making_lines
        /
        NULLIF(
            vsp.total_order_lines
            -
            vsp.unknown_profit_lines,
            0
        ),
        2
    ) AS known_loss_making_line_percentage

FROM vw_subcategory_performance AS vsp

CROSS JOIN referencias AS r

WHERE vsp.total_sales
        >= r.average_subcategory_sales

  AND vsp.comparable_profit_margin_percentage
        < r.average_subcategory_margin

ORDER BY
    vsp.comparable_profit_margin_percentage ASC,
    vsp.total_sales DESC;



-- Validación de perfiles
WITH referencias AS
(
    SELECT
        AVG(total_sales)
            AS average_subcategory_sales,

        AVG(comparable_profit_margin_percentage)
            AS average_subcategory_margin

    FROM vw_subcategory_performance
),

clasificacion AS
(
    SELECT
        sub_category,

        CASE
            WHEN comparable_profit_margin_percentage IS NULL
                THEN 'Sin margen comparable'

            WHEN total_sales >= average_subcategory_sales
             AND comparable_profit_margin_percentage
                    >= average_subcategory_margin
                THEN 'Alto volumen - Alta rentabilidad'

            WHEN total_sales >= average_subcategory_sales
             AND comparable_profit_margin_percentage
                    < average_subcategory_margin
                THEN 'Alto volumen - Baja rentabilidad'

            WHEN total_sales < average_subcategory_sales
             AND comparable_profit_margin_percentage
                    >= average_subcategory_margin
                THEN 'Bajo volumen - Alta rentabilidad'

            ELSE 'Bajo volumen - Baja rentabilidad'
        END AS performance_profile

    FROM vw_subcategory_performance
    CROSS JOIN referencias
)

SELECT
    performance_profile,
    COUNT(*) AS total_subcategories
FROM clasificacion
GROUP BY performance_profile
ORDER BY performance_profile;






-- Concentración de ventas y análisis Pareto
-- Ordenamos las subcategorías desde la de mayores ventas
-- hasta la de menores ventas y calculamos:
-- 1. Participación individual sobre las ventas.
-- 2. Ventas acumuladas.
-- 3. Participación acumulada.
-- 4. Clasificación ABC basada en concentración.

-- La clasificación utilizada será:
-- A → hasta aproximadamente el 80% acumulado.
-- B → desde el 80% hasta aproximadamente el 95%.
-- C → resto de las ventas.
WITH ventas_subcategorias AS
(
    SELECT
        vsp.category,
        vsp.sub_category,

        vsp.total_orders,
        vsp.total_order_lines,
        vsp.distinct_customers,
        vsp.distinct_products,

        vsp.total_sales,
        vsp.total_profit,

        vsp.comparable_profit_margin_percentage,

        vsp.unknown_sales_lines,
        vsp.unknown_profit_lines,
        -- Posición según ventas.
        ROW_NUMBER() OVER (
            ORDER BY
                vsp.total_sales DESC,
                vsp.sub_category
        ) AS sales_position,
        -- Ventas totales conocidas del negocio.
        SUM(vsp.total_sales) OVER ()
            AS business_total_sales,
        -- Ventas acumuladas siguiendo el ranking.
        SUM(vsp.total_sales) OVER
        (
            ORDER BY
                vsp.total_sales DESC,
                vsp.sub_category

            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW
        ) AS cumulative_sales

    FROM vw_subcategory_performance AS vsp
),

participacion AS
(
    SELECT
        vs.*,

        100.0
        *
        vs.total_sales
        /
        NULLIF(
            vs.business_total_sales,
            0
        ) AS sales_share_percentage,

        100.0
        *
        vs.cumulative_sales
        /
        NULLIF(
            vs.business_total_sales,
            0
        ) AS cumulative_sales_percentage

    FROM ventas_subcategorias AS vs
)
SELECT
    sales_position,

    category,
    sub_category,

    total_orders,
    total_order_lines,
    distinct_customers,
    distinct_products,

    ROUND(total_sales, 2)
        AS total_sales,

    ROUND(
        sales_share_percentage,
        2
    ) AS sales_share_percentage,

    ROUND(
        cumulative_sales,
        2
    ) AS cumulative_sales,

    ROUND(
        cumulative_sales_percentage,
        2
    ) AS cumulative_sales_percentage,
    -- Clasificación basada en la concentración
    -- acumulada de las ventas.
    CASE
        WHEN cumulative_sales_percentage <= 80
            THEN 'A'

        WHEN cumulative_sales_percentage <= 95
            THEN 'B'

        ELSE 'C'
    END AS abc_classification,

    ROUND(total_profit, 2)
        AS total_profit,

    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
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

FROM participacion

ORDER BY sales_position;



-- Cantidad de subcategorías necesarias para concentrar
-- diferentes porcentajes de las ventas
WITH ventas_ordenadas AS
(
    SELECT
        sub_category,
        total_sales,

        100.0
        *
        SUM(total_sales) OVER
        (
            ORDER BY
                total_sales DESC,
                sub_category

            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW
        )
        /
        NULLIF(
            SUM(total_sales) OVER (),
            0
        ) AS cumulative_sales_percentage

    FROM vw_subcategory_performance
)

SELECT
    -- Número mínimo aproximado de subcategorías
    -- necesarias para alcanzar cada umbral.

    MIN(
        CASE
            WHEN cumulative_sales_percentage >= 50
                THEN posicion
        END
    ) AS subcategories_for_50_percent,

    MIN(
        CASE
            WHEN cumulative_sales_percentage >= 80
                THEN posicion
        END
    ) AS subcategories_for_80_percent,

    MIN(
        CASE
            WHEN cumulative_sales_percentage >= 95
                THEN posicion
        END
    ) AS subcategories_for_95_percent

FROM
(
    SELECT
        sub_category,
        cumulative_sales_percentage,

        ROW_NUMBER() OVER (
            ORDER BY
                total_sales DESC,
                sub_category
        ) AS posicion

    FROM ventas_ordenadas
) AS concentracion;



-- Validación de participación total
SELECT
    ROUND(
        SUM(
            100.0
            *
            total_sales
            /
            NULLIF(
                (
                    SELECT SUM(total_sales)
                    FROM vw_subcategory_performance
                ),
                0
            )
        ),
        2
    ) AS total_sales_share_percentage

FROM vw_subcategory_performance;




-- Subcategorías con mayor riesgo de pérdidas
-- Analizamos el beneficio acumulado, el margen comparable
-- y la frecuencia de líneas con pérdidas de cada subcategoría.
WITH riesgo_subcategorias AS
(
    SELECT
        vsp.category,
        vsp.sub_category,
        vsp.total_orders,
        vsp.total_order_lines,
        vsp.distinct_customers,
        vsp.distinct_products,
        vsp.total_sales,
        vsp.total_profit,
        vsp.average_line_discount,
        vsp.comparable_profit_margin_percentage,
        vsp.loss_making_lines,
        vsp.unknown_sales_lines,
        vsp.unknown_profit_lines,
        -- Líneas cuyo beneficio sí es conocido.
        vsp.total_order_lines
        -
        vsp.unknown_profit_lines
            AS known_profit_lines,
        -- Porcentaje de líneas conocidas que generaron pérdidas.
        100.0
        *
        vsp.loss_making_lines
        /
        NULLIF(
            vsp.total_order_lines
            -
            vsp.unknown_profit_lines,
            0
        ) AS known_loss_making_line_percentage
    FROM vw_subcategory_performance AS vsp
),

clasificacion_riesgo AS
(
    SELECT
        rs.*,
        -- Ranking desde el menor beneficio acumulado.
        DENSE_RANK() OVER (
            ORDER BY rs.total_profit ASC
        ) AS lowest_profit_rank,
        -- Ranking desde la mayor frecuencia de pérdidas.
        DENSE_RANK() OVER (
            ORDER BY
                rs.known_loss_making_line_percentage DESC
        ) AS loss_frequency_rank,
        -- Clasificación basada únicamente en resultados observados.
        CASE
            WHEN rs.total_profit < 0
                THEN 'Beneficio acumulado negativo'
            WHEN rs.comparable_profit_margin_percentage < 0
                THEN 'Margen comparable negativo'
            WHEN rs.loss_making_lines > 0
                THEN 'Presenta líneas con pérdidas'
            ELSE 'Sin pérdidas conocidas'
        END AS risk_status
    FROM riesgo_subcategorias AS rs
)

SELECT
    category,
    sub_category,
    risk_status,
    total_orders,
    total_order_lines,
    known_profit_lines,
    loss_making_lines,
    ROUND(
        known_loss_making_line_percentage,
        2
    ) AS known_loss_making_line_percentage,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    ROUND(
        average_line_discount * 100,
        2
    ) AS average_discount_percentage,
    lowest_profit_rank,
    loss_frequency_rank,
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
FROM clasificacion_riesgo
ORDER BY
    CASE risk_status
        WHEN 'Beneficio acumulado negativo' THEN 1
        WHEN 'Margen comparable negativo' THEN 2
        WHEN 'Presenta líneas con pérdidas' THEN 3
        ELSE 4
    END,
    total_profit ASC,
    sub_category;




-- Subcategorías con beneficio acumulado negativo.
SELECT
    category,
    sub_category,
    total_orders,
    total_order_lines,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    ROUND(
        average_line_discount * 100,
        2
    ) AS average_discount_percentage,
    loss_making_lines,
    ROUND(
        100.0
        *
        loss_making_lines
        /
        NULLIF(
            total_order_lines
            -
            unknown_profit_lines,
            0
        ),
        2
    ) AS known_loss_making_line_percentage,
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
FROM vw_subcategory_performance
WHERE total_profit < 0
ORDER BY
    total_profit ASC,
    sub_category;




-- Subcategorías con mayor proporción de líneas con pérdidas.
SELECT
    category,
    sub_category,
    total_order_lines,
    loss_making_lines,
    ROUND(
        100.0
        *
        loss_making_lines
        /
        NULLIF(
            total_order_lines
            -
            unknown_profit_lines,
            0
        ),
        2
    ) AS known_loss_making_line_percentage,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    ROUND(
        average_line_discount * 100,
        2
    ) AS average_discount_percentage
FROM vw_subcategory_performance
WHERE total_order_lines
      -
      unknown_profit_lines > 0
ORDER BY
    known_loss_making_line_percentage DESC,
    loss_making_lines DESC,
    sub_category
LIMIT 5;





-- Evolución anual por subcategoría
-- Analizamos el desempeño anual de cada subcategoría.
-- Posteriormente utilizamos LAG() para comparar cada
-- subcategoría con su propio resultado del año anterior.
WITH rendimiento_anual_subcategoria AS
(
    SELECT
        vsd.category,
        vsd.sub_category,
        YEAR(vsd.order_date) AS order_year,
        -- Actividad comercial.
        COUNT(DISTINCT vsd.order_key)
            AS total_orders,
        COUNT(DISTINCT vsd.customer_id)
            AS distinct_customers,
        COUNT(*) AS total_order_lines,
        COUNT(DISTINCT vsd.product_key)
            AS distinct_products,
        -- Métricas comerciales.
        SUM(vsd.sales)
            AS total_sales,
        SUM(vsd.quantity)
            AS total_quantity,
        SUM(vsd.profit)
            AS total_profit,
        AVG(vsd.discount)
            AS average_line_discount,
        -- Margen comparable.
        SUM(
            CASE
                WHEN vsd.sales IS NOT NULL
                 AND vsd.profit IS NOT NULL
                    THEN vsd.profit
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN vsd.sales IS NOT NULL
                     AND vsd.profit IS NOT NULL
                        THEN vsd.sales
                END
            ),
            0
        ) * 100 AS comparable_profit_margin_percentage,
        -- Líneas con pérdidas.
        SUM(
            CASE
                WHEN vsd.profit < 0 THEN 1
                ELSE 0
            END
        ) AS loss_making_lines,
        -- Cobertura de datos.
        COUNT(*) - COUNT(vsd.sales)
            AS unknown_sales_lines,
        COUNT(*) - COUNT(vsd.quantity)
            AS unknown_quantity_lines,
        COUNT(*) - COUNT(vsd.profit)
            AS unknown_profit_lines
    FROM vw_sales_detail AS vsd
    GROUP BY
        vsd.category,
        vsd.sub_category,
        YEAR(vsd.order_date)
),

comparacion_anual_subcategoria AS
(
    SELECT
        ras.*,
        -- Valores de la misma subcategoría
        -- durante el año anterior.
        LAG(ras.total_orders) OVER
        (
            PARTITION BY
                ras.category,
                ras.sub_category
            ORDER BY ras.order_year
        ) AS previous_year_orders,
        LAG(ras.total_sales) OVER
        (
            PARTITION BY
                ras.category,
                ras.sub_category
            ORDER BY ras.order_year
        ) AS previous_year_sales,
        LAG(ras.total_profit) OVER
        (
            PARTITION BY
                ras.category,
                ras.sub_category
            ORDER BY ras.order_year
        ) AS previous_year_profit,
        LAG(ras.comparable_profit_margin_percentage) OVER
        (
            PARTITION BY
                ras.category,
                ras.sub_category
            ORDER BY ras.order_year
        ) AS previous_year_margin
    FROM rendimiento_anual_subcategoria AS ras
)

SELECT
    category,
    sub_category,
    order_year,
    total_orders,
    distinct_customers,
    total_order_lines,
    distinct_products,
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
        average_line_discount * 100,
        2
    ) AS average_discount_percentage,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    -- Crecimiento anual de pedidos.
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
    ) AS year_over_year_order_growth_percentage,
    -- Crecimiento anual de ventas.
    ROUND(
        100.0
        *
        (
            total_sales
            -
            previous_year_sales
        )
        /
        NULLIF(previous_year_sales, 0),
        2
    ) AS year_over_year_sales_growth_percentage,
    -- Cambio absoluto del beneficio.
    ROUND(
        total_profit
        -
        previous_year_profit,
        2
    ) AS year_over_year_profit_change,
    -- Cambio del margen en puntos porcentuales.
    ROUND(
        comparable_profit_margin_percentage
        -
        previous_year_margin,
        2
    ) AS year_over_year_margin_change_points,
    loss_making_lines,
    ROUND(
        100.0
        *
        loss_making_lines
        /
        NULLIF(
            total_order_lines
            -
            unknown_profit_lines,
            0
        ),
        2
    ) AS known_loss_making_line_percentage,
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
FROM comparacion_anual_subcategoria
ORDER BY
    category,
    sub_category,
    order_year;




-- Subcategorías con crecimiento de ventas
-- y deterioro del margen.
WITH rendimiento_anual AS
(
    SELECT
        vsd.category,
        vsd.sub_category,
        YEAR(vsd.order_date) AS order_year,
        SUM(vsd.sales) AS total_sales,
        SUM(
            CASE
                WHEN vsd.sales IS NOT NULL
                 AND vsd.profit IS NOT NULL
                    THEN vsd.profit
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN vsd.sales IS NOT NULL
                     AND vsd.profit IS NOT NULL
                        THEN vsd.sales
                END
            ),
            0
        ) * 100 AS comparable_profit_margin_percentage
    FROM vw_sales_detail AS vsd
    GROUP BY
        vsd.category,
        vsd.sub_category,
        YEAR(vsd.order_date)
),

comparacion AS
(
    SELECT
        ra.*,
        LAG(ra.total_sales) OVER
        (
            PARTITION BY
                ra.category,
                ra.sub_category
            ORDER BY ra.order_year
        ) AS previous_year_sales,
        LAG(ra.comparable_profit_margin_percentage) OVER
        (
            PARTITION BY
                ra.category,
                ra.sub_category
            ORDER BY ra.order_year
        ) AS previous_year_margin
    FROM rendimiento_anual AS ra
)

SELECT
    category,
    sub_category,
    order_year,
    ROUND(
        previous_year_sales,
        2
    ) AS previous_year_sales,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        100.0
        *
        (
            total_sales
            -
            previous_year_sales
        )
        /
        NULLIF(previous_year_sales, 0),
        2
    ) AS sales_growth_percentage,
    ROUND(
        previous_year_margin,
        2
    ) AS previous_year_margin,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS current_margin,
    ROUND(
        comparable_profit_margin_percentage
        -
        previous_year_margin,
        2
    ) AS margin_change_points
FROM comparacion
WHERE total_sales > previous_year_sales
  AND comparable_profit_margin_percentage
        < previous_year_margin
ORDER BY
    margin_change_points ASC,
    sales_growth_percentage DESC;



-- Validamos la cobertura anual de cada subcategoría.
SELECT
    category,
    sub_category,
    MIN(YEAR(order_date)) AS first_year,
    MAX(YEAR(order_date)) AS last_year,
    COUNT(
        DISTINCT YEAR(order_date)
    ) AS observed_years
FROM vw_sales_detail
GROUP BY
    category,
    sub_category
ORDER BY
    category,
    sub_category;