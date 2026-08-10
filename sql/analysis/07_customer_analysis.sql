/*
Archivo      : 07_customer_analysis.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Análisis del comportamiento y valor de los
               clientes, considerando ventas, frecuencia,
               rentabilidad, recurrencia y cobertura de datos.
*/

USE superstore_analytics;


-- Ranking general de clientes
-- Comparamos los clientes según:
-- 1. Ventas conocidas.
-- 2. Beneficio conocido.
-- 3. Cantidad de pedidos.
-- 4. Valor promedio de pedido completo.
-- 5. Participación sobre las ventas del negocio.
WITH ranking_clientes AS
(
    SELECT
        vcp.customer_id,
        vcp.customer_name,
        vcp.segment,
        vcp.total_orders,
        vcp.first_order_date,
        vcp.last_order_date,
        vcp.purchase_span_days,
        vcp.distinct_locations,
        vcp.total_order_lines,
        vcp.total_product_references,
        vcp.total_sales,
        vcp.total_quantity,
        vcp.total_profit,
        vcp.average_complete_order_value,
        vcp.comparable_profit_margin_percentage,
        vcp.average_shipping_days,
        vcp.unknown_sales_lines,
        vcp.unknown_quantity_lines,
        vcp.unknown_profit_lines,
        vcp.orders_with_unknown_sales,
        vcp.orders_with_unknown_profit,
        vcp.complete_loss_making_orders,
        -- Participación del cliente sobre las ventas conocidas.
        100.0
        *
        vcp.total_sales
        /
        NULLIF(
            SUM(vcp.total_sales) OVER (),
            0
        ) AS global_sales_share_percentage,
        -- Ranking global por ventas.
        DENSE_RANK() OVER (
            ORDER BY vcp.total_sales DESC
        ) AS sales_rank,
        -- Ranking global por beneficio.
        DENSE_RANK() OVER (
            ORDER BY vcp.total_profit DESC
        ) AS profit_rank,
        -- Ranking por frecuencia de compra.
        DENSE_RANK() OVER (
            ORDER BY vcp.total_orders DESC
        ) AS order_frequency_rank,
        -- Ranking por valor promedio de pedido completo.
        DENSE_RANK() OVER (
            ORDER BY vcp.average_complete_order_value DESC
        ) AS average_order_value_rank
    FROM vw_customer_performance AS vcp
)

SELECT
    customer_id,
    customer_name,
    segment,
    total_orders,
    first_order_date,
    last_order_date,
    purchase_span_days,
    distinct_locations,
    total_order_lines,
    total_product_references,
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
    ROUND(
        global_sales_share_percentage,
        4
    ) AS global_sales_share_percentage,
    sales_rank,
    profit_rank,
    order_frequency_rank,
    average_order_value_rank,
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
FROM ranking_clientes
ORDER BY
    sales_rank,
    customer_name,
    customer_id;



-- Top 20 clientes por ventas conocidas.
SELECT
    customer_id,
    customer_name,
    segment,
    total_orders,
    first_order_date,
    last_order_date,
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
    complete_loss_making_orders
FROM vw_customer_performance
ORDER BY
    total_sales DESC,
    customer_name,
    customer_id
LIMIT 20;


-- Validamos que todos los clientes estén representados.
SELECT
    (SELECT COUNT(*) FROM customers)
        AS clientes_modelo,
    (SELECT COUNT(*) FROM vw_customer_performance)
        AS clientes_analizados,
    (SELECT COUNT(*) FROM vw_customer_performance)
    -
    (SELECT COUNT(*) FROM customers)
        AS diferencia;


-- Cada customer_id debe aparecer una sola vez.
SELECT
    COUNT(*) AS total_clientes,
    COUNT(DISTINCT customer_id) AS clientes_unicos,
    COUNT(*)
    -
    COUNT(DISTINCT customer_id) AS duplicados
FROM vw_customer_performance;



-- Segmentación de clientes por valor y frecuencia
-- Dividimos a los clientes según dos dimensiones:
-- 1. Valor comercial medido por sus ventas acumuladas.
-- 2. Frecuencia medida por la cantidad de pedidos.

-- NTILE(2) divide los clientes en dos grupos de tamaño
-- aproximadamente igual para cada dimensión.
WITH segmentacion_base AS
(
    SELECT
        vcp.customer_id,
        vcp.customer_name,
        vcp.segment,
        vcp.total_orders,
        vcp.first_order_date,
        vcp.last_order_date,
        vcp.purchase_span_days,
        vcp.total_order_lines,
        vcp.total_sales,
        vcp.total_profit,
        vcp.average_complete_order_value,
        vcp.comparable_profit_margin_percentage,
        vcp.complete_loss_making_orders,
        vcp.orders_with_unknown_sales,
        vcp.orders_with_unknown_profit,
        vcp.unknown_sales_lines,
        vcp.unknown_profit_lines,
        -- La mitad superior recibe value_group = 2.
        NTILE(2) OVER
        (
            ORDER BY vcp.total_sales
        ) AS value_group,
        -- La mitad superior recibe frequency_group = 2.
        NTILE(2) OVER
        (
            ORDER BY vcp.total_orders
        ) AS frequency_group
    FROM vw_customer_performance AS vcp
    WHERE vcp.total_sales IS NOT NULL
),

