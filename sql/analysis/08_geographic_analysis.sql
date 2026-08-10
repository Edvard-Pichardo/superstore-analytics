/*
Archivo      : 08_geographic_analysis.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Análisis geográfico del desempeño comercial,
               considerando ventas, beneficio, clientes,
               pedidos, rentabilidad y logística.
*/

USE superstore_analytics;


-- Ranking general de ciudades
-- Comparamos las ciudades según ventas, beneficio,
-- volumen de pedidos y margen comparable.
WITH ranking_ciudades AS
(
    SELECT
        vgp.region,
        vgp.country,
        vgp.state,
        vgp.city,
        vgp.distinct_postal_codes,
        vgp.total_orders,
        vgp.distinct_customers,
        vgp.total_order_lines,
        vgp.total_sales,
        vgp.total_quantity,
        vgp.total_profit,
        vgp.average_complete_order_value,
        vgp.comparable_profit_margin_percentage,
        vgp.average_shipping_days,
        vgp.minimum_shipping_days,
        vgp.maximum_shipping_days,
        vgp.complete_loss_making_orders,
        vgp.unknown_sales_lines,
        vgp.unknown_quantity_lines,
        vgp.unknown_profit_lines,
        vgp.orders_with_unknown_sales,
        vgp.orders_with_unknown_profit,
        -- Participación de cada ciudad sobre las
        -- ventas conocidas de todo el negocio.
        100.0
        *
        vgp.total_sales
        /
        NULLIF(
            SUM(vgp.total_sales) OVER (),
            0
        ) AS global_sales_share_percentage,
        -- Ranking global por ventas.
        DENSE_RANK() OVER
        (
            ORDER BY vgp.total_sales DESC
        ) AS sales_rank,
        -- Ranking global por beneficio.
        DENSE_RANK() OVER
        (
            ORDER BY vgp.total_profit DESC
        ) AS profit_rank,
        -- Ranking global por margen comparable.
        DENSE_RANK() OVER
        (
            ORDER BY
                vgp.comparable_profit_margin_percentage DESC
        ) AS margin_rank,
        -- Ranking de ventas dentro de cada región.
        DENSE_RANK() OVER
        (
            PARTITION BY vgp.region
            ORDER BY vgp.total_sales DESC
        ) AS regional_sales_rank
    FROM vw_geographic_performance AS vgp
)

SELECT
    region,
    country,
    state,
    city,
    distinct_postal_codes,
    total_orders,
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
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    minimum_shipping_days,
    maximum_shipping_days,
    ROUND(
        global_sales_share_percentage,
        4
    ) AS global_sales_share_percentage,
    sales_rank,
    profit_rank,
    margin_rank,
    regional_sales_rank,
    -- Diferencia entre la posición por ventas
    -- y la posición obtenida por beneficio.
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
FROM ranking_ciudades
ORDER BY
    sales_rank,
    country,
    state,
    city;


-- Top 20 ciudades por ventas conocidas.
SELECT
    region,
    country,
    state,
    city,
    total_orders,
    distinct_customers,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
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
    complete_loss_making_orders,
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
FROM vw_geographic_performance
ORDER BY
    total_sales DESC,
    country,
    state,
    city
LIMIT 20;




-- Top 20 ciudades por beneficio conocido.
SELECT
    region,
    country,
    state,
    city,
    total_orders,
    distinct_customers,
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
        average_shipping_days,
        2
    ) AS average_shipping_days
FROM vw_geographic_performance
ORDER BY
    total_profit DESC,
    country,
    state,
    city
LIMIT 20;




-- Validamos que todas las ciudades del modelo analítico
-- estén representadas en la vista geográfica.
SELECT
    COUNT(*) AS total_cities,
    COUNT(
        DISTINCT
        region,
        country,
        state,
        city
    ) AS unique_cities,
    COUNT(*)
    -
    COUNT(
        DISTINCT
        region,
        country,
        state,
        city
    ) AS duplicates
FROM vw_geographic_performance;




-- Ciudades de alto volumen y baja rentabilidad
-- Comparamos cada ciudad contra las ventas y el margen
-- promedio de todas las ciudades del negocio.
WITH referencias AS
(
    SELECT
        AVG(total_sales)
            AS average_city_sales,
        AVG(comparable_profit_margin_percentage)
            AS average_city_margin
    FROM vw_geographic_performance
    WHERE total_sales IS NOT NULL
),

evaluacion_ciudades AS
(
    SELECT
        vgp.region,
        vgp.country,
        vgp.state,
        vgp.city,
        vgp.distinct_postal_codes,
        vgp.total_orders,
        vgp.distinct_customers,
        vgp.total_order_lines,
        vgp.total_sales,
        vgp.total_quantity,
        vgp.total_profit,
        vgp.average_complete_order_value,
        vgp.comparable_profit_margin_percentage,
        vgp.average_shipping_days,
        vgp.complete_loss_making_orders,
        vgp.orders_with_unknown_profit,
        vgp.unknown_sales_lines,
        vgp.unknown_profit_lines,
        r.average_city_sales,
        r.average_city_margin,
        -- Clasificamos cada ciudad según su volumen
        -- comercial y su margen comparable.
        CASE
            WHEN vgp.total_sales IS NULL
                THEN 'Ventas desconocidas'
            WHEN vgp.comparable_profit_margin_percentage IS NULL
                THEN 'Sin margen comparable'
            WHEN vgp.total_sales >= r.average_city_sales
             AND vgp.comparable_profit_margin_percentage
                    >= r.average_city_margin
                THEN 'Alto volumen - Alta rentabilidad'
            WHEN vgp.total_sales >= r.average_city_sales
             AND vgp.comparable_profit_margin_percentage
                    < r.average_city_margin
                THEN 'Alto volumen - Baja rentabilidad'
            WHEN vgp.total_sales < r.average_city_sales
             AND vgp.comparable_profit_margin_percentage
                    >= r.average_city_margin
                THEN 'Bajo volumen - Alta rentabilidad'
            ELSE 'Bajo volumen - Baja rentabilidad'
        END AS geographic_profile,
        -- Clasificamos también el resultado financiero
        -- absoluto de cada ciudad.
        CASE
            WHEN vgp.total_profit < 0
                THEN 'Beneficio acumulado negativo'
            WHEN vgp.complete_loss_making_orders > 0
                THEN 'Presenta pedidos completos con pérdidas'
            ELSE 'Sin pérdidas completas conocidas'
        END AS profitability_status
    FROM vw_geographic_performance AS vgp
    CROSS JOIN referencias AS r
)

SELECT
    region,
    country,
    state,
    city,
    geographic_profile,
    profitability_status,
    distinct_postal_codes,
    total_orders,
    distinct_customers,
    total_order_lines,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        average_city_sales,
        2
    ) AS sales_benchmark,
    ROUND(
        total_sales
        -
        average_city_sales,
        2
    ) AS sales_vs_benchmark,
    total_quantity,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    ROUND(
        average_city_margin,
        2
    ) AS margin_benchmark,
    ROUND(
        comparable_profit_margin_percentage
        -
        average_city_margin,
        2
    ) AS margin_vs_benchmark_points,
    ROUND(
        average_complete_order_value,
        2
    ) AS average_complete_order_value,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
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
FROM evaluacion_ciudades
ORDER BY
    CASE geographic_profile
        WHEN 'Alto volumen - Baja rentabilidad' THEN 1
        WHEN 'Alto volumen - Alta rentabilidad' THEN 2
        WHEN 'Bajo volumen - Baja rentabilidad' THEN 3
        WHEN 'Bajo volumen - Alta rentabilidad' THEN 4
        WHEN 'Sin margen comparable' THEN 5
        ELSE 6
    END,
    total_sales DESC,
    country,
    state,
    city;




-- Desempeño comercial por región
-- Comparamos las regiones según volumen comercial,
-- rentabilidad, clientes, logística y cobertura de datos.
WITH rendimiento_regional AS
(
    SELECT
        vos.region,
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
        -- Margen calculado únicamente con pedidos
        -- cuyas ventas y beneficios están completos.
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
        AVG(vos.shipping_days)
            AS average_shipping_days,
        MIN(vos.shipping_days)
            AS minimum_shipping_days,
        MAX(vos.shipping_days)
            AS maximum_shipping_days,
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
    GROUP BY vos.region
),

ranking_regional AS
(
    SELECT
        rr.*,
        -- Participación de cada región sobre las ventas.
        100.0
        *
        rr.total_sales
        /
        NULLIF(
            SUM(rr.total_sales) OVER (),
            0
        ) AS sales_share_percentage,
        -- Participación de cada región sobre los pedidos.
        100.0
        *
        rr.total_orders
        /
        NULLIF(
            SUM(rr.total_orders) OVER (),
            0
        ) AS order_share_percentage,
        -- Rankings regionales.
        DENSE_RANK() OVER
        (
            ORDER BY rr.total_sales DESC
        ) AS sales_rank,
        DENSE_RANK() OVER
        (
            ORDER BY rr.total_profit DESC
        ) AS profit_rank,
        DENSE_RANK() OVER
        (
            ORDER BY
                rr.comparable_profit_margin_percentage DESC
        ) AS margin_rank
    FROM rendimiento_regional AS rr
)

SELECT
    region,
    total_orders,
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
    ROUND(
        order_share_percentage,
        2
    ) AS order_share_percentage,
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
    sales_rank,
    profit_rank,
    margin_rank,
    -- Diferencia entre posición por ventas y beneficio.
    CAST(profit_rank AS SIGNED)
    -
    CAST(sales_rank AS SIGNED)
        AS sales_profit_rank_gap,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    minimum_shipping_days,
    maximum_shipping_days,
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
FROM ranking_regional
ORDER BY
    sales_rank,
    region;




-- Validamos que las cuatro regiones representen
-- el 100% de los pedidos y ventas.
WITH resumen_regional AS
(
    SELECT
        region,
        COUNT(*) AS total_orders,
        SUM(total_sales) AS total_sales
    FROM vw_order_summary
    GROUP BY region
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
    ) AS order_share_total,
    ROUND(
        100.0
        *
        SUM(total_sales)
        /
        NULLIF(
            (
                SELECT SUM(total_sales)
                FROM vw_order_summary
            ),
            0
        ),
        2
    ) AS sales_share_total
FROM resumen_regional;




-- Verificamos que estén representadas todas las regiones.
SELECT
    COUNT(DISTINCT region)
        AS total_regions
FROM vw_order_summary;




-- Desempeño comercial por estado
-- Analizamos ventas, beneficio, clientes, pedidos,
-- rentabilidad y cobertura para cada estado.
WITH rendimiento_estatal AS
(
    SELECT
        vos.region,
        vos.country,
        vos.state,
        COUNT(*) AS total_orders,
        COUNT(DISTINCT vos.customer_id)
            AS distinct_customers,
        COUNT(DISTINCT vos.city)
            AS distinct_cities,
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
        AVG(vos.shipping_days)
            AS average_shipping_days,
        MIN(vos.shipping_days)
            AS minimum_shipping_days,
        MAX(vos.shipping_days)
            AS maximum_shipping_days,
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
        vos.region,
        vos.country,
        vos.state
),

ranking_estatal AS
(
    SELECT
        re.*,
        -- Participación del estado sobre las ventas globales.
        100.0
        *
        re.total_sales
        /
        NULLIF(
            SUM(re.total_sales) OVER (),
            0
        ) AS global_sales_share_percentage,
        -- Ranking global por ventas.
        DENSE_RANK() OVER
        (
            ORDER BY re.total_sales DESC
        ) AS global_sales_rank,
        -- Ranking global por beneficio.
        DENSE_RANK() OVER
        (
            ORDER BY re.total_profit DESC
        ) AS global_profit_rank,
        -- Ranking global por margen comparable.
        DENSE_RANK() OVER
        (
            ORDER BY
                re.comparable_profit_margin_percentage DESC
        ) AS global_margin_rank,
        -- Ranking de ventas dentro de cada región.
        DENSE_RANK() OVER
        (
            PARTITION BY re.region
            ORDER BY re.total_sales DESC
        ) AS regional_sales_rank,
        -- Ranking de beneficio dentro de cada región.
        DENSE_RANK() OVER
        (
            PARTITION BY re.region
            ORDER BY re.total_profit DESC
        ) AS regional_profit_rank,
        -- Ranking de ventas dentro de cada país.
        DENSE_RANK() OVER
        (
            PARTITION BY re.country
            ORDER BY re.total_sales DESC
        ) AS country_sales_rank
    FROM rendimiento_estatal AS re
)

SELECT
    region,
    country,
    state,
    distinct_cities,
    total_orders,
    distinct_customers,
    total_order_lines,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        global_sales_share_percentage,
        2
    ) AS global_sales_share_percentage,
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
    global_sales_rank,
    global_profit_rank,
    global_margin_rank,
    regional_sales_rank,
    regional_profit_rank,
    country_sales_rank,
    -- Diferencia entre posición global por ventas
    -- y posición global por beneficio.
    CAST(global_profit_rank AS SIGNED)
    -
    CAST(global_sales_rank AS SIGNED)
        AS sales_profit_rank_gap,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    minimum_shipping_days,
    maximum_shipping_days,
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
FROM ranking_estatal
ORDER BY
    global_sales_rank,
    country,
    state;




-- Estados con mayor volumen de ventas conocidas.
SELECT
    region,
    country,
    state,
    total_orders,
    distinct_customers,
    distinct_cities,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
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
    complete_loss_making_orders
FROM
(
    SELECT
        vos.region,
        vos.country,
        vos.state,
        COUNT(*) AS total_orders,
        COUNT(DISTINCT vos.customer_id)
            AS distinct_customers,
        COUNT(DISTINCT vos.city)
            AS distinct_cities,
        SUM(vos.total_sales)
            AS total_sales,
        SUM(vos.total_profit)
            AS total_profit,
        AVG(
            CASE
                WHEN vos.unknown_sales_lines = 0
                    THEN vos.total_sales
            END
        ) AS average_complete_order_value,
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
        AVG(vos.shipping_days)
            AS average_shipping_days,
        SUM(
            CASE
                WHEN vos.unknown_profit_lines = 0
                 AND vos.total_profit < 0
                    THEN 1
                ELSE 0
            END
        ) AS complete_loss_making_orders
    FROM vw_order_summary AS vos
    GROUP BY
        vos.region,
        vos.country,
        vos.state
) AS estados
ORDER BY
    total_sales DESC,
    country,
    state
LIMIT 15;




-- Estados cuyo beneficio conocido acumulado es negativo.
SELECT
    region,
    country,
    state,
    COUNT(*) AS total_orders,
    COUNT(DISTINCT customer_id)
        AS distinct_customers,
    ROUND(
        SUM(total_sales),
        2
    ) AS total_sales,
    ROUND(
        SUM(total_profit),
        2
    ) AS total_profit,
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
    ) AS complete_loss_making_order_percentage,
    ROUND(
        100.0
        *
        (
            SUM(total_order_lines)
            -
            SUM(unknown_profit_lines)
        )
        /
        NULLIF(
            SUM(total_order_lines),
            0
        ),
        2
    ) AS profit_coverage_percentage
FROM vw_order_summary
GROUP BY
    region,
    country,
    state
HAVING SUM(total_profit) < 0
ORDER BY
    total_profit ASC,
    total_sales DESC,
    country,
    state;




-- Validamos que la agregación por estado conserve
-- todos los pedidos, ventas y beneficios del negocio.
WITH estados AS
(
    SELECT
        region,
        country,
        state,
        COUNT(*) AS total_orders,
        SUM(total_sales) AS total_sales,
        SUM(total_profit) AS total_profit
    FROM vw_order_summary
    GROUP BY
        region,
        country,
        state
)

SELECT
    SUM(total_orders)
        AS state_orders,
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS original_orders,
    SUM(total_orders)
    -
    (
        SELECT COUNT(*)
        FROM vw_order_summary
    ) AS order_difference,
    ROUND(
        SUM(total_sales),
        6
    ) AS state_sales,
    ROUND(
        (
            SELECT SUM(total_sales)
            FROM vw_order_summary
        ),
        6
    ) AS original_sales,
    ROUND(
        SUM(total_sales)
        -
        (
            SELECT SUM(total_sales)
            FROM vw_order_summary
        ),
        6
    ) AS sales_difference,
    ROUND(
        SUM(total_profit),
        6
    ) AS state_profit,
    ROUND(
        (
            SELECT SUM(total_profit)
            FROM vw_order_summary
        ),
        6
    ) AS original_profit,
    ROUND(
        SUM(total_profit)
        -
        (
            SELECT SUM(total_profit)
            FROM vw_order_summary
        ),
        6
    ) AS profit_difference
FROM estados;




-- Desempeño comercial por país
-- Comparamos los países según ventas, beneficio,
-- clientes, pedidos, rentabilidad y logística.
WITH rendimiento_paises AS
(
    SELECT
        vos.country,
        COUNT(DISTINCT vos.region)
            AS distinct_regions,
        COUNT(DISTINCT vos.state)
            AS distinct_states,
        COUNT(DISTINCT vos.city)
            AS distinct_cities,
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
        -- Margen calculado únicamente con pedidos
        -- cuyas ventas y beneficios están completos.
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
        AVG(vos.shipping_days)
            AS average_shipping_days,
        MIN(vos.shipping_days)
            AS minimum_shipping_days,
        MAX(vos.shipping_days)
            AS maximum_shipping_days,
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
    GROUP BY vos.country
),

ranking_paises AS
(
    SELECT
        rp.*,
        -- Participación sobre las ventas globales.
        100.0
        *
        rp.total_sales
        /
        NULLIF(
            SUM(rp.total_sales) OVER (),
            0
        ) AS sales_share_percentage,
        -- Participación sobre los pedidos globales.
        100.0
        *
        rp.total_orders
        /
        NULLIF(
            SUM(rp.total_orders) OVER (),
            0
        ) AS order_share_percentage,
        -- Participación sobre los clientes del negocio.
        100.0
        *
        rp.distinct_customers
        /
        NULLIF(
            SUM(rp.distinct_customers) OVER (),
            0
        ) AS customer_presence_share_percentage,
        DENSE_RANK() OVER
        (
            ORDER BY rp.total_sales DESC
        ) AS sales_rank,
        DENSE_RANK() OVER
        (
            ORDER BY rp.total_profit DESC
        ) AS profit_rank,
        DENSE_RANK() OVER
        (
            ORDER BY
                rp.comparable_profit_margin_percentage DESC
        ) AS margin_rank,
        DENSE_RANK() OVER
        (
            ORDER BY rp.average_complete_order_value DESC
        ) AS average_order_value_rank
    FROM rendimiento_paises AS rp
)

SELECT
    country,
    distinct_regions,
    distinct_states,
    distinct_cities,
    total_orders,
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
    ROUND(
        order_share_percentage,
        2
    ) AS order_share_percentage,
    ROUND(
        customer_presence_share_percentage,
        2
    ) AS customer_presence_share_percentage,
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
    sales_rank,
    profit_rank,
    margin_rank,
    average_order_value_rank,
    -- Diferencia entre posición por ventas y beneficio.
    CAST(profit_rank AS SIGNED)
    -
    CAST(sales_rank AS SIGNED)
        AS sales_profit_rank_gap,
    ROUND(
        average_shipping_days,
        2
    ) AS average_shipping_days,
    minimum_shipping_days,
    maximum_shipping_days,
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
FROM ranking_paises
ORDER BY
    sales_rank,
    country;




-- Países cuyo beneficio conocido acumulado es negativo.
SELECT
    country,
    COUNT(*) AS total_orders,
    COUNT(DISTINCT customer_id)
        AS distinct_customers,
    ROUND(
        SUM(total_sales),
        2
    ) AS total_sales,
    ROUND(
        SUM(total_profit),
        2
    ) AS total_profit,
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
    ) AS complete_loss_making_order_percentage,
    ROUND(
        100.0
        *
        (
            SUM(total_order_lines)
            -
            SUM(unknown_profit_lines)
        )
        /
        NULLIF(
            SUM(total_order_lines),
            0
        ),
        2
    ) AS profit_coverage_percentage
FROM vw_order_summary
GROUP BY country
HAVING SUM(total_profit) < 0
ORDER BY
    total_profit ASC,
    total_sales DESC,
    country;




-- Validamos la participación total de los países.
WITH resumen_paises AS
(
    SELECT
        country,
        COUNT(*) AS total_orders,
        SUM(total_sales) AS total_sales
    FROM vw_order_summary
    GROUP BY country
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
    ) AS order_share_total,
    ROUND(
        100.0
        *
        SUM(total_sales)
        /
        NULLIF(
            (
                SELECT SUM(total_sales)
                FROM vw_order_summary
            ),
            0
        ),
        2
    ) AS sales_share_total
FROM resumen_paises;




-- Verificamos el número de países representados.
SELECT
    COUNT(DISTINCT country)
        AS total_countries
FROM vw_order_summary;




-- Concentración geográfica de ventas y análisis ABC por ciudad
-- Ordenamos las ciudades según sus ventas conocidas y
-- calculamos su participación acumulada sobre el negocio.
WITH ventas_ciudades AS
(
    SELECT
        vgp.region,
        vgp.country,
        vgp.state,
        vgp.city,
        vgp.total_orders,
        vgp.distinct_customers,
        vgp.total_sales,
        vgp.total_profit,
        vgp.comparable_profit_margin_percentage,
        ROW_NUMBER() OVER
        (
            ORDER BY
                vgp.total_sales DESC,
                vgp.country,
                vgp.state,
                vgp.city
        ) AS city_position,
        100.0
        *
        vgp.total_sales
        /
        NULLIF(
            SUM(vgp.total_sales) OVER (),
            0
        ) AS sales_share_percentage
    FROM vw_geographic_performance AS vgp
    WHERE vgp.total_sales IS NOT NULL
),

ventas_acumuladas AS
(
    SELECT
        vc.*,
        SUM(vc.sales_share_percentage) OVER
        (
            ORDER BY
                vc.total_sales DESC,
                vc.country,
                vc.state,
                vc.city
            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND CURRENT ROW
        ) AS cumulative_sales_percentage
    FROM ventas_ciudades AS vc
),

clasificacion_abc AS
(
    SELECT
        va.*,
        CASE
            WHEN va.cumulative_sales_percentage <= 80
                THEN 'A'
            WHEN va.cumulative_sales_percentage <= 95
                THEN 'B'
            ELSE 'C'
        END AS abc_class
    FROM ventas_acumuladas AS va
)

SELECT
    city_position,
    region,
    country,
    state,
    city,
    total_orders,
    distinct_customers,
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
        sales_share_percentage,
        4
    ) AS sales_share_percentage,
    ROUND(
        cumulative_sales_percentage,
        2
    ) AS cumulative_sales_percentage,
    abc_class
FROM clasificacion_abc
ORDER BY city_position;




-- Cantidad de ciudades necesarias para alcanzar
-- distintos niveles de concentración de ventas.
WITH ventas_ciudades AS
(
    SELECT
        vgp.country,
        vgp.state,
        vgp.city,
        vgp.total_sales,
        ROW_NUMBER() OVER
        (
            ORDER BY
                vgp.total_sales DESC,
                vgp.country,
                vgp.state,
                vgp.city
        ) AS city_position,
        100.0
        *
        vgp.total_sales
        /
        NULLIF(
            SUM(vgp.total_sales) OVER (),
            0
        ) AS sales_share_percentage
    FROM vw_geographic_performance AS vgp
    WHERE vgp.total_sales IS NOT NULL
),

ventas_acumuladas AS
(
    SELECT
        vc.*,
        SUM(vc.sales_share_percentage) OVER
        (
            ORDER BY
                vc.total_sales DESC,
                vc.country,
                vc.state,
                vc.city
            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND CURRENT ROW
        ) AS cumulative_sales_percentage
    FROM ventas_ciudades AS vc
)

SELECT
    COUNT(*) AS cities_with_known_sales,
    MIN(
        CASE
            WHEN cumulative_sales_percentage >= 50
                THEN city_position
        END
    ) AS cities_for_50_percent_sales,
    MIN(
        CASE
            WHEN cumulative_sales_percentage >= 80
                THEN city_position
        END
    ) AS cities_for_80_percent_sales,
    MIN(
        CASE
            WHEN cumulative_sales_percentage >= 95
                THEN city_position
        END
    ) AS cities_for_95_percent_sales
FROM ventas_acumuladas;




-- Distribución de ciudades y ventas por clase ABC.
WITH ventas_ciudades AS
(
    SELECT
        vgp.country,
        vgp.state,
        vgp.city,
        vgp.total_sales,
        100.0
        *
        vgp.total_sales
        /
        NULLIF(
            SUM(vgp.total_sales) OVER (),
            0
        ) AS sales_share_percentage
    FROM vw_geographic_performance AS vgp
    WHERE vgp.total_sales IS NOT NULL
),

ventas_acumuladas AS
(
    SELECT
        vc.*,
        SUM(vc.sales_share_percentage) OVER
        (
            ORDER BY
                vc.total_sales DESC,
                vc.country,
                vc.state,
                vc.city
            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND CURRENT ROW
        ) AS cumulative_sales_percentage
    FROM ventas_ciudades AS vc
),

clasificacion AS
(
    SELECT
        va.*,
        CASE
            WHEN va.cumulative_sales_percentage <= 80
                THEN 'A'
            WHEN va.cumulative_sales_percentage <= 95
                THEN 'B'
            ELSE 'C'
        END AS abc_class
    FROM ventas_acumuladas AS va
)

SELECT
    abc_class,
    COUNT(*) AS total_cities,
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
    ) AS city_share_percentage,
    ROUND(
        SUM(total_sales),
        2
    ) AS total_sales,
    ROUND(
        SUM(sales_share_percentage),
        2
    ) AS sales_share_percentage,
    ROUND(
        AVG(total_sales),
        2
    ) AS average_city_sales
FROM clasificacion
GROUP BY abc_class
ORDER BY abc_class;




-- Validamos que la participación acumulada de ventas
-- represente el 100% de las ventas conocidas.
WITH participacion_ciudades AS
(
    SELECT
        100.0
        *
        total_sales
        /
        NULLIF(
            SUM(total_sales) OVER (),
            0
        ) AS sales_share_percentage
    FROM vw_geographic_performance
    WHERE total_sales IS NOT NULL
)

SELECT
    COUNT(*) AS cities_with_known_sales,
    ROUND(
        SUM(sales_share_percentage),
        2
    ) AS total_sales_share_percentage
FROM participacion_ciudades;




-- Evolución anual del desempeño por región
-- Analizamos la evolución de pedidos, clientes, ventas,
-- beneficio y margen comparable para cada región y año.
WITH rendimiento_anual AS
(
    SELECT
        vos.region,
        YEAR(vos.order_date) AS order_year,
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
        -- Margen calculado únicamente con pedidos
        -- cuyas ventas y beneficios están completos.
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
        vos.region,
        YEAR(vos.order_date)
),

comparacion_anual AS
(
    SELECT
        ra.*,
        -- Valores del año anterior dentro de la misma región.
        LAG(ra.total_orders) OVER
        (
            PARTITION BY ra.region
            ORDER BY ra.order_year
        ) AS previous_year_orders,
        LAG(ra.distinct_customers) OVER
        (
            PARTITION BY ra.region
            ORDER BY ra.order_year
        ) AS previous_year_customers,
        LAG(ra.total_sales) OVER
        (
            PARTITION BY ra.region
            ORDER BY ra.order_year
        ) AS previous_year_sales,
        LAG(ra.total_profit) OVER
        (
            PARTITION BY ra.region
            ORDER BY ra.order_year
        ) AS previous_year_profit,
        LAG(
            ra.comparable_profit_margin_percentage
        ) OVER
        (
            PARTITION BY ra.region
            ORDER BY ra.order_year
        ) AS previous_year_margin
    FROM rendimiento_anual AS ra
)

SELECT
    region,
    order_year,
    total_orders,
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
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    -- Variación anual del número de pedidos.
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
    -- Variación anual de clientes activos.
    ROUND(
        100.0
        *
        (
            distinct_customers
            -
            previous_year_customers
        )
        /
        NULLIF(previous_year_customers, 0),
        2
    ) AS yoy_customer_growth_percentage,
    -- Variación porcentual anual de las ventas.
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
    ) AS yoy_sales_growth_percentage,
    -- Para el beneficio utilizamos cambio absoluto,
    -- ya que puede pasar entre valores positivos y negativos.
    ROUND(
        total_profit
        -
        previous_year_profit,
        2
    ) AS yoy_profit_absolute_change,
    -- Cambio del margen expresado en puntos porcentuales.
    ROUND(
        comparable_profit_margin_percentage
        -
        previous_year_margin,
        2
    ) AS yoy_margin_change_points,
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
FROM comparacion_anual
ORDER BY
    region,
    order_year;




-- Detectamos años en los que una región aumentó sus ventas
-- mientras su margen comparable se deterioró.
WITH rendimiento_anual AS
(
    SELECT
        vos.region,
        YEAR(vos.order_date) AS order_year,
        SUM(vos.total_sales)
            AS total_sales,
        SUM(vos.total_profit)
            AS total_profit,
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
        ) * 100 AS comparable_profit_margin_percentage
    FROM vw_order_summary AS vos
    GROUP BY
        vos.region,
        YEAR(vos.order_date)
),

comparacion AS
(
    SELECT
        ra.*,
        LAG(ra.total_sales) OVER
        (
            PARTITION BY ra.region
            ORDER BY ra.order_year
        ) AS previous_year_sales,
        LAG(ra.total_profit) OVER
        (
            PARTITION BY ra.region
            ORDER BY ra.order_year
        ) AS previous_year_profit,
        LAG(
            ra.comparable_profit_margin_percentage
        ) OVER
        (
            PARTITION BY ra.region
            ORDER BY ra.order_year
        ) AS previous_year_margin
    FROM rendimiento_anual AS ra
)

SELECT
    region,
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
    ) AS yoy_sales_growth_percentage,
    ROUND(
        previous_year_profit,
        2
    ) AS previous_year_profit,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        total_profit
        -
        previous_year_profit,
        2
    ) AS yoy_profit_absolute_change,
    ROUND(
        previous_year_margin,
        2
    ) AS previous_year_margin,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    ROUND(
        comparable_profit_margin_percentage
        -
        previous_year_margin,
        2
    ) AS yoy_margin_change_points
FROM comparacion
WHERE total_sales > previous_year_sales
  AND comparable_profit_margin_percentage
        < previous_year_margin
ORDER BY
    yoy_margin_change_points ASC,
    yoy_sales_growth_percentage DESC,
    region,
    order_year;




-- Validamos la cobertura temporal de cada región.
SELECT
    region,
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
FROM vw_order_summary
GROUP BY region
ORDER BY region;




-- Contamos las combinaciones observadas entre región y año.
SELECT
    COUNT(*) AS region_year_combinations
FROM
(
    SELECT
        region,
        YEAR(order_date) AS order_year
    FROM vw_order_summary
    GROUP BY
        region,
        YEAR(order_date)
) AS combinaciones;




-- Concentración geográfica de pérdidas
-- Analizamos únicamente las ciudades cuyo beneficio
-- conocido acumulado es negativo y medimos qué proporción
-- representan sobre el total de pérdidas conocidas.
WITH ciudades_con_perdidas AS
(
    SELECT
        vgp.region,
        vgp.country,
        vgp.state,
        vgp.city,
        vgp.total_orders,
        vgp.distinct_customers,
        vgp.total_order_lines,
        vgp.total_sales,
        vgp.total_profit,
        vgp.comparable_profit_margin_percentage,
        vgp.complete_loss_making_orders,
        vgp.orders_with_unknown_profit,
        vgp.unknown_profit_lines,
        ABS(vgp.total_profit)
            AS known_loss_amount
    FROM vw_geographic_performance AS vgp
    WHERE vgp.total_profit < 0
),

participacion_perdidas AS
(
    SELECT
        ccp.*,
        ROW_NUMBER() OVER
        (
            ORDER BY
                ccp.known_loss_amount DESC,
                ccp.country,
                ccp.state,
                ccp.city
        ) AS loss_position,
        100.0
        *
        ccp.known_loss_amount
        /
        NULLIF(
            SUM(ccp.known_loss_amount) OVER (),
            0
        ) AS loss_share_percentage
    FROM ciudades_con_perdidas AS ccp
),

perdidas_acumuladas AS
(
    SELECT
        pp.*,
        SUM(pp.loss_share_percentage) OVER
        (
            ORDER BY
                pp.known_loss_amount DESC,
                pp.country,
                pp.state,
                pp.city
            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND CURRENT ROW
        ) AS cumulative_loss_percentage
    FROM participacion_perdidas AS pp
),

clasificacion_perdidas AS
(
    SELECT
        pa.*,
        CASE
            WHEN pa.cumulative_loss_percentage <= 80
                THEN 'A'
            WHEN pa.cumulative_loss_percentage <= 95
                THEN 'B'
            ELSE 'C'
        END AS loss_concentration_class
    FROM perdidas_acumuladas AS pa
)

SELECT
    loss_position,
    region,
    country,
    state,
    city,
    total_orders,
    distinct_customers,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        known_loss_amount,
        2
    ) AS known_loss_amount,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    ROUND(
        loss_share_percentage,
        2
    ) AS loss_share_percentage,
    ROUND(
        cumulative_loss_percentage,
        2
    ) AS cumulative_loss_percentage,
    loss_concentration_class,
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
FROM clasificacion_perdidas
ORDER BY loss_position;




-- Cantidad de ciudades necesarias para alcanzar
-- el 50%, 80% y 95% de las pérdidas conocidas.
WITH ciudades_con_perdidas AS
(
    SELECT
        country,
        state,
        city,
        ABS(total_profit)
            AS known_loss_amount
    FROM vw_geographic_performance
    WHERE total_profit < 0
),

participacion AS
(
    SELECT
        ccp.*,
        ROW_NUMBER() OVER
        (
            ORDER BY
                ccp.known_loss_amount DESC,
                ccp.country,
                ccp.state,
                ccp.city
        ) AS loss_position,
        100.0
        *
        ccp.known_loss_amount
        /
        NULLIF(
            SUM(ccp.known_loss_amount) OVER (),
            0
        ) AS loss_share_percentage
    FROM ciudades_con_perdidas AS ccp
),

acumulado AS
(
    SELECT
        p.*,
        SUM(p.loss_share_percentage) OVER
        (
            ORDER BY
                p.known_loss_amount DESC,
                p.country,
                p.state,
                p.city
            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND CURRENT ROW
        ) AS cumulative_loss_percentage
    FROM participacion AS p
)

SELECT
    COUNT(*) AS loss_making_cities,
    MIN(
        CASE
            WHEN cumulative_loss_percentage >= 50
                THEN loss_position
        END
    ) AS cities_for_50_percent_losses,
    MIN(
        CASE
            WHEN cumulative_loss_percentage >= 80
                THEN loss_position
        END
    ) AS cities_for_80_percent_losses,
    MIN(
        CASE
            WHEN cumulative_loss_percentage >= 95
                THEN loss_position
        END
    ) AS cities_for_95_percent_losses
FROM acumulado;




-- Top 20 ciudades con mayores pérdidas conocidas.
SELECT
    region,
    country,
    state,
    city,
    total_orders,
    distinct_customers,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        ABS(total_profit),
        2
    ) AS known_loss_amount,
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
FROM vw_geographic_performance
WHERE total_profit < 0
ORDER BY
    total_profit ASC,
    total_sales DESC,
    country,
    state,
    city
LIMIT 20;




-- Detectamos ciudades con ventas superiores al promedio
-- pero con beneficio conocido acumulado negativo.
WITH referencia AS
(
    SELECT
        AVG(total_sales)
            AS average_city_sales
    FROM vw_geographic_performance
    WHERE total_sales IS NOT NULL
)

SELECT
    vgp.region,
    vgp.country,
    vgp.state,
    vgp.city,
    vgp.total_orders,
    vgp.distinct_customers,
    ROUND(
        vgp.total_sales,
        2
    ) AS total_sales,
    ROUND(
        r.average_city_sales,
        2
    ) AS average_city_sales,
    ROUND(
        vgp.total_sales
        -
        r.average_city_sales,
        2
    ) AS sales_above_average,
    ROUND(
        vgp.total_profit,
        2
    ) AS total_profit,
    ROUND(
        vgp.comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    vgp.complete_loss_making_orders,
    ROUND(
        100.0
        *
        (
            vgp.total_order_lines
            -
            vgp.unknown_profit_lines
        )
        /
        NULLIF(vgp.total_order_lines, 0),
        2
    ) AS profit_coverage_percentage
FROM vw_geographic_performance AS vgp
CROSS JOIN referencia AS r
WHERE vgp.total_sales >= r.average_city_sales
  AND vgp.total_profit < 0
ORDER BY
    vgp.total_sales DESC,
    vgp.total_profit ASC,
    vgp.country,
    vgp.state,
    vgp.city;




-- Validamos la suma de las pérdidas de las ciudades.
WITH ciudades_negativas AS
(
    SELECT
        region,
        country,
        state,
        city,
        total_profit
    FROM vw_geographic_performance
    WHERE total_profit < 0
)

SELECT
    COUNT(*) AS loss_making_cities,
    ROUND(
        SUM(total_profit),
        2
    ) AS total_negative_profit,
    ROUND(
        SUM(ABS(total_profit)),
        2
    ) AS total_known_loss_amount,
    ROUND(
        100.0
        *
        SUM(
            ABS(total_profit)
        )
        /
        NULLIF(
            SUM(
                ABS(total_profit)
            ),
            0
        ),
        2
    ) AS validated_loss_share_percentage
FROM ciudades_negativas;




-- Validación y conciliación geográfica global
-- Comprobamos que país, región, estado y ciudad
-- reproduzcan los totales globales del negocio.
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

nivel_pais AS
(
    SELECT
        country,
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

nivel_region AS
(
    SELECT
        region,
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

nivel_estado AS
(
    SELECT
        region,
        country,
        state,
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
        region,
        country,
        state
),

resumen_niveles AS
(
    SELECT
        'Country' AS geographic_level,
        COUNT(*) AS geographic_groups,
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
    FROM nivel_pais

    UNION ALL

    SELECT
        'Region',
        COUNT(*),
        SUM(total_orders),
        SUM(total_order_lines),
        SUM(total_sales),
        SUM(total_quantity),
        SUM(total_profit)
    FROM nivel_region

    UNION ALL

    SELECT
        'State',
        COUNT(*),
        SUM(total_orders),
        SUM(total_order_lines),
        SUM(total_sales),
        SUM(total_quantity),
        SUM(total_profit)
    FROM nivel_estado

    UNION ALL

    SELECT
        'City',
        COUNT(*),
        SUM(total_orders),
        SUM(total_order_lines),
        SUM(total_sales),
        SUM(total_quantity),
        SUM(total_profit)
    FROM vw_geographic_performance
)

SELECT
    rn.geographic_level,
    rn.geographic_groups,
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
    CASE rn.geographic_level
        WHEN 'Country' THEN 1
        WHEN 'Region' THEN 2
        WHEN 'State' THEN 3
        WHEN 'City' THEN 4
    END;




-- Validamos la cardinalidad de la estructura geográfica.
SELECT
    COUNT(DISTINCT country)
        AS total_countries,
    COUNT(DISTINCT region)
        AS total_regions,
    COUNT(
        DISTINCT
        country,
        state
    ) AS total_states,
    COUNT(
        DISTINCT
        country,
        state,
        city
    ) AS total_cities
FROM vw_order_summary;




-- Verificamos que ningún pedido tenga
-- información geográfica incompleta.
SELECT
    SUM(
        CASE
            WHEN country IS NULL THEN 1
            ELSE 0
        END
    ) AS orders_without_country,
    SUM(
        CASE
            WHEN region IS NULL THEN 1
            ELSE 0
        END
    ) AS orders_without_region,
    SUM(
        CASE
            WHEN state IS NULL THEN 1
            ELSE 0
        END
    ) AS orders_without_state,
    SUM(
        CASE
            WHEN city IS NULL THEN 1
            ELSE 0
        END
    ) AS orders_without_city
FROM vw_order_summary;




-- Cada order_key debe aparecer una sola vez en
-- la vista resumida y tener una única ubicación.
SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_key)
        AS unique_order_keys,
    COUNT(*)
    -
    COUNT(DISTINCT order_key)
        AS duplicated_order_keys
FROM vw_order_summary;




-- Resumen final de integridad geográfica.
SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_key)
        AS unique_orders,
    COUNT(DISTINCT country)
        AS total_countries,
    COUNT(DISTINCT region)
        AS total_regions,
    COUNT(
        DISTINCT
        country,
        state
    ) AS total_states,
    COUNT(
        DISTINCT
        country,
        state,
        city
    ) AS total_cities,
    ROUND(
        SUM(total_sales),
        2
    ) AS total_sales,
    ROUND(
        SUM(total_profit),
        2
    ) AS total_profit
FROM vw_order_summary;