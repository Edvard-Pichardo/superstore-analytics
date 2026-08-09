/*
Archivo      : 04_category_analysis.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Análisis comparativo del desempeño comercial
               de las categorías de productos, considerando
               ventas, beneficio, volumen, participación,
               rentabilidad y cobertura de datos.
*/

USE superstore_analytics;


-- Comparación y ranking de categorías
-- Comparamos las categorías principales del negocio.

-- Además de sus métricas absolutas, calculamos:
-- 1. Participación sobre las ventas totales.
-- 2. Participación sobre la cantidad total vendida.
-- 3. Ranking según ventas.
-- 4. Ranking según beneficio.
-- 5. Ranking según margen comparable.

-- La cobertura de datos se mantiene visible para evitar
-- interpretar las métricas sin considerar los valores
-- desconocidos presentes en el conjunto.

WITH comparacion_categorias AS
(
    SELECT
        vcp.category,
        -- Actividad comercial.
        vcp.total_orders,
        vcp.total_order_lines,
        vcp.distinct_customers,
        vcp.distinct_products,
        vcp.distinct_subcategories,
        -- Métricas comerciales.
        vcp.total_sales,
        vcp.total_quantity,
        vcp.total_profit,

        vcp.average_line_discount,
        vcp.average_known_line_sales,
        vcp.average_known_line_profit,

        vcp.comparable_profit_margin_percentage,
        -- Información relacionada con pérdidas.
        vcp.loss_making_lines,
        -- Cobertura de información.
        vcp.unknown_sales_lines,
        vcp.unknown_quantity_lines,
        vcp.unknown_profit_lines,
        -- Participación dentro del negocio
        -- Porcentaje de las ventas conocidas que corresponde
        -- a cada categoría.
        100.0
        *
        vcp.total_sales
        /
        NULLIF(
            SUM(vcp.total_sales) OVER (),
            0
        ) AS sales_share_percentage,
        -- Porcentaje de las unidades conocidas que corresponde
        -- a cada categoría.
        100.0
        *
        vcp.total_quantity
        /
        NULLIF(
            SUM(vcp.total_quantity) OVER (),
            0
        ) AS quantity_share_percentage,
        -- Porcentaje de líneas de venta pertenecientes
        -- a cada categoría.
        100.0
        *
        vcp.total_order_lines
        /
        NULLIF(
            SUM(vcp.total_order_lines) OVER (),
            0
        ) AS order_line_share_percentage,
        -- Rankings
        -- Categorías ordenadas de mayor a menor venta.
        DENSE_RANK() OVER (
            ORDER BY vcp.total_sales DESC
        ) AS sales_rank,
        -- Categorías ordenadas de mayor a menor beneficio.
        DENSE_RANK() OVER (
            ORDER BY vcp.total_profit DESC
        ) AS profit_rank,
        -- Categorías ordenadas de mayor a menor margen
        -- comparable.
        DENSE_RANK() OVER (
            ORDER BY
                vcp.comparable_profit_margin_percentage DESC
        ) AS margin_rank

    FROM vw_category_performance AS vcp
)

SELECT
    -- Identificación.
    category,
    -- Actividad comercial.
    total_orders,
    total_order_lines,
    distinct_customers,
    distinct_products,
    distinct_subcategories,
    -- Métricas principales.
    ROUND(total_sales, 2)
        AS total_sales,

    total_quantity,

    ROUND(total_profit, 2)
        AS total_profit,

    ROUND(average_line_discount, 4)
        AS average_line_discount,

    ROUND(average_known_line_sales, 2)
        AS average_known_line_sales,

    ROUND(average_known_line_profit, 2)
        AS average_known_line_profit,

    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    -- Participación.
    ROUND(
        sales_share_percentage,
        2
    ) AS sales_share_percentage,

    ROUND(
        quantity_share_percentage,
        2
    ) AS quantity_share_percentage,

    ROUND(
        order_line_share_percentage,
        2
    ) AS order_line_share_percentage,
    -- Rankings.
    sales_rank,
    profit_rank,
    margin_rank,
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
    -- Cobertura de datos.
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