clasificacion_clientes AS
(
    SELECT
        sb.*,
        CASE
            WHEN sb.value_group = 2
             AND sb.frequency_group = 2
                THEN 'Alto valor - Alta frecuencia'
            WHEN sb.value_group = 2
             AND sb.frequency_group = 1
                THEN 'Alto valor - Baja frecuencia'
            WHEN sb.value_group = 1
             AND sb.frequency_group = 2
                THEN 'Bajo valor - Alta frecuencia'
            ELSE 'Bajo valor - Baja frecuencia'
        END AS customer_profile
    FROM segmentacion_base AS sb
)

SELECT
    customer_id,
    customer_name,
    segment,
    customer_profile,
    total_orders,
    first_order_date,
    last_order_date,
    purchase_span_days,
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
    complete_loss_making_orders,
    value_group,
    frequency_group,
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
FROM clasificacion_clientes
ORDER BY
    CASE customer_profile
        WHEN 'Alto valor - Alta frecuencia' THEN 1
        WHEN 'Alto valor - Baja frecuencia' THEN 2
        WHEN 'Bajo valor - Alta frecuencia' THEN 3
        ELSE 4
    END,
    total_sales DESC,
    customer_name;




-- Resumen de clientes por perfil de valor y frecuencia.
WITH segmentacion_base AS
(
    SELECT
        vcp.customer_id,
        vcp.total_orders,
        vcp.total_sales,
        vcp.total_profit,
        NTILE(2) OVER
        (
            ORDER BY vcp.total_sales
        ) AS value_group,
        NTILE(2) OVER
        (
            ORDER BY vcp.total_orders
        ) AS frequency_group
    FROM vw_customer_performance AS vcp
    WHERE vcp.total_sales IS NOT NULL
),

clasificacion AS
(
    SELECT
        sb.*,
        CASE
            WHEN sb.value_group = 2
             AND sb.frequency_group = 2
                THEN 'Alto valor - Alta frecuencia'
            WHEN sb.value_group = 2
             AND sb.frequency_group = 1
                THEN 'Alto valor - Baja frecuencia'
            WHEN sb.value_group = 1
             AND sb.frequency_group = 2
                THEN 'Bajo valor - Alta frecuencia'
            ELSE 'Bajo valor - Baja frecuencia'
        END AS customer_profile
    FROM segmentacion_base AS sb
)

SELECT
    customer_profile,
    COUNT(*) AS total_customers,
    ROUND(
        AVG(total_orders),
        2
    ) AS average_orders,
    ROUND(
        AVG(total_sales),
        2
    ) AS average_customer_sales,
    ROUND(
        SUM(total_sales),
        2
    ) AS total_sales,
    ROUND(
        SUM(total_profit),
        2
    ) AS total_profit,
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
    ) AS sales_share_percentage
FROM clasificacion
GROUP BY customer_profile
ORDER BY
    CASE customer_profile
        WHEN 'Alto valor - Alta frecuencia' THEN 1
        WHEN 'Alto valor - Baja frecuencia' THEN 2
        WHEN 'Bajo valor - Alta frecuencia' THEN 3
        ELSE 4
    END;


-- Clientes sin ventas acumuladas conocidas.
SELECT
    COUNT(*) AS customers_without_known_sales
FROM vw_customer_performance
WHERE total_sales IS NULL;




-- Segmentación RFM de clientes
-- Clasificamos a los clientes según:
-- R = Recencia desde su última compra.
-- F = Frecuencia de pedidos.
-- M = Valor monetario acumulado.

-- Cada dimensión recibe una puntuación de 1 a 4.
-- Una puntuación mayor representa un mejor resultado.
WITH base_rfm AS
(
    SELECT
        vcp.customer_id,
        vcp.customer_name,
        vcp.segment,
        vcp.total_orders,
        vcp.first_order_date,
        vcp.last_order_date,
        vcp.purchase_span_days,
        vcp.total_order_lines,
        vcp.total_sales,
        vcp.total_profit,
        vcp.average_complete_order_value,
        vcp.comparable_profit_margin_percentage,
        vcp.unknown_sales_lines,
        vcp.unknown_profit_lines,
        -- Utilizamos la última fecha del conjunto como
        -- referencia temporal para calcular la recencia.
        MAX(vcp.last_order_date) OVER ()
            AS analysis_reference_date
    FROM vw_customer_performance AS vcp
    WHERE vcp.total_sales IS NOT NULL
),

metricas_rfm AS
(
    SELECT
        br.*,
        -- Número de días transcurridos entre la última
        -- compra del cliente y la fecha de referencia.
        DATEDIFF(
            br.analysis_reference_date,
            br.last_order_date
        ) AS recency_days
    FROM base_rfm AS br
),

puntuaciones_rfm AS
(
    SELECT
        mr.*,
        -- Una menor recencia representa un cliente
        -- que compró más recientemente.
        --
        -- Ordenamos de mayor a menor para que los clientes
        -- más recientes reciban las puntuaciones más altas.
        NTILE(4) OVER
        (
            ORDER BY mr.recency_days DESC
        ) AS recency_score,
        -- Más pedidos producen una puntuación mayor.
        NTILE(4) OVER
        (
            ORDER BY mr.total_orders ASC
        ) AS frequency_score,
        -- Más ventas acumuladas producen una puntuación mayor.
        NTILE(4) OVER
        (
            ORDER BY mr.total_sales ASC
        ) AS monetary_score
    FROM metricas_rfm AS mr
),

segmentacion_rfm AS
(
    SELECT
        pr.*,
        -- Sumamos las tres dimensiones para obtener
        -- una puntuación general entre 3 y 12.
        pr.recency_score
        +
        pr.frequency_score
        +
        pr.monetary_score
            AS rfm_total_score,
        -- Creamos también el código RFM tradicional.
        CONCAT(
            pr.recency_score,
            pr.frequency_score,
            pr.monetary_score
        ) AS rfm_code,
        -- Clasificamos al cliente considerando de forma
        -- conjunta su recencia, frecuencia y valor.
        CASE
            WHEN pr.recency_score >= 3
             AND pr.frequency_score >= 3
             AND pr.monetary_score >= 3
                THEN 'Clientes de alto valor'
            WHEN pr.recency_score = 4
             AND pr.frequency_score >= 2
                THEN 'Clientes recientes'
            WHEN pr.frequency_score >= 3
             AND pr.monetary_score >= 3
                THEN 'Clientes leales'
            WHEN pr.recency_score <= 2
             AND pr.frequency_score >= 3
             AND pr.monetary_score >= 3
                THEN 'Clientes valiosos en riesgo'
            WHEN pr.recency_score <= 2
             AND pr.frequency_score <= 2
                THEN 'Clientes inactivos'
            ELSE 'Clientes intermedios'
        END AS rfm_segment
    FROM puntuaciones_rfm AS pr
)

SELECT
    customer_id,
    customer_name,
    segment,
    analysis_reference_date,
    last_order_date,
    recency_days,
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
        average_complete_order_value,
        2
    ) AS average_complete_order_value,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    recency_score,
    frequency_score,
    monetary_score,
    rfm_code,
    rfm_total_score,
    rfm_segment,
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
FROM segmentacion_rfm
ORDER BY
    rfm_total_score DESC,
    total_sales DESC,
    customer_name;




-- Resumen de los segmentos RFM.
WITH base_rfm AS
(
    SELECT
        customer_id,
        total_orders,
        total_sales,
        total_profit,
        last_order_date,
        MAX(last_order_date) OVER ()
            AS analysis_reference_date
    FROM vw_customer_performance
    WHERE total_sales IS NOT NULL
),

metricas_rfm AS
(
    SELECT
        br.*,
        DATEDIFF(
            analysis_reference_date,
            last_order_date
        ) AS recency_days
    FROM base_rfm AS br
),

puntuaciones AS
(
    SELECT
        mr.*,
        NTILE(4) OVER
        (
            ORDER BY recency_days DESC
        ) AS recency_score,
        NTILE(4) OVER
        (
            ORDER BY total_orders ASC
        ) AS frequency_score,
        NTILE(4) OVER
        (
            ORDER BY total_sales ASC
        ) AS monetary_score
    FROM metricas_rfm AS mr
),

segmentacion AS
(
    SELECT
        p.*,
        CASE
            WHEN recency_score >= 3
             AND frequency_score >= 3
             AND monetary_score >= 3
                THEN 'Clientes de alto valor'
            WHEN recency_score = 4
             AND frequency_score >= 2
                THEN 'Clientes recientes'
            WHEN frequency_score >= 3
             AND monetary_score >= 3
                THEN 'Clientes leales'
            WHEN recency_score <= 2
             AND frequency_score >= 3
             AND monetary_score >= 3
                THEN 'Clientes valiosos en riesgo'
            WHEN recency_score <= 2
             AND frequency_score <= 2
                THEN 'Clientes inactivos'
            ELSE 'Clientes intermedios'
        END AS rfm_segment
    FROM puntuaciones AS p
)

SELECT
    rfm_segment,
    COUNT(*) AS total_customers,
    ROUND(
        AVG(recency_days),
        2
    ) AS average_recency_days,
    ROUND(
        AVG(total_orders),
        2
    ) AS average_orders,
    ROUND(
        AVG(total_sales),
        2
    ) AS average_customer_sales,
    ROUND(
        SUM(total_sales),
        2
    ) AS total_sales,
    ROUND(
        SUM(total_profit),
        2
    ) AS total_profit,
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
    ) AS sales_share_percentage
FROM segmentacion
GROUP BY rfm_segment
ORDER BY
    total_sales DESC;



-- Verificamos que todos los clientes con ventas
-- conocidas hayan recibido una clasificación RFM.
SELECT
    COUNT(*) AS customers_with_known_sales
FROM vw_customer_performance
WHERE total_sales IS NOT NULL;




-- Clientes de alto valor con rentabilidad deficiente
-- Comparamos las ventas y el margen de cada cliente contra
-- los valores promedio de toda la cartera.

-- Esto permite detectar clientes con ventas superiores
-- al promedio pero con una rentabilidad relativamente baja.
WITH referencias AS
(
    SELECT
        AVG(total_sales)
            AS average_customer_sales,
        AVG(comparable_profit_margin_percentage)
            AS average_customer_margin
    FROM vw_customer_performance
    WHERE total_sales IS NOT NULL
),

evaluacion_clientes AS
(
    SELECT
        vcp.customer_id,
        vcp.customer_name,
        vcp.segment,
        vcp.total_orders,
        vcp.first_order_date,
        vcp.last_order_date,
        vcp.purchase_span_days,
        vcp.total_order_lines,
        vcp.total_sales,
        vcp.total_quantity,
        vcp.total_profit,
        vcp.average_complete_order_value,
        vcp.comparable_profit_margin_percentage,
        vcp.complete_loss_making_orders,
        vcp.orders_with_unknown_sales,
        vcp.orders_with_unknown_profit,
        vcp.unknown_sales_lines,
        vcp.unknown_profit_lines,
        r.average_customer_sales,
        r.average_customer_margin,
        -- Clasificamos al cliente según ventas y margen.
        CASE
            WHEN vcp.total_sales IS NULL
                THEN 'Ventas desconocidas'
            WHEN vcp.comparable_profit_margin_percentage IS NULL
                THEN 'Sin margen comparable'
            WHEN vcp.total_sales >= r.average_customer_sales
             AND vcp.comparable_profit_margin_percentage
                    >= r.average_customer_margin
                THEN 'Alto valor - Alta rentabilidad'
            WHEN vcp.total_sales >= r.average_customer_sales
             AND vcp.comparable_profit_margin_percentage
                    < r.average_customer_margin
                THEN 'Alto valor - Baja rentabilidad'
            WHEN vcp.total_sales < r.average_customer_sales
             AND vcp.comparable_profit_margin_percentage
                    >= r.average_customer_margin
                THEN 'Bajo valor - Alta rentabilidad'
            ELSE 'Bajo valor - Baja rentabilidad'
        END AS profitability_profile,
        -- Clasificación adicional según el beneficio conocido.
        CASE
            WHEN vcp.total_profit < 0
                THEN 'Beneficio acumulado conocido negativo'
            WHEN vcp.complete_loss_making_orders > 0
                THEN 'Presenta pedidos completos con pérdidas'
            ELSE 'Sin pérdidas completas conocidas'
        END AS loss_status
    FROM vw_customer_performance AS vcp
    CROSS JOIN referencias AS r
)

SELECT
    customer_id,
    customer_name,
    segment,
    profitability_profile,
    loss_status,
    total_orders,
    first_order_date,
    last_order_date,
    purchase_span_days,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        average_customer_sales,
        2
    ) AS sales_benchmark,
    ROUND(
        total_sales
        -
        average_customer_sales,
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
        average_customer_margin,
        2
    ) AS margin_benchmark,
    ROUND(
        comparable_profit_margin_percentage
        -
        average_customer_margin,
        2
    ) AS margin_vs_benchmark_points,
    ROUND(
        average_complete_order_value,
        2
    ) AS average_complete_order_value,
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
FROM evaluacion_clientes
ORDER BY
    CASE profitability_profile
        WHEN 'Alto valor - Baja rentabilidad' THEN 1
        WHEN 'Alto valor - Alta rentabilidad' THEN 2
        WHEN 'Bajo valor - Baja rentabilidad' THEN 3
        WHEN 'Bajo valor - Alta rentabilidad' THEN 4
        WHEN 'Sin margen comparable' THEN 5
        ELSE 6
    END,
    total_sales DESC,
    customer_name;




-- Clientes con ventas superiores al promedio
-- y margen inferior al promedio de la cartera.
WITH referencias AS
(
    SELECT
        AVG(total_sales)
            AS average_customer_sales,
        AVG(comparable_profit_margin_percentage)
            AS average_customer_margin
    FROM vw_customer_performance
    WHERE total_sales IS NOT NULL
)

SELECT
    vcp.customer_id,
    vcp.customer_name,
    vcp.segment,
    vcp.total_orders,
    ROUND(
        vcp.total_sales,
        2
    ) AS total_sales,
    ROUND(
        vcp.total_profit,
        2
    ) AS total_profit,
    ROUND(
        vcp.average_complete_order_value,
        2
    ) AS average_complete_order_value,
    ROUND(
        vcp.comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    ROUND(
        r.average_customer_margin,
        2
    ) AS margin_benchmark,
    ROUND(
        vcp.comparable_profit_margin_percentage
        -
        r.average_customer_margin,
        2
    ) AS margin_vs_benchmark_points,
    vcp.complete_loss_making_orders,
    ROUND(
        100.0
        *
        vcp.complete_loss_making_orders
        /
        NULLIF(
            vcp.total_orders
            -
            vcp.orders_with_unknown_profit,
            0
        ),
        2
    ) AS complete_loss_making_order_percentage,
    ROUND(
        100.0
        *
        (
            vcp.total_order_lines
            -
            vcp.unknown_profit_lines
        )
        /
        NULLIF(vcp.total_order_lines, 0),
        2
    ) AS profit_coverage_percentage
FROM vw_customer_performance AS vcp
CROSS JOIN referencias AS r
WHERE vcp.total_sales >= r.average_customer_sales
  AND vcp.comparable_profit_margin_percentage
        < r.average_customer_margin
ORDER BY
    vcp.total_sales DESC,
    vcp.comparable_profit_margin_percentage ASC,
    vcp.customer_name;




-- Clientes cuyo beneficio conocido acumulado es negativo.
SELECT
    customer_id,
    customer_name,
    segment,
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
        average_complete_order_value,
        2
    ) AS average_complete_order_value,
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
FROM vw_customer_performance
WHERE total_profit < 0
ORDER BY
    total_profit ASC,
    total_sales DESC,
    customer_name;



-- Clientes con mayor proporción de pedidos completos
-- cuyo beneficio total fue negativo.
SELECT
    customer_id,
    customer_name,
    segment,
    total_orders,
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
FROM vw_customer_performance
WHERE total_orders
      -
      orders_with_unknown_profit > 0
  AND complete_loss_making_orders > 0
ORDER BY
    complete_loss_making_order_percentage DESC,
    complete_loss_making_orders DESC,
    total_sales DESC,
    customer_name;




-- Recurrencia y continuidad de compra
-- Analizamos cuántos pedidos realiza cada cliente y
-- durante cuántos meses y años diferentes permanece activo.
WITH actividad_clientes AS
(
    SELECT
        vos.customer_id,
        vos.customer_name,
        vos.segment,
        COUNT(*) AS total_orders,
        MIN(vos.order_date) AS first_order_date,
        MAX(vos.order_date) AS last_order_date,
        DATEDIFF(
            MAX(vos.order_date),
            MIN(vos.order_date)
        ) AS customer_lifetime_days,
        COUNT(
            DISTINCT DATE_FORMAT(
                vos.order_date,
                '%Y-%m'
            )
        ) AS active_months,
        COUNT(
            DISTINCT YEAR(vos.order_date)
        ) AS active_years,
        SUM(vos.total_sales) AS total_sales,
        SUM(vos.total_profit) AS total_profit,
        SUM(vos.total_order_lines) AS total_order_lines,
        SUM(vos.unknown_sales_lines) AS unknown_sales_lines,
        SUM(vos.unknown_profit_lines) AS unknown_profit_lines
    FROM vw_order_summary AS vos
    GROUP BY
        vos.customer_id,
        vos.customer_name,
        vos.segment
),

clasificacion_recurrencia AS
(
    SELECT
        ac.*,
        CASE
            WHEN ac.total_orders = 1
                THEN 'Compra única'
            WHEN ac.active_months = 1
                THEN 'Recurrente en un solo mes'
            WHEN ac.active_years = 1
                THEN 'Recurrente dentro de un año'
            ELSE 'Recurrente multianual'
        END AS recurrence_profile
    FROM actividad_clientes AS ac
)

SELECT
    customer_id,
    customer_name,
    segment,
    recurrence_profile,
    total_orders,
    first_order_date,
    last_order_date,
    customer_lifetime_days,
    active_months,
    active_years,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        total_sales
        /
        NULLIF(total_orders, 0),
        2
    ) AS average_known_sales_per_order,
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
FROM clasificacion_recurrencia
ORDER BY
    CASE recurrence_profile
        WHEN 'Recurrente multianual' THEN 1
        WHEN 'Recurrente dentro de un año' THEN 2
        WHEN 'Recurrente en un solo mes' THEN 3
        ELSE 4
    END,
    total_orders DESC,
    total_sales DESC,
    customer_name;




-- Resumen de clientes según su perfil de recurrencia.
WITH actividad_clientes AS
(
    SELECT
        vos.customer_id,
        COUNT(*) AS total_orders,
        COUNT(
            DISTINCT DATE_FORMAT(
                vos.order_date,
                '%Y-%m'
            )
        ) AS active_months,
        COUNT(
            DISTINCT YEAR(vos.order_date)
        ) AS active_years,
        DATEDIFF(
            MAX(vos.order_date),
            MIN(vos.order_date)
        ) AS customer_lifetime_days,
        SUM(vos.total_sales) AS total_sales,
        SUM(vos.total_profit) AS total_profit
    FROM vw_order_summary AS vos
    GROUP BY vos.customer_id
),

clasificacion AS
(
    SELECT
        ac.*,
        CASE
            WHEN ac.total_orders = 1
                THEN 'Compra única'
            WHEN ac.active_months = 1
                THEN 'Recurrente en un solo mes'
            WHEN ac.active_years = 1
                THEN 'Recurrente dentro de un año'
            ELSE 'Recurrente multianual'
        END AS recurrence_profile
    FROM actividad_clientes AS ac
)

SELECT
    recurrence_profile,
    COUNT(*) AS total_customers,
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
    ) AS customer_percentage,
    ROUND(
        AVG(total_orders),
        2
    ) AS average_orders,
    ROUND(
        AVG(customer_lifetime_days),
        2
    ) AS average_customer_lifetime_days,
    ROUND(
        AVG(total_sales),
        2
    ) AS average_customer_sales,
    ROUND(
        SUM(total_sales),
        2
    ) AS total_sales,
    ROUND(
        SUM(total_profit),
        2
    ) AS total_profit,
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
    ) AS sales_share_percentage
FROM clasificacion
GROUP BY recurrence_profile
ORDER BY
    CASE recurrence_profile
        WHEN 'Recurrente multianual' THEN 1
        WHEN 'Recurrente dentro de un año' THEN 2
        WHEN 'Recurrente en un solo mes' THEN 3
        ELSE 4
    END;




-- Porcentaje de clientes que realizaron más de un pedido.
WITH pedidos_cliente AS
(
    SELECT
        customer_id,
        COUNT(*) AS total_orders
    FROM vw_order_summary
    GROUP BY customer_id
)

SELECT
    COUNT(*) AS total_customers,
    SUM(
        CASE
            WHEN total_orders > 1 THEN 1
            ELSE 0
        END
    ) AS repeat_customers,
    SUM(
        CASE
            WHEN total_orders = 1 THEN 1
            ELSE 0
        END
    ) AS one_time_customers,
    ROUND(
        100.0
        *
        SUM(
            CASE
                WHEN total_orders > 1 THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0),
        2
    ) AS repeat_customer_percentage
FROM pedidos_cliente;





-- Análisis de cohortes y retención de clientes
-- Agrupamos a los clientes según el mes de su primera compra
-- y medimos cuántos vuelven a realizar pedidos durante
-- los meses posteriores.
WITH primera_compra AS
(
    SELECT
        vos.customer_id,
        MIN(vos.order_date)
            AS first_order_date,
        CAST(
            DATE_FORMAT(
                MIN(vos.order_date),
                '%Y-%m-01'
            )
            AS DATE
        ) AS cohort_month
    FROM vw_order_summary AS vos
    GROUP BY vos.customer_id
),

actividad_mensual AS
(
    -- Un cliente aparece como máximo una vez por mes,
    -- aunque haya realizado varios pedidos.
    SELECT DISTINCT
        vos.customer_id,
        CAST(
            DATE_FORMAT(
                vos.order_date,
                '%Y-%m-01'
            )
            AS DATE
        ) AS activity_month
    FROM vw_order_summary AS vos
),

tamano_cohorte AS
(
    SELECT
        pc.cohort_month,
        COUNT(*) AS cohort_size
    FROM primera_compra AS pc
    GROUP BY pc.cohort_month
),

actividad_cohorte AS
(
    SELECT
        pc.cohort_month,
        am.activity_month,
        TIMESTAMPDIFF(
            MONTH,
            pc.cohort_month,
            am.activity_month
        ) AS months_since_first_order,
        COUNT(DISTINCT am.customer_id)
            AS active_customers
    FROM primera_compra AS pc
    INNER JOIN actividad_mensual AS am
        ON am.customer_id = pc.customer_id
    WHERE am.activity_month >= pc.cohort_month
    GROUP BY
        pc.cohort_month,
        am.activity_month,
        TIMESTAMPDIFF(
            MONTH,
            pc.cohort_month,
            am.activity_month
        )
)

SELECT
    DATE_FORMAT(
        ac.cohort_month,
        '%Y-%m'
    ) AS cohort_month,
    ac.months_since_first_order,
    tc.cohort_size,
    ac.active_customers,
    ROUND(
        100.0
        *
        ac.active_customers
        /
        NULLIF(tc.cohort_size, 0),
        2
    ) AS retention_percentage
FROM actividad_cohorte AS ac
INNER JOIN tamano_cohorte AS tc
    ON tc.cohort_month = ac.cohort_month
ORDER BY
    ac.cohort_month,
    ac.months_since_first_order;




-- Retención de cada cohorte a 1, 3, 6 y 12 meses.
WITH primera_compra AS
(
    SELECT
        vos.customer_id,
        CAST(
            DATE_FORMAT(
                MIN(vos.order_date),
                '%Y-%m-01'
            )
            AS DATE
        ) AS cohort_month
    FROM vw_order_summary AS vos
    GROUP BY vos.customer_id
),

actividad_mensual AS
(
    SELECT DISTINCT
        vos.customer_id,
        CAST(
            DATE_FORMAT(
                vos.order_date,
                '%Y-%m-01'
            )
            AS DATE
        ) AS activity_month
    FROM vw_order_summary AS vos
),

ultima_fecha AS
(
    SELECT
        CAST(
            DATE_FORMAT(
                MAX(order_date),
                '%Y-%m-01'
            )
            AS DATE
        ) AS last_observed_month
    FROM vw_order_summary
),

tamano_cohorte AS
(
    SELECT
        pc.cohort_month,
        COUNT(*) AS cohort_size
    FROM primera_compra AS pc
    GROUP BY pc.cohort_month
),

retencion AS
(
    SELECT
        pc.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            pc.cohort_month,
            am.activity_month
        ) AS month_number,
        COUNT(DISTINCT am.customer_id)
            AS active_customers
    FROM primera_compra AS pc
    INNER JOIN actividad_mensual AS am
        ON am.customer_id = pc.customer_id
    WHERE am.activity_month >= pc.cohort_month
    GROUP BY
        pc.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            pc.cohort_month,
            am.activity_month
        )
),

resumen AS
(
    SELECT
        tc.cohort_month,
        tc.cohort_size,
        TIMESTAMPDIFF(
            MONTH,
            tc.cohort_month,
            uf.last_observed_month
        ) AS observable_months,
        MAX(
            CASE
                WHEN r.month_number = 1
                    THEN r.active_customers
            END
        ) AS customers_month_1,
        MAX(
            CASE
                WHEN r.month_number = 3
                    THEN r.active_customers
            END
        ) AS customers_month_3,
        MAX(
            CASE
                WHEN r.month_number = 6
                    THEN r.active_customers
            END
        ) AS customers_month_6,
        MAX(
            CASE
                WHEN r.month_number = 12
                    THEN r.active_customers
            END
        ) AS customers_month_12
    FROM tamano_cohorte AS tc
    CROSS JOIN ultima_fecha AS uf
    LEFT JOIN retencion AS r
        ON r.cohort_month = tc.cohort_month
    GROUP BY
        tc.cohort_month,
        tc.cohort_size,
        uf.last_observed_month
)

SELECT
    DATE_FORMAT(
        cohort_month,
        '%Y-%m'
    ) AS cohort_month,
    cohort_size,
    observable_months,
    CASE
        WHEN observable_months >= 1
            THEN ROUND(
                100.0
                *
                COALESCE(customers_month_1, 0)
                /
                NULLIF(cohort_size, 0),
                2
            )
    END AS retention_month_1_percentage,
    CASE
        WHEN observable_months >= 3
            THEN ROUND(
                100.0
                *
                COALESCE(customers_month_3, 0)
                /
                NULLIF(cohort_size, 0),
                2
            )
    END AS retention_month_3_percentage,
    CASE
        WHEN observable_months >= 6
            THEN ROUND(
                100.0
                *
                COALESCE(customers_month_6, 0)
                /
                NULLIF(cohort_size, 0),
                2
            )
    END AS retention_month_6_percentage,
    CASE
        WHEN observable_months >= 12
            THEN ROUND(
                100.0
                *
                COALESCE(customers_month_12, 0)
                /
                NULLIF(cohort_size, 0),
                2
            )
    END AS retention_month_12_percentage
FROM resumen
ORDER BY cohort_month;




-- Cantidad de nuevos clientes incorporados cada mes.
WITH primera_compra AS
(
    SELECT
        customer_id,
        CAST(
            DATE_FORMAT(
                MIN(order_date),
                '%Y-%m-01'
            )
            AS DATE
        ) AS cohort_month
    FROM vw_order_summary
    GROUP BY customer_id
)

SELECT
    DATE_FORMAT(
        cohort_month,
        '%Y-%m'
    ) AS cohort_month,
    COUNT(*) AS new_customers
FROM primera_compra
GROUP BY cohort_month
ORDER BY cohort_month;




-- Validamos que cada cliente pertenezca
-- exactamente a una cohorte.
WITH primera_compra AS
(
    SELECT
        customer_id,
        CAST(
            DATE_FORMAT(
                MIN(order_date),
                '%Y-%m-01'
            )
            AS DATE
        ) AS cohort_month
    FROM vw_order_summary
    GROUP BY customer_id
)

SELECT
    COUNT(*) AS customers_in_cohorts,
    COUNT(DISTINCT customer_id)
        AS unique_customers,
    (
        SELECT COUNT(*)
        FROM customers
    ) AS customers_model,
    COUNT(*)
    -
    (
        SELECT COUNT(*)
        FROM customers
    ) AS difference
FROM primera_compra;





-- Comparación de clientes por segmento
-- Analizamos la composición y el valor de la cartera
-- de clientes dentro de cada segmento.
WITH rendimiento_segmentos AS
(
    SELECT
        vcp.segment,
        COUNT(*) AS total_customers,
        -- Actividad comercial.
        SUM(vcp.total_orders)
            AS total_orders,
        AVG(vcp.total_orders)
            AS average_orders_per_customer,
        SUM(vcp.total_order_lines)
            AS total_order_lines,
        -- Ventas y beneficio.
        SUM(vcp.total_sales)
            AS total_sales,
        AVG(vcp.total_sales)
            AS average_sales_per_customer,
        SUM(vcp.total_profit)
            AS total_profit,
        AVG(vcp.total_profit)
            AS average_profit_per_customer,
        -- Valor promedio de pedido a nivel de cliente.
        AVG(vcp.average_complete_order_value)
            AS average_customer_order_value,
        -- Margen calculado únicamente con clientes cuyas
        -- ventas y beneficios están completamente disponibles.
        SUM(
            CASE
                WHEN vcp.unknown_sales_lines = 0
                 AND vcp.unknown_profit_lines = 0
                    THEN vcp.total_profit
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN vcp.unknown_sales_lines = 0
                     AND vcp.unknown_profit_lines = 0
                        THEN vcp.total_sales
                END
            ),
            0
        ) * 100 AS comparable_profit_margin_percentage,
        -- Recurrencia.
        SUM(
            CASE
                WHEN vcp.total_orders > 1 THEN 1
                ELSE 0
            END
        ) AS repeat_customers,
        SUM(
            CASE
                WHEN vcp.total_orders = 1 THEN 1
                ELSE 0
            END
        ) AS one_time_customers,
        -- Clientes cuya actividad abarca más de un año.
        SUM(
            CASE
                WHEN YEAR(vcp.first_order_date)
                     <
                     YEAR(vcp.last_order_date)
                    THEN 1
                ELSE 0
            END
        ) AS multi_year_customers,
        -- Duración de la relación comercial.
        AVG(vcp.purchase_span_days)
            AS average_purchase_span_days,
        -- Clientes cuyo beneficio conocido acumulado es negativo.
        SUM(
            CASE
                WHEN vcp.total_profit < 0 THEN 1
                ELSE 0
            END
        ) AS customers_with_negative_profit,
        -- Pedidos completos que generaron pérdidas.
        SUM(vcp.complete_loss_making_orders)
            AS complete_loss_making_orders,
        -- Cobertura de información.
        SUM(vcp.unknown_sales_lines)
            AS unknown_sales_lines,
        SUM(vcp.unknown_profit_lines)
            AS unknown_profit_lines
    FROM vw_customer_performance AS vcp
    GROUP BY vcp.segment
),

ranking_segmentos AS
(
    SELECT
        rs.*,
        -- Ranking según ventas acumuladas.
        DENSE_RANK() OVER (
            ORDER BY rs.total_sales DESC
        ) AS sales_rank,
        -- Ranking según beneficio acumulado.
        DENSE_RANK() OVER (
            ORDER BY rs.total_profit DESC
        ) AS profit_rank,
        -- Ranking según ventas promedio por cliente.
        DENSE_RANK() OVER (
            ORDER BY rs.average_sales_per_customer DESC
        ) AS customer_value_rank
    FROM rendimiento_segmentos AS rs
)

SELECT
    segment,
    total_customers,
    total_orders,
    ROUND(
        average_orders_per_customer,
        2
    ) AS average_orders_per_customer,
    total_order_lines,
    ROUND(
        total_sales,
        2
    ) AS total_sales,
    ROUND(
        average_sales_per_customer,
        2
    ) AS average_sales_per_customer,
    ROUND(
        total_profit,
        2
    ) AS total_profit,
    ROUND(
        average_profit_per_customer,
        2
    ) AS average_profit_per_customer,
    ROUND(
        average_customer_order_value,
        2
    ) AS average_customer_order_value,
    ROUND(
        comparable_profit_margin_percentage,
        2
    ) AS comparable_profit_margin_percentage,
    sales_rank,
    profit_rank,
    customer_value_rank,
    repeat_customers,
    one_time_customers,
    ROUND(
        100.0
        *
        repeat_customers
        /
        NULLIF(total_customers, 0),
        2
    ) AS repeat_customer_percentage,
    multi_year_customers,
    ROUND(
        100.0
        *
        multi_year_customers
        /
        NULLIF(total_customers, 0),
        2
    ) AS multi_year_customer_percentage,
    ROUND(
        average_purchase_span_days,
        2
    ) AS average_purchase_span_days,
    customers_with_negative_profit,
    ROUND(
        100.0
        *
        customers_with_negative_profit
        /
        NULLIF(total_customers, 0),
        2
    ) AS negative_profit_customer_percentage,
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
FROM ranking_segmentos
ORDER BY
    sales_rank,
    segment;




-- Participación de cada segmento en clientes y ventas.
SELECT
    segment,
    COUNT(*) AS total_customers,
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
    ) AS customer_share_percentage,
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
    ) AS sales_share_percentage,
    ROUND(
        SUM(total_profit),
        2
    ) AS total_profit
FROM vw_customer_performance
GROUP BY segment
ORDER BY
    total_sales DESC;




-- Validamos clientes, pedidos, ventas y beneficios.
SELECT
    clientes.total_customers
        AS customers_original,
    segmentos.total_customers
        AS customers_segmented,
    segmentos.total_customers
    -
    clientes.total_customers
        AS customer_difference,
    clientes.total_orders
        AS orders_original,
    segmentos.total_orders
        AS orders_segmented,
    segmentos.total_orders
    -
    clientes.total_orders
        AS order_difference,
    clientes.total_sales
        AS sales_original,
    segmentos.total_sales
        AS sales_segmented,
    segmentos.total_sales
    -
    clientes.total_sales
        AS sales_difference,
    clientes.total_profit
        AS profit_original,
    segmentos.total_profit
        AS profit_segmented,
    segmentos.total_profit
    -
    clientes.total_profit
        AS profit_difference
FROM
(
    SELECT
        COUNT(*) AS total_customers,
        SUM(total_orders) AS total_orders,
        SUM(total_sales) AS total_sales,
        SUM(total_profit) AS total_profit
    FROM vw_customer_performance
) AS clientes
CROSS JOIN
(
    SELECT
        SUM(total_customers) AS total_customers,
        SUM(total_orders) AS total_orders,
        SUM(total_sales) AS total_sales,
        SUM(total_profit) AS total_profit
    FROM
    (
        SELECT
            segment,
            COUNT(*) AS total_customers,
            SUM(total_orders) AS total_orders,
            SUM(total_sales) AS total_sales,
            SUM(total_profit) AS total_profit
        FROM vw_customer_performance
        GROUP BY segment
    ) AS resumen_segmentos
) AS segmentos;




