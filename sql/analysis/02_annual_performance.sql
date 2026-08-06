/*
Archivo      : 02_annual_performance.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Evolución anual del negocio
               Análisis anual de pedidos, clientes,
               ventas, beneficios y crecimiento interanual.
*/

USE superstore_analytics;

-- Primero calculamos los indicadores correspondientes
-- a cada año disponible en el conjunto de datos.
WITH rendimiento_anual AS
(
    SELECT
        vos.order_year,
        -- Actividad comercial.
        COUNT(*) AS total_orders,
        COUNT(DISTINCT vos.customer_id) AS distinct_customers,
        SUM(vos.total_order_lines) AS total_order_lines,
        -- Métricas conocidas.
        SUM(vos.total_sales) AS total_sales,
        SUM(vos.total_quantity) AS total_quantity,
        SUM(vos.total_profit) AS total_profit,
        -- Promedios calculados únicamente con pedidos
        -- cuya información se encuentra completa.
        AVG(
            CASE
                WHEN vos.unknown_sales_lines = 0
                    THEN vos.total_sales
            END
        ) AS average_complete_order_value,

        AVG(
            CASE
                WHEN vos.unknown_profit_lines = 0
                    THEN vos.total_profit
            END
        ) AS average_complete_order_profit,
        -- Margen comparable calculado con pedidos cuyas
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
        -- Cobertura de información.
        SUM(vos.unknown_sales_lines)
            AS unknown_sales_lines,

        SUM(vos.unknown_quantity_lines)
            AS unknown_quantity_lines,

        SUM(vos.unknown_profit_lines)
            AS unknown_profit_lines,
        -- Pedidos completos cuyo resultado fue negativo.
        SUM(
            CASE
                WHEN vos.unknown_profit_lines = 0
                 AND vos.total_profit < 0
                    THEN 1
                ELSE 0
            END
        ) AS complete_loss_making_orders

    FROM vw_order_summary AS vos

    GROUP BY vos.order_year
),

comparacion_anual AS
(
    SELECT
        ra.*,
        -- Recuperamos los valores del año anterior.
        LAG(ra.total_orders)
            OVER (ORDER BY ra.order_year)
            AS previous_year_orders,

        LAG(ra.distinct_customers)
            OVER (ORDER BY ra.order_year)
            AS previous_year_customers,

        LAG(ra.total_sales)
            OVER (ORDER BY ra.order_year)
            AS previous_year_sales,

        LAG(ra.total_profit)
            OVER (ORDER BY ra.order_year)
            AS previous_year_profit

    FROM rendimiento_anual AS ra
)
SELECT
    order_year,

    total_orders,
    distinct_customers,
    total_order_lines,

    ROUND(total_sales, 2)
        AS total_sales,

    total_quantity,

    ROUND(total_profit, 2)
        AS total_profit,

    ROUND(average_complete_order_value, 2)
        AS average_complete_order_value,

    ROUND(average_complete_order_profit, 2)
        AS average_complete_order_profit,

    ROUND(comparable_profit_margin_percentage, 2)
        AS comparable_profit_margin_percentage,
    -- Crecimiento interanual de pedidos.
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
    -- Crecimiento interanual de clientes activos.
    ROUND(
        100.0
        *
        (
            distinct_customers - previous_year_customers
        )
        /
        NULLIF(previous_year_customers, 0),
        2
    ) AS year_over_year_customer_growth_percentage,
    -- Crecimiento interanual de ventas conocidas.
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
    -- Para el beneficio mostramos el cambio absoluto.
    -- Un porcentaje sería difícil de interpretar cuando
    -- el año anterior tiene beneficios negativos o cercanos a cero.
    ROUND(
        total_profit - previous_year_profit,
        2
    ) AS year_over_year_profit_change,
    -- Cobertura anual de las métricas.
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
    ) AS profit_coverage_percentage,

    complete_loss_making_orders

FROM comparacion_anual

ORDER BY order_year;


-- Verificamos la cantidad de años disponibles.
SELECT
    MIN(order_year) AS first_year,
    MAX(order_year) AS last_year,
    COUNT(DISTINCT order_year) AS total_years
FROM vw_order_summary;


-- Comprobamos que la agrupación anual conserve todos
-- los pedidos, líneas y métricas comerciales.
SELECT
    resumen.total_orders AS orders_summary,
    anual.total_orders AS orders_annual,
    anual.total_orders - resumen.total_orders
        AS order_difference,

    resumen.total_lines AS lines_summary,
    anual.total_lines AS lines_annual,
    anual.total_lines - resumen.total_lines
        AS line_difference,

    resumen.total_sales AS sales_summary,
    anual.total_sales AS sales_annual,
    anual.total_sales - resumen.total_sales
        AS sales_difference,

    resumen.total_quantity AS quantity_summary,
    anual.total_quantity AS quantity_annual,
    anual.total_quantity - resumen.total_quantity
        AS quantity_difference,

    resumen.total_profit AS profit_summary,
    anual.total_profit AS profit_annual,
    anual.total_profit - resumen.total_profit
        AS profit_difference

FROM
(
    SELECT
        COUNT(*) AS total_orders,
        SUM(total_order_lines) AS total_lines,
        SUM(total_sales) AS total_sales,
        SUM(total_quantity) AS total_quantity,
        SUM(total_profit) AS total_profit
    FROM vw_order_summary
) AS resumen

CROSS JOIN
(
    SELECT
        SUM(total_orders) AS total_orders,
        SUM(total_lines) AS total_lines,
        SUM(total_sales) AS total_sales,
        SUM(total_quantity) AS total_quantity,
        SUM(total_profit) AS total_profit
    FROM
    (
        SELECT
            order_year,
            COUNT(*) AS total_orders,
            SUM(total_order_lines) AS total_lines,
            SUM(total_sales) AS total_sales,
            SUM(total_quantity) AS total_quantity,
            SUM(total_profit) AS total_profit
        FROM vw_order_summary
        GROUP BY order_year
    ) AS rendimiento_anual
) AS anual;