FROM comparacion_categorias

ORDER BY
    sales_rank,
    category;




-- Validación de las participaciones
SELECT
    ROUND(
        SUM(total_sales)
        /
        NULLIF(
            (SELECT SUM(total_sales)
             FROM vw_category_performance),
            0
        ) * 100,
        2
    ) AS sales_share_total,

    ROUND(
        SUM(total_quantity)
        /
        NULLIF(
            (SELECT SUM(total_quantity)
             FROM vw_category_performance),
            0
        ) * 100,
        2
    ) AS quantity_share_total,

    ROUND(
        SUM(total_order_lines)
        /
        NULLIF(
            (SELECT SUM(total_order_lines)
             FROM vw_category_performance),
            0
        ) * 100,
        2
    ) AS order_line_share_total

FROM vw_category_performance;




-- Ventas frente a rentabilidad
-- Comparamos la posición de cada categoría según:
-- 1. Ventas totales conocidas.
-- 2. Beneficio total conocido.
-- 3. Margen de beneficio comparable.

-- La diferencia entre los rankings permite detectar
-- categorías cuyo volumen de ventas no se traduce
-- proporcionalmente en rentabilidad.
-- =====================================================
-- BLOQUE 2
-- Ventas frente a rentabilidad
-- =====================================================

-- Comparamos la posición de cada categoría según:
--
-- 1. Ventas totales conocidas.
-- 2. Beneficio total conocido.
-- 3. Margen de beneficio comparable.
--
-- La diferencia entre los rankings permite detectar
-- categorías cuyo volumen de ventas no se traduce
-- proporcionalmente en rentabilidad.

WITH ranking_rentabilidad AS
(
    SELECT
        vcp.category,

        vcp.total_orders,
        vcp.total_order_lines,

        vcp.total_sales,
        vcp.total_profit,

        vcp.average_line_discount,
        vcp.comparable_profit_margin_percentage,

        vcp.loss_making_lines,
        vcp.unknown_sales_lines,
        vcp.unknown_profit_lines,
        -- Ranking según ventas.
        DENSE_RANK() OVER (
            ORDER BY vcp.total_sales DESC
        ) AS sales_rank,
        -- Ranking según beneficio.
        DENSE_RANK() OVER (
            ORDER BY vcp.total_profit DESC
        ) AS profit_rank,
        -- Ranking según margen comparable.
        DENSE_RANK() OVER (
            ORDER BY
                vcp.comparable_profit_margin_percentage DESC
        ) AS margin_rank

    FROM vw_category_performance AS vcp
)
SELECT
    category,

    total_orders,
    total_order_lines,

    ROUND(total_sales, 2)
        AS total_sales,

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
    -- Rankings individuales.
    sales_rank,
    profit_rank,
    margin_rank,
    -- Diferencia entre volumen y rentabilidad
    CAST(profit_rank AS SIGNED)
    -
    CAST(sales_rank AS SIGNED)
        AS sales_profit_rank_gap,

    CASE
        WHEN profit_rank < sales_rank
            THEN 'Rentabilidad superior al volumen'

        WHEN profit_rank > sales_rank
            THEN 'Rentabilidad inferior al volumen'

        ELSE 'Rentabilidad alineada con ventas'
    END AS profitability_vs_sales,
    -- Frecuencia de pérdidas
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
    -- Cobertura de datos
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

FROM ranking_rentabilidad

ORDER BY
    sales_rank,
    category;



-- Categorías ordenadas por margen comparable
SELECT
    category,

    ROUND(total_sales, 2)
        AS total_sales,

    ROUND(total_profit, 2)
        AS total_profit,

    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,

    ROUND(
        average_line_discount,
        4
    ) AS average_line_discount,

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
    ) AS known_loss_making_line_percentage

FROM vw_category_performance

ORDER BY
    comparable_profit_margin_percentage DESC,
    total_profit DESC;






-- Impacto de los descuentos en la rentabilidad
-- Agrupamos las líneas de venta por categoría y nivel
-- de descuento para analizar cómo cambia el beneficio.

-- Los intervalos permiten comparar operaciones sin
-- descuento, descuentos bajos, medios y altos.
WITH ventas_por_descuento AS
(
    SELECT
        vsd.category,
        -- Clasificamos cada línea según su descuento.
        CASE
            WHEN vsd.discount = 0
                THEN 'Sin descuento'

            WHEN vsd.discount <= 0.10
                THEN '01 - 10%'

            WHEN vsd.discount <= 0.20
                THEN '11 - 20%'

            WHEN vsd.discount <= 0.30
                THEN '21 - 30%'

            WHEN vsd.discount <= 0.50
                THEN '31 - 50%'

            ELSE 'Más de 50%'
        END AS discount_range,
        -- Campo auxiliar para conservar el orden
        -- lógico de los intervalos.
        CASE
            WHEN vsd.discount = 0 THEN 1
            WHEN vsd.discount <= 0.10 THEN 2
            WHEN vsd.discount <= 0.20 THEN 3
            WHEN vsd.discount <= 0.30 THEN 4
            WHEN vsd.discount <= 0.50 THEN 5
            ELSE 6
        END AS discount_order,
        -- Actividad comercial.
        COUNT(*) AS total_order_lines,

        COUNT(DISTINCT vsd.order_key)
            AS total_orders,

        COUNT(DISTINCT vsd.customer_id)
            AS distinct_customers,
        -- Descuento promedio real dentro del intervalo.
        AVG(vsd.discount)
            AS average_discount,
        -- Métricas conocidas.
        SUM(vsd.sales)
            AS total_sales,

        SUM(vsd.quantity)
            AS total_quantity,

        SUM(vsd.profit)
            AS total_profit,

        AVG(vsd.sales)
            AS average_known_line_sales,

        AVG(vsd.profit)
            AS average_known_line_profit,
        -- Margen comparable
        -- Utilizamos únicamente las filas donde ventas
        -- y beneficio son conocidos simultáneamente.
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
        -- Pérdidas
        SUM(
            CASE
                WHEN vsd.profit < 0 THEN 1
                ELSE 0
            END
        ) AS loss_making_lines,
        -- Cobertura de datos
        COUNT(*) - COUNT(vsd.sales)
            AS unknown_sales_lines,

        COUNT(*) - COUNT(vsd.quantity)
            AS unknown_quantity_lines,

        COUNT(*) - COUNT(vsd.profit)
            AS unknown_profit_lines

    FROM vw_sales_detail AS vsd

    GROUP BY
        vsd.category,

        CASE
            WHEN vsd.discount = 0
                THEN 'Sin descuento'

            WHEN vsd.discount <= 0.10
                THEN '01 - 10%'

            WHEN vsd.discount <= 0.20
                THEN '11 - 20%'

            WHEN vsd.discount <= 0.30
                THEN '21 - 30%'

            WHEN vsd.discount <= 0.50
                THEN '31 - 50%'

            ELSE 'Más de 50%'
        END,

        CASE
            WHEN vsd.discount = 0 THEN 1
            WHEN vsd.discount <= 0.10 THEN 2
            WHEN vsd.discount <= 0.20 THEN 3
            WHEN vsd.discount <= 0.30 THEN 4
            WHEN vsd.discount <= 0.50 THEN 5
            ELSE 6
        END
)

SELECT
    category,
    discount_range,

    total_orders,
    total_order_lines,
    distinct_customers,

    ROUND(
        average_discount * 100,
        2
    ) AS average_discount_percentage,

    ROUND(total_sales, 2)
        AS total_sales,

    total_quantity,

    ROUND(total_profit, 2)
        AS total_profit,

    ROUND(average_known_line_sales, 2)
        AS average_known_line_sales,

    ROUND(average_known_line_profit, 2)
        AS average_known_line_profit,

    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,

    loss_making_lines,
    -- Porcentaje de líneas con beneficio conocido
    -- que terminaron en pérdida.
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

FROM ventas_por_descuento

ORDER BY
    category,
    discount_order;



