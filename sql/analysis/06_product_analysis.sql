/*
Archivo      : 06_product_analysis.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Análisis del desempeño comercial de los
               productos, considerando ventas, beneficio,
               margen, participación, pérdidas y cobertura
               de información.
*/

USE superstore_analytics;

-- Ranking general de productos
-- Comparamos todos los productos del catálogo según:
-- 1. Ventas conocidas.
-- 2. Beneficio conocido.
-- 3. Margen comparable.
-- 4. Participación sobre las ventas del negocio.
-- 5. Posición dentro de su propia subcategoría.
-- product_key se utiliza como identificador principal
-- porque algunos product_id originales fueron reutilizados.

WITH ranking_productos AS
(
    SELECT
        vpp.product_key,
        vpp.product_id,
        vpp.product_name,
        vpp.category,
        vpp.sub_category,
        vpp.first_order_date,
        vpp.last_order_date,
        vpp.total_orders,
        vpp.total_order_lines,
        vpp.distinct_customers,
        vpp.total_sales,
        vpp.total_quantity,
        vpp.total_profit,
        vpp.average_line_discount,
        vpp.comparable_average_unit_sales,
        vpp.comparable_profit_margin_percentage,
        vpp.loss_making_lines,
        vpp.unknown_sales_lines,
        vpp.unknown_quantity_lines,
        vpp.unknown_profit_lines,
        -- Participación del producto sobre las ventas
        -- conocidas de todo el negocio.
        100.0
        *
        vpp.total_sales
        /
        NULLIF(
            SUM(vpp.total_sales) OVER (),
            0
        ) AS global_sales_share_percentage,
        -- Ranking global por ventas.
        DENSE_RANK() OVER (
            ORDER BY vpp.total_sales DESC
        ) AS global_sales_rank,
        -- Ranking global por beneficio.
        DENSE_RANK() OVER (
            ORDER BY vpp.total_profit DESC
        ) AS global_profit_rank,
        -- Ranking global por margen comparable.
        DENSE_RANK() OVER (
            ORDER BY
                vpp.comparable_profit_margin_percentage DESC
        ) AS global_margin_rank,
        -- Ranking de ventas dentro de cada subcategoría.
        DENSE_RANK() OVER (
            PARTITION BY
                vpp.category,
                vpp.sub_category
            ORDER BY vpp.total_sales DESC
        ) AS subcategory_sales_rank
    FROM vw_product_performance AS vpp
)

SELECT
    product_key,
    product_id,
    product_name,
    category,
    sub_category,
    first_order_date,
    last_order_date,
    total_orders,
    total_order_lines,
    distinct_customers,
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
        comparable_average_unit_sales,
        2
    ) AS comparable_average_unit_sales,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    ROUND(
        global_sales_share_percentage,
        4
    ) AS global_sales_share_percentage,
    global_sales_rank,
    global_profit_rank,
    global_margin_rank,
    subcategory_sales_rank,
    -- Diferencia entre la posición por ventas
    -- y la posición obtenida por beneficio.
    CAST(global_profit_rank AS SIGNED)
    -
    CAST(global_sales_rank AS SIGNED)
        AS sales_profit_rank_gap,
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
FROM ranking_productos
ORDER BY
    global_sales_rank,
    product_name,
    product_key;



-- Top 20 productos por ventas conocidas.
SELECT
    product_key,
    product_id,
    product_name,
    category,
    sub_category,
    total_orders,
    distinct_customers,
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
    loss_making_lines,
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
FROM vw_product_performance
ORDER BY
    total_sales DESC,
    product_name,
    product_key
LIMIT 20;



-- Top 20 productos por beneficio conocido.
SELECT
    product_key,
    product_id,
    product_name,
    category,
    sub_category,
    total_orders,
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
    loss_making_lines
FROM vw_product_performance
ORDER BY
    total_profit DESC,
    product_name,
    product_key
LIMIT 20;



-- Validamos la cantidad de productos disponibles.
SELECT
    (SELECT COUNT(*) FROM products)
        AS productos_modelo,
    (SELECT COUNT(*) FROM vw_product_performance)
        AS productos_analizados,
    (SELECT COUNT(*) FROM vw_product_performance)
    -
    (SELECT COUNT(*) FROM products)
        AS diferencia;


-- Verificamos que cada producto aparezca una sola vez.
SELECT
    COUNT(*) AS total_productos,
    COUNT(DISTINCT product_key) AS product_keys_unicos,
    COUNT(*)
    -
    COUNT(DISTINCT product_key) AS duplicados
FROM vw_product_performance;





-- Productos de alto volumen y baja rentabilidad
-- Comparamos cada producto con:
-- 1. Las ventas promedio de todos los productos.
-- 2. El margen comparable promedio de todos los productos.

-- Esto permite detectar productos con un volumen comercial
-- elevado pero una rentabilidad relativamente baja.
WITH referencias AS
(
    SELECT
        AVG(total_sales)
            AS average_product_sales,
        AVG(comparable_profit_margin_percentage)
            AS average_product_margin
    FROM vw_product_performance
),

evaluacion_productos AS
(
    SELECT
        vpp.product_key,
        vpp.product_id,
        vpp.product_name,
        vpp.category,
        vpp.sub_category,
        vpp.total_orders,
        vpp.total_order_lines,
        vpp.distinct_customers,
        vpp.total_sales,
        vpp.total_quantity,
        vpp.total_profit,
        vpp.average_line_discount,
        vpp.comparable_profit_margin_percentage,
        vpp.loss_making_lines,
        vpp.unknown_sales_lines,
        vpp.unknown_profit_lines,
        r.average_product_sales,
        r.average_product_margin,
        -- Clasificamos el producto según volumen y margen.
        CASE
            WHEN vpp.total_sales IS NULL
                THEN 'Ventas desconocidas'
            WHEN vpp.comparable_profit_margin_percentage IS NULL
                THEN 'Sin margen comparable'
            WHEN vpp.total_sales >= r.average_product_sales
             AND vpp.comparable_profit_margin_percentage
                    >= r.average_product_margin
                THEN 'Alto volumen - Alta rentabilidad'
            WHEN vpp.total_sales >= r.average_product_sales
             AND vpp.comparable_profit_margin_percentage
                    < r.average_product_margin
                THEN 'Alto volumen - Baja rentabilidad'
            WHEN vpp.total_sales < r.average_product_sales
             AND vpp.comparable_profit_margin_percentage
                    >= r.average_product_margin
                THEN 'Bajo volumen - Alta rentabilidad'
            ELSE 'Bajo volumen - Baja rentabilidad'
        END AS performance_profile,
        -- Clasificación adicional basada en el resultado financiero.
        CASE
            WHEN vpp.total_profit < 0
                THEN 'Beneficio acumulado negativo'
            WHEN vpp.comparable_profit_margin_percentage < 0
                THEN 'Margen comparable negativo'
            WHEN vpp.loss_making_lines > 0
                THEN 'Presenta líneas con pérdidas'
            ELSE 'Sin pérdidas conocidas'
        END AS profitability_status
    FROM vw_product_performance AS vpp
    CROSS JOIN referencias AS r
)

SELECT
    product_key,
    product_id,
    product_name,
    category,
    sub_category,
    performance_profile,
    profitability_status,
    total_orders,
    total_order_lines,
    distinct_customers,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        average_product_sales,
        2
    ) AS sales_benchmark,
    ROUND(
        total_sales
        -
        average_product_sales,
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
        average_product_margin,
        2
    ) AS margin_benchmark,
    ROUND(
        comparable_profit_margin_percentage
        -
        average_product_margin,
        2
    ) AS margin_vs_benchmark_points,
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
FROM evaluacion_productos
ORDER BY
    CASE performance_profile
        WHEN 'Alto volumen - Baja rentabilidad' THEN 1
        WHEN 'Alto volumen - Alta rentabilidad' THEN 2
        WHEN 'Bajo volumen - Baja rentabilidad' THEN 3
        WHEN 'Bajo volumen - Alta rentabilidad' THEN 4
        WHEN 'Sin margen comparable' THEN 5
        ELSE 6
    END,
    total_sales DESC,
    product_name,
    product_key;




-- Productos de alto volumen y baja rentabilidad.
WITH referencias AS
(
    SELECT
        AVG(total_sales)
            AS average_product_sales,
        AVG(comparable_profit_margin_percentage)
            AS average_product_margin
    FROM vw_product_performance
)

SELECT
    vpp.product_key,
    vpp.product_id,
    vpp.product_name,
    vpp.category,
    vpp.sub_category,
    vpp.total_orders,
    vpp.distinct_customers,
    ROUND(
        vpp.total_sales,
        2
    ) AS total_sales,
    ROUND(
        vpp.total_profit,
        2
    ) AS total_profit,
    ROUND(
        vpp.comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    ROUND(
        r.average_product_margin,
        2
    ) AS margin_benchmark,
    ROUND(
        vpp.comparable_profit_margin_percentage
        -
        r.average_product_margin,
        2
    ) AS margin_vs_benchmark_points,
    ROUND(
        vpp.average_line_discount * 100,
        2
    ) AS average_discount_percentage,
    vpp.loss_making_lines,
    ROUND(
        100.0
        *
        vpp.loss_making_lines
        /
        NULLIF(
            vpp.total_order_lines
            -
            vpp.unknown_profit_lines,
            0
        ),
        2
    ) AS known_loss_making_line_percentage,
    ROUND(
        100.0
        *
        (
            vpp.total_order_lines
            -
            vpp.unknown_profit_lines
        )
        /
        NULLIF(vpp.total_order_lines, 0),
        2
    ) AS profit_coverage_percentage
FROM vw_product_performance AS vpp
CROSS JOIN referencias AS r
WHERE vpp.total_sales >= r.average_product_sales
  AND vpp.comparable_profit_margin_percentage
        < r.average_product_margin
ORDER BY
    vpp.total_sales DESC,
    vpp.comparable_profit_margin_percentage ASC,
    vpp.product_name;



-- Productos cuyo beneficio conocido acumulado es negativo.
SELECT
    product_key,
    product_id,
    product_name,
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
FROM vw_product_performance
WHERE total_profit < 0
ORDER BY
    total_profit ASC,
    total_sales DESC,
    product_name;



-- Validamos la distribución de productos entre perfiles.
WITH referencias AS
(
    SELECT
        AVG(total_sales)
            AS average_product_sales,
        AVG(comparable_profit_margin_percentage)
            AS average_product_margin
    FROM vw_product_performance
),

clasificacion AS
(
    SELECT
        product_key,
        CASE
            WHEN total_sales IS NULL
                THEN 'Ventas desconocidas'
            WHEN comparable_profit_margin_percentage IS NULL
                THEN 'Sin margen comparable'
            WHEN total_sales >= average_product_sales
             AND comparable_profit_margin_percentage
                    >= average_product_margin
                THEN 'Alto volumen - Alta rentabilidad'
            WHEN total_sales >= average_product_sales
             AND comparable_profit_margin_percentage
                    < average_product_margin
                THEN 'Alto volumen - Baja rentabilidad'
            WHEN total_sales < average_product_sales
             AND comparable_profit_margin_percentage
                    >= average_product_margin
                THEN 'Bajo volumen - Alta rentabilidad'
            ELSE 'Bajo volumen - Baja rentabilidad'
        END AS performance_profile
    FROM vw_product_performance
    CROSS JOIN referencias
)

SELECT
    performance_profile,
    COUNT(*) AS total_products
FROM clasificacion
GROUP BY performance_profile
ORDER BY
    total_products DESC,
    performance_profile;




-- Concentración de ventas y clasificación ABC de productos
-- Ordenamos los productos por ventas conocidas y calculamos
-- su participación individual y acumulada dentro del negocio.
-- Clasificación ABC:
-- A = productos que concentran aproximadamente el primer 80%.
-- B = productos que llevan la concentración hasta aproximadamente 95%.
-- C = productos responsables del porcentaje restante.
WITH ventas_productos AS
(
    SELECT
        vpp.product_key,
        vpp.product_id,
        vpp.product_name,
        vpp.category,
        vpp.sub_category,
        vpp.total_orders,
        vpp.total_order_lines,
        vpp.distinct_customers,
        vpp.total_sales,
        vpp.total_profit,
        vpp.comparable_profit_margin_percentage,
        vpp.unknown_sales_lines,
        vpp.unknown_profit_lines,
        -- Posición del producto según sus ventas.
        ROW_NUMBER() OVER
        (
            ORDER BY
                vpp.total_sales DESC,
                vpp.product_key
        ) AS sales_position,
        -- Ventas conocidas totales del catálogo.
        SUM(vpp.total_sales) OVER ()
            AS business_total_sales,
        -- Ventas acumuladas siguiendo el ranking.
        SUM(vpp.total_sales) OVER
        (
            ORDER BY
                vpp.total_sales DESC,
                vpp.product_key
            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW
        ) AS cumulative_sales
    FROM vw_product_performance AS vpp
),

participacion_productos AS
(
    SELECT
        vp.*,
        -- Participación individual sobre las ventas conocidas.
        100.0
        *
        vp.total_sales
        /
        NULLIF(vp.business_total_sales, 0)
            AS sales_share_percentage,
        -- Participación acumulada sobre las ventas conocidas.
        100.0
        *
        vp.cumulative_sales
        /
        NULLIF(vp.business_total_sales, 0)
            AS cumulative_sales_percentage
    FROM ventas_productos AS vp
)

SELECT
    sales_position,
    product_key,
    product_id,
    product_name,
    category,
    sub_category,
    total_orders,
    total_order_lines,
    distinct_customers,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        sales_share_percentage,
        4
    ) AS sales_share_percentage,
    ROUND(
        cumulative_sales,
        2
    ) AS cumulative_sales,
    ROUND(
        cumulative_sales_percentage,
        2
    ) AS cumulative_sales_percentage,
    -- Asignamos la clasificación ABC según
    -- la participación acumulada de ventas.
    CASE
        WHEN cumulative_sales_percentage <= 80
            THEN 'A'
        WHEN cumulative_sales_percentage <= 95
            THEN 'B'
        ELSE 'C'
    END AS abc_classification,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
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
FROM participacion_productos
ORDER BY sales_position;



-- Cantidad mínima de productos necesaria para alcanzar
-- distintos niveles de concentración de ventas.
WITH ventas_ordenadas AS
(
    SELECT
        product_key,
        product_name,
        total_sales,
        ROW_NUMBER() OVER
        (
            ORDER BY
                total_sales DESC,
                product_key
        ) AS sales_position,
        100.0
        *
        SUM(total_sales) OVER
        (
            ORDER BY
                total_sales DESC,
                product_key
            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW
        )
        /
        NULLIF(
            SUM(total_sales) OVER (),
            0
        ) AS cumulative_sales_percentage
    FROM vw_product_performance
)

SELECT
    MIN(
        CASE
            WHEN cumulative_sales_percentage >= 50
                THEN sales_position
        END
    ) AS products_for_50_percent,
    MIN(
        CASE
            WHEN cumulative_sales_percentage >= 80
                THEN sales_position
        END
    ) AS products_for_80_percent,
    MIN(
        CASE
            WHEN cumulative_sales_percentage >= 95
                THEN sales_position
        END
    ) AS products_for_95_percent
FROM ventas_ordenadas;


-- Distribución de productos según clasificación ABC.
WITH ventas_productos AS
(
    SELECT
        product_key,
        total_sales,
        100.0
        *
        SUM(total_sales) OVER
        (
            ORDER BY
                total_sales DESC,
                product_key
            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW
        )
        /
        NULLIF(
            SUM(total_sales) OVER (),
            0
        ) AS cumulative_sales_percentage
    FROM vw_product_performance
),

clasificacion AS
(
    SELECT
        product_key,
        total_sales,
        CASE
            WHEN cumulative_sales_percentage <= 80
                THEN 'A'
            WHEN cumulative_sales_percentage <= 95
                THEN 'B'
            ELSE 'C'
        END AS abc_classification
    FROM ventas_productos
)

SELECT
    abc_classification,
    COUNT(*) AS total_products,
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
    ) AS product_percentage,
    ROUND(
        SUM(total_sales),
        2
    ) AS total_sales,
    ROUND(
        100.0
        *
        SUM(total_sales)
        /
        NULLIF(
            SUM(SUM(total_sales)) OVER (),
            0
        ),
        2
    ) AS sales_percentage
FROM clasificacion
GROUP BY abc_classification
ORDER BY
    CASE abc_classification
        WHEN 'A' THEN 1
        WHEN 'B' THEN 2
        ELSE 3
    END;


-- Validamos que la participación de todos los
-- productos represente el 100% de las ventas conocidas.
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
                    FROM vw_product_performance
                ),
                0
            )
        ),
        2
    ) AS total_sales_share_percentage
FROM vw_product_performance;




-- Análisis de códigos de producto reutilizados
-- Identificamos los códigos originales asociados con
-- más de un producto dentro del modelo normalizado.
WITH codigos_reutilizados AS
(
    SELECT
        p.source_product_id AS product_id,
        COUNT(*) AS associated_products
    FROM products AS p
    GROUP BY
        p.source_product_id
    HAVING COUNT(*) > 1
),

detalle_productos AS
(
    SELECT
        cr.product_id,
        cr.associated_products,
        vpp.product_key,
        vpp.product_name,
        vpp.category,
        vpp.sub_category,
        vpp.total_orders,
        vpp.total_order_lines,
        vpp.distinct_customers,
        vpp.total_sales,
        vpp.total_quantity,
        vpp.total_profit,
        vpp.average_line_discount,
        vpp.comparable_profit_margin_percentage,
        vpp.loss_making_lines,
        vpp.unknown_sales_lines,
        vpp.unknown_profit_lines,
        -- Ranking de ventas entre los productos
        -- que comparten el mismo código original.
        DENSE_RANK() OVER
        (
            PARTITION BY cr.product_id
            ORDER BY vpp.total_sales DESC
        ) AS sales_rank_within_source_id,
        -- Participación del producto sobre las ventas
        -- generadas por su código original.
        100.0
        *
        vpp.total_sales
        /
        NULLIF(
            SUM(vpp.total_sales) OVER
            (
                PARTITION BY cr.product_id
            ),
            0
        ) AS source_id_sales_share_percentage
    FROM codigos_reutilizados AS cr
    INNER JOIN vw_product_performance AS vpp
        ON vpp.product_id = cr.product_id
)

SELECT
    product_id,
    associated_products,
    product_key,
    product_name,
    category,
    sub_category,
    total_orders,
    total_order_lines,
    distinct_customers,
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
    sales_rank_within_source_id,
    ROUND(
        source_id_sales_share_percentage,
        2
    ) AS source_id_sales_share_percentage,
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
FROM detalle_productos
ORDER BY
    product_id,
    sales_rank_within_source_id,
    product_key;


-- Resumen general de códigos de producto reutilizados.
WITH codigos_reutilizados AS
(
    SELECT
        source_product_id,
        COUNT(*) AS associated_products
    FROM products
    GROUP BY
        source_product_id
    HAVING COUNT(*) > 1
)

SELECT
    COUNT(*) AS reused_product_ids,
    SUM(associated_products) AS products_with_reused_ids,
    MIN(associated_products) AS minimum_products_per_id,
    MAX(associated_products) AS maximum_products_per_id,
    ROUND(
        AVG(associated_products),
        2
    ) AS average_products_per_id
FROM codigos_reutilizados;


-- Impacto comercial de los productos cuyos códigos
-- originales fueron reutilizados.
WITH codigos_reutilizados AS
(
    SELECT
        source_product_id
    FROM products
    GROUP BY
        source_product_id
    HAVING COUNT(*) > 1
),

metricas_reutilizadas AS
(
    SELECT
        SUM(vpp.total_sales) AS reused_total_sales,
        SUM(vpp.total_profit) AS reused_total_profit,
        SUM(vpp.total_order_lines) AS reused_order_lines
    FROM vw_product_performance AS vpp
    INNER JOIN codigos_reutilizados AS cr
        ON cr.source_product_id = vpp.product_id
)

SELECT
    ROUND(
        mr.reused_total_sales,
        2
    ) AS reused_product_sales,
    ROUND(
        100.0
        *
        mr.reused_total_sales
        /
        NULLIF(
            vb.total_sales,
            0
        ),
        2
    ) AS reused_product_sales_percentage,
    ROUND(
        mr.reused_total_profit,
        2
    ) AS reused_product_profit,
    mr.reused_order_lines,
    ROUND(
        100.0
        *
        mr.reused_order_lines
        /
        NULLIF(
            vb.total_order_lines,
            0
        ),
        2
    ) AS reused_product_line_percentage
FROM metricas_reutilizadas AS mr
CROSS JOIN vw_business_overview AS vb;




-- Evolución anual por producto
-- Analizamos el desempeño de cada producto por año.
-- product_key mantiene separados correctamente los productos
-- cuyos identificadores originales fueron reutilizados.
WITH rendimiento_anual_producto AS
(
    SELECT
        vsd.product_key,
        vsd.product_id,
        vsd.product_name,
        vsd.category,
        vsd.sub_category,
        YEAR(vsd.order_date) AS order_year,
        -- Actividad comercial.
        COUNT(DISTINCT vsd.order_key)
            AS total_orders,
        COUNT(DISTINCT vsd.customer_id)
            AS distinct_customers,
        COUNT(*) AS total_order_lines,
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
        -- Líneas con beneficio negativo.
        SUM(
            CASE
                WHEN vsd.profit < 0 THEN 1
                ELSE 0
            END
        ) AS loss_making_lines,
        -- Cobertura de información.
        COUNT(*) - COUNT(vsd.sales)
            AS unknown_sales_lines,
        COUNT(*) - COUNT(vsd.quantity)
            AS unknown_quantity_lines,
        COUNT(*) - COUNT(vsd.profit)
            AS unknown_profit_lines
    FROM vw_sales_detail AS vsd
    GROUP BY
        vsd.product_key,
        vsd.product_id,
        vsd.product_name,
        vsd.category,
        vsd.sub_category,
        YEAR(vsd.order_date)
),

comparacion_anual_producto AS
(
    SELECT
        rap.*,
        -- Recuperamos los resultados del mismo producto
        -- durante el año anterior disponible.
        LAG(rap.total_orders) OVER
        (
            PARTITION BY rap.product_key
            ORDER BY rap.order_year
        ) AS previous_year_orders,
        LAG(rap.total_sales) OVER
        (
            PARTITION BY rap.product_key
            ORDER BY rap.order_year
        ) AS previous_year_sales,
        LAG(rap.total_profit) OVER
        (
            PARTITION BY rap.product_key
            ORDER BY rap.order_year
        ) AS previous_year_profit,
        LAG(rap.comparable_profit_margin_percentage) OVER
        (
            PARTITION BY rap.product_key
            ORDER BY rap.order_year
        ) AS previous_year_margin
    FROM rendimiento_anual_producto AS rap
)

SELECT
    product_key,
    product_id,
    product_name,
    category,
    sub_category,
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
FROM comparacion_anual_producto
ORDER BY
    product_key,
    order_year;




-- Productos con crecimiento de ventas y deterioro del margen.
WITH rendimiento_anual AS
(
    SELECT
        vsd.product_key,
        vsd.product_id,
        vsd.product_name,
        vsd.category,
        vsd.sub_category,
        YEAR(vsd.order_date) AS order_year,
        SUM(vsd.sales)
            AS total_sales,
        SUM(vsd.profit)
            AS total_profit,
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
        vsd.product_key,
        vsd.product_id,
        vsd.product_name,
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
            PARTITION BY ra.product_key
            ORDER BY ra.order_year
        ) AS previous_year_sales,
        LAG(ra.total_profit) OVER
        (
            PARTITION BY ra.product_key
            ORDER BY ra.order_year
        ) AS previous_year_profit,
        LAG(ra.comparable_profit_margin_percentage) OVER
        (
            PARTITION BY ra.product_key
            ORDER BY ra.order_year
        ) AS previous_year_margin
    FROM rendimiento_anual AS ra
)

SELECT
    product_key,
    product_id,
    product_name,
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
    ) AS current_year_sales,
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
        previous_year_profit,
        2
    ) AS previous_year_profit,
    ROUND(
        total_profit,
        2
    ) AS current_year_profit,
    ROUND(
        total_profit
        -
        previous_year_profit,
        2
    ) AS profit_change,
    ROUND(
        previous_year_margin,
        2
    ) AS previous_year_margin,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS current_year_margin,
    ROUND(
        comparable_profit_margin_percentage
        -
        previous_year_margin,
        2
    ) AS margin_change_points
FROM comparacion
WHERE previous_year_sales IS NOT NULL
  AND previous_year_margin IS NOT NULL
  AND total_sales > previous_year_sales
  AND comparable_profit_margin_percentage
        < previous_year_margin
ORDER BY
    margin_change_points ASC,
    sales_growth_percentage DESC,
    product_name;


-- Productos que pasaron de beneficio positivo a negativo
WITH beneficio_anual AS
(
    SELECT
        vsd.product_key,
        vsd.product_id,
        vsd.product_name,
        vsd.category,
        vsd.sub_category,
        YEAR(vsd.order_date) AS order_year,
        SUM(vsd.profit) AS total_profit,
        COUNT(*) - COUNT(vsd.profit)
            AS unknown_profit_lines
    FROM vw_sales_detail AS vsd
    GROUP BY
        vsd.product_key,
        vsd.product_id,
        vsd.product_name,
        vsd.category,
        vsd.sub_category,
        YEAR(vsd.order_date)
),

comparacion AS
(
    SELECT
        ba.*,
        LAG(ba.total_profit) OVER
        (
            PARTITION BY ba.product_key
            ORDER BY ba.order_year
        ) AS previous_year_profit
    FROM beneficio_anual AS ba
)

SELECT
    product_key,
    product_id,
    product_name,
    category,
    sub_category,
    order_year,
    ROUND(
        previous_year_profit,
        2
    ) AS previous_year_profit,
    ROUND(
        total_profit,
        2
    ) AS current_year_profit,
    ROUND(
        total_profit
        -
        previous_year_profit,
        2
    ) AS profit_change,
    unknown_profit_lines
FROM comparacion
WHERE previous_year_profit > 0
  AND total_profit < 0
ORDER BY
    profit_change ASC,
    product_name;


-- Validamos la cobertura temporal de los productos.
SELECT
    observed_years,
    COUNT(*) AS total_products
FROM
(
    SELECT
        product_key,
        COUNT(
            DISTINCT YEAR(order_date)
        ) AS observed_years
    FROM vw_sales_detail
    GROUP BY product_key
) AS cobertura
GROUP BY observed_years
ORDER BY observed_years;