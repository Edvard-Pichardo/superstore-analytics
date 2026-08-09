/*
Archivo      : 03_monthly_trends.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Análisis de la evolución mensual del negocio,
               incluyendo ventas, pedidos, clientes, beneficios
               y crecimiento respecto al mes anterior.
*/

USE superstore_analytics;


-- Evolución mensual y crecimiento mes contra mes
-- Utilizamos la vista mensual previamente creada y recuperamos
-- mediante LAG() los valores correspondientes al mes anterior.

-- Esto permite calcular variaciones mensuales sin realizar
-- auto-joins sobre la misma vista.

WITH comparacion_mensual AS
(
    SELECT
        vmp.*,
        -- Valores correspondientes al mes anterior.
        LAG(vmp.total_orders)
            OVER (
                ORDER BY
                    vmp.order_year,
                    vmp.order_month
            ) AS previous_month_orders,

        LAG(vmp.distinct_customers)
            OVER (
                ORDER BY
                    vmp.order_year,
                    vmp.order_month
            ) AS previous_month_customers,

        LAG(vmp.total_sales)
            OVER (
                ORDER BY
                    vmp.order_year,
                    vmp.order_month
            ) AS previous_month_sales,

        LAG(vmp.total_profit)
            OVER (
                ORDER BY
                    vmp.order_year,
                    vmp.order_month
            ) AS previous_month_profit

    FROM vw_monthly_performance AS vmp
)

SELECT
    -- Periodo.
    order_year,
    order_month,
    order_year_month,
    -- Actividad comercial.
    total_orders,
    distinct_customers,
    total_order_lines,
    -- Métricas principales.
    ROUND(total_sales, 2)
        AS total_sales,

    total_quantity,

    ROUND(total_profit, 2)
        AS total_profit,

    ROUND(average_complete_order_value, 2)
        AS average_complete_order_value,

    ROUND(average_complete_order_profit, 2)
        AS average_complete_order_profit,

    ROUND(profit_margin_percentage, 2)
        AS profit_margin_percentage,
    -- Crecimiento mensual
    -- Variación porcentual de pedidos frente al mes anterior.
    ROUND(
        100.0
        *
        (
            total_orders - previous_month_orders
        )
        /
        NULLIF(previous_month_orders, 0),
        2
    ) AS month_over_month_order_growth_percentage,
    -- Variación de clientes activos frente al mes anterior.
    ROUND(
        100.0
        *
        (
            distinct_customers - previous_month_customers
        )
        /
        NULLIF(previous_month_customers, 0),
        2
    ) AS month_over_month_customer_growth_percentage,
    -- Variación porcentual de las ventas conocidas.
    ROUND(
        100.0
        *
        (
            total_sales - previous_month_sales
        )
        /
        NULLIF(previous_month_sales, 0),
        2
    ) AS month_over_month_sales_growth_percentage,
    -- Para el beneficio utilizamos cambio absoluto.
    -- Un porcentaje puede resultar engañoso cuando el
    -- beneficio anterior es negativo o cercano a cero.
    ROUND(
        total_profit - previous_month_profit,
        2
    ) AS month_over_month_profit_change,
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
    ) AS profit_coverage_percentage,

    orders_with_unknown_sales,
    orders_with_unknown_profit

FROM comparacion_mensual

ORDER BY
    order_year,
    order_month;


-- Verificamos el rango y la cantidad de periodos mensuales.
SELECT
    MIN(order_year_month) AS first_month,
    MAX(order_year_month) AS last_month,
    COUNT(*) AS total_months
FROM vw_monthly_performance;


-- Cada año-mes debe aparecer una sola vez. (Debe devolver cero filas)
SELECT
    order_year,
    order_month,
    COUNT(*) AS total_registros
FROM vw_monthly_performance
GROUP BY
    order_year,
    order_month
HAVING COUNT(*) > 1;




-- Ranking de mejores y peores meses
-- Clasificamos cada periodo mensual según:
-- 1. Ventas conocidas.
-- 2. Beneficio conocido.
-- 3. Cantidad de pedidos.

-- DENSE_RANK() permite asignar la misma posición
-- cuando dos meses tienen exactamente el mismo valor.

WITH ranking_mensual AS
(
    SELECT
        order_year,
        order_month,
        order_year_month,

        total_orders,
        distinct_customers,
        total_order_lines,

        total_sales,
        total_quantity,
        total_profit,

        average_complete_order_value,
        profit_margin_percentage,

        unknown_sales_lines,
        unknown_profit_lines,
        -- Ranking de mayor a menor venta.
        DENSE_RANK() OVER (
            ORDER BY total_sales DESC
        ) AS sales_rank_best,
        -- Ranking de menor a mayor venta.
        DENSE_RANK() OVER (
            ORDER BY total_sales ASC
        ) AS sales_rank_worst,
        -- Ranking de mayor a menor beneficio.
        DENSE_RANK() OVER (
            ORDER BY total_profit DESC
        ) AS profit_rank_best,
        -- Ranking de menor a mayor beneficio.
        DENSE_RANK() OVER (
            ORDER BY total_profit ASC
        ) AS profit_rank_worst,
        -- Ranking según cantidad de pedidos.
        DENSE_RANK() OVER (
            ORDER BY total_orders DESC
        ) AS order_rank_best,

        DENSE_RANK() OVER (
            ORDER BY total_orders ASC
        ) AS order_rank_worst

    FROM vw_monthly_performance
)

SELECT
    order_year_month,

    total_orders,
    distinct_customers,

    ROUND(total_sales, 2)
        AS total_sales,

    total_quantity,

    ROUND(total_profit, 2)
        AS total_profit,

    ROUND(average_complete_order_value, 2)
        AS average_complete_order_value,

    ROUND(profit_margin_percentage, 2)
        AS profit_margin_percentage,
    -- Posiciones en los rankings.
    sales_rank_best,
    sales_rank_worst,

    profit_rank_best,
    profit_rank_worst,

    order_rank_best,
    order_rank_worst,
    -- Cobertura para interpretar correctamente
    -- los rankings de ventas y beneficios.
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

FROM ranking_mensual

ORDER BY
    sales_rank_best,
    order_year_month;




-- Top 5 meses por ventas
SELECT
    order_year_month,
    total_orders,
    distinct_customers,

    ROUND(total_sales, 2)
        AS total_sales,

    ROUND(total_profit, 2)
        AS total_profit,

    ROUND(profit_margin_percentage, 2)
        AS profit_margin_percentage

FROM vw_monthly_performance
ORDER BY
    total_sales DESC,
    order_year_month

LIMIT 5;


-- Top 5 meses por beneficio
SELECT
    order_year_month,
    total_orders,

    ROUND(total_sales, 2)
        AS total_sales,

    ROUND(total_profit, 2)
        AS total_profit,

    ROUND(profit_margin_percentage, 2)
        AS profit_margin_percentage

FROM vw_monthly_performance

ORDER BY
    total_profit DESC,
    order_year_month

LIMIT 5;



-- 5 meses con menor beneficio
SELECT
    order_year_month,
    total_orders,

    ROUND(total_sales, 2)
        AS total_sales,

    ROUND(total_profit, 2)
        AS total_profit,

    ROUND(profit_margin_percentage, 2)
        AS profit_margin_percentage,

    unknown_profit_lines

FROM vw_monthly_performance
ORDER BY
    total_profit ASC,
    order_year_month

LIMIT 5;




-- Análisis de estacionalidad
-- Agrupamos los mismos meses de diferentes años para
-- identificar patrones estacionales.

-- Por ejemplo:
-- enero 2023 + enero 2024 + enero 2025 + enero 2026
-- se analizan conjuntamente como "Enero".

WITH estacionalidad AS
(
    SELECT
        vmp.order_month,
        -- Nombre del mes en español.
        CASE vmp.order_month
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
        -- Cantidad de periodos y años disponibles
        -- para evaluar cada mes.
        COUNT(*) AS observed_periods,
        COUNT(DISTINCT vmp.order_year) AS observed_years,
        -- Promedios históricos mensuales.
        AVG(vmp.total_orders)
            AS average_orders,

        AVG(vmp.distinct_customers)
            AS average_distinct_customers,

        AVG(vmp.total_sales)
            AS average_sales,

        AVG(vmp.total_quantity)
            AS average_quantity,

        AVG(vmp.total_profit)
            AS average_profit,

        AVG(vmp.average_complete_order_value)
            AS average_complete_order_value,
        -- Valores extremos observados.
        MIN(vmp.total_sales)
            AS minimum_sales,

        MAX(vmp.total_sales)
            AS maximum_sales,

        MIN(vmp.total_profit)
            AS minimum_profit,

        MAX(vmp.total_profit)
            AS maximum_profit,
        -- Cobertura promedio de ventas.
        AVG(
            100.0
            *
            (
                vmp.total_order_lines
                -
                vmp.unknown_sales_lines
            )
            /
            NULLIF(vmp.total_order_lines, 0)
        ) AS average_sales_coverage_percentage,
        -- Cobertura promedio de beneficios.
        AVG(
            100.0
            *
            (
                vmp.total_order_lines
                -
                vmp.unknown_profit_lines
            )
            /
            NULLIF(vmp.total_order_lines, 0)
        ) AS average_profit_coverage_percentage

    FROM vw_monthly_performance AS vmp

    GROUP BY
        vmp.order_month
),

ranking_estacional AS
(
    SELECT
        e.*,
        -- Clasificación histórica según ventas promedio.
        DENSE_RANK() OVER (
            ORDER BY e.average_sales DESC
        ) AS average_sales_rank,
        -- Clasificación histórica según beneficio promedio.
        DENSE_RANK() OVER (
            ORDER BY e.average_profit DESC
        ) AS average_profit_rank,
        -- Clasificación histórica según volumen de pedidos.
        DENSE_RANK() OVER (
            ORDER BY e.average_orders DESC
        ) AS average_orders_rank

    FROM estacionalidad AS e
)

SELECT
    order_month,
    month_name,

    observed_periods,
    observed_years,

    ROUND(average_orders, 2)
        AS average_orders,

    ROUND(average_distinct_customers, 2)
        AS average_distinct_customers,

    ROUND(average_sales, 2)
        AS average_sales,

    ROUND(average_quantity, 2)
        AS average_quantity,

    ROUND(average_profit, 2)
        AS average_profit,

    ROUND(average_complete_order_value, 2)
        AS average_complete_order_value,

    ROUND(minimum_sales, 2)
        AS minimum_sales,

    ROUND(maximum_sales, 2)
        AS maximum_sales,

    ROUND(minimum_profit, 2)
        AS minimum_profit,

    ROUND(maximum_profit, 2)
        AS maximum_profit,

    average_sales_rank,
    average_profit_rank,
    average_orders_rank,

    ROUND(
        average_sales_coverage_percentage,
        2
    ) AS average_sales_coverage_percentage,

    ROUND(
        average_profit_coverage_percentage,
        2
    ) AS average_profit_coverage_percentage

FROM ranking_estacional

ORDER BY order_month;


-- Verificamos cuántos meses del calendario están
-- representados en el conjunto de datos.
SELECT
    COUNT(DISTINCT order_month)
        AS meses_distintos,

    MIN(order_month)
        AS primer_mes,

    MAX(order_month)
        AS ultimo_mes

FROM vw_monthly_performance;


-- Verificamos cuántos años diferentes contribuyen
-- al análisis de cada mes.
SELECT
    order_month,

    CASE order_month
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

    COUNT(DISTINCT order_year)
        AS observed_years

FROM vw_monthly_performance

GROUP BY order_month

ORDER BY order_month;


-- Ranking de meses por ventas promedio históricas
SELECT
    order_month,

    CASE order_month
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

    COUNT(*) AS observed_years,

    ROUND(
        AVG(total_sales),
        2
    ) AS average_sales,

    ROUND(
        AVG(total_profit),
        2
    ) AS average_profit,

    ROUND(
        AVG(total_orders),
        2
    ) AS average_orders

FROM vw_monthly_performance

GROUP BY order_month

ORDER BY
    average_sales DESC,
    order_month;