-- Descuentos asociados con beneficio negativo
-- Mostramos únicamente las combinaciones de categoría
-- y descuento cuyo beneficio conocido acumulado es negativo.
SELECT
    category,
    discount,

    COUNT(*) AS total_order_lines,

    ROUND(
        SUM(sales),
        2
    ) AS total_sales,

    ROUND(
        SUM(profit),
        2
    ) AS total_profit,

    ROUND(
        AVG(profit),
        2
    ) AS average_known_profit,

    SUM(
        CASE
            WHEN profit < 0 THEN 1
            ELSE 0
        END
    ) AS loss_making_lines

FROM vw_sales_detail

GROUP BY
    category,
    discount

HAVING SUM(profit) < 0

ORDER BY
    category,
    discount;



-- Evolución anual por categoría
-- Analizamos el desempeño de cada categoría por año.
-- Posteriormente utilizamos LAG() para comparar cada
-- categoría consigo misma respecto al año anterior.
WITH rendimiento_anual_categoria AS
(
    SELECT
        vsd.category,
        YEAR(vsd.order_date) AS order_year,
        -- Actividad comercial.
        COUNT(DISTINCT vsd.order_key)
            AS total_orders,

        COUNT(DISTINCT vsd.customer_id)
            AS distinct_customers,

        COUNT(*) AS total_order_lines,

        COUNT(DISTINCT vsd.product_key)
            AS distinct_products,
        -- Métricas conocidas.
        SUM(vsd.sales)
            AS total_sales,

        SUM(vsd.quantity)
            AS total_quantity,

        SUM(vsd.profit)
            AS total_profit,

        AVG(vsd.discount)
            AS average_line_discount,
        -- Margen comparable calculado únicamente con
        -- líneas donde sales y profit son conocidos.
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
        -- Líneas con beneficio conocido negativo.
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
        YEAR(vsd.order_date)
),

comparacion_anual_categoria AS
(
    SELECT
        rac.*,
        -- Valores de la misma categoría durante
        -- el año inmediatamente anterior.
        LAG(rac.total_orders) OVER
        (
            PARTITION BY rac.category
            ORDER BY rac.order_year
        ) AS previous_year_orders,

        LAG(rac.total_sales) OVER
        (
            PARTITION BY rac.category
            ORDER BY rac.order_year
        ) AS previous_year_sales,

        LAG(rac.total_profit) OVER
        (
            PARTITION BY rac.category
            ORDER BY rac.order_year
        ) AS previous_year_profit

    FROM rendimiento_anual_categoria AS rac
)
SELECT
    category,
    order_year,

    total_orders,
    distinct_customers,
    total_order_lines,
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
    -- Variación respecto al año anterior
    ROUND(
        100.0
        *
        (
            total_orders - previous_year_orders
        )
        /
        NULLIF(previous_year_orders, 0),
        2
    ) AS year_over_year_order_growth_percentage,

    ROUND(
        100.0
        *
        (
            total_sales - previous_year_sales
        )
        /
        NULLIF(previous_year_sales, 0),
        2
    ) AS year_over_year_sales_growth_percentage,
    -- Para profit conservamos el cambio absoluto.
    ROUND(
        total_profit - previous_year_profit,
        2
    ) AS year_over_year_profit_change,
    -- Pérdidas
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
    -- Cobertura de datos
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

FROM comparacion_anual_categoria

ORDER BY
    category,
    order_year;



-- Validación de cobertura temporal por categoría
SELECT
    category,

    MIN(YEAR(order_date))
        AS first_year,

    MAX(YEAR(order_date))
        AS last_year,

    COUNT(
        DISTINCT YEAR(order_date)
    ) AS observed_years

FROM vw_sales_detail

GROUP BY category

ORDER BY category;

-- Verificamos cuántas combinaciones distintas de
-- categoría y año existen en los datos.
SELECT COUNT(*) AS category_year_combinations
FROM
(
    SELECT
        category,
        YEAR(order_date) AS order_year
    FROM vw_sales_detail

    GROUP BY
        category,
        YEAR(order_date)
) AS periodos;