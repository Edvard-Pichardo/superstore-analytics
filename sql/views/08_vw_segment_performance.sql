/*
Archivo      : 08_vw_segment_performance.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Vista de desempeño por segmento
               Resume la actividad comercial de cada segmento.
*/

USE superstore_analytics;

-- Cada fila representa un segmento e incluye pedidos,
-- clientes, ventas, rentabilidad, logística y cobertura
-- de información.
CREATE OR REPLACE VIEW vw_segment_performance AS
SELECT
    -- Identificación del segmento.
    vos.segment,
    -- Periodo de actividad.
    MIN(vos.order_date) AS first_order_date,
    MAX(vos.order_date) AS last_order_date,
    -- Actividad comercial.
    COUNT(*) AS total_orders,
    COUNT(DISTINCT vos.customer_id) AS distinct_customers,
    SUM(vos.total_order_lines) AS total_order_lines,
    SUM(vos.distinct_products) AS total_product_references,
    -- Métricas comerciales conocidas.
    SUM(vos.total_sales) AS total_sales,
    SUM(vos.total_quantity) AS total_quantity,
    SUM(vos.total_profit) AS total_profit,
    -- Valor promedio calculado únicamente con pedidos
    -- cuyas ventas se encuentran completamente disponibles.
    AVG(
        CASE
            WHEN vos.unknown_sales_lines = 0
                THEN vos.total_sales
        END
    ) AS average_complete_order_value,
    -- Beneficio promedio de pedidos con información
    -- completa de profit.
    AVG(
        CASE
            WHEN vos.unknown_profit_lines = 0
                THEN vos.total_profit
        END
    ) AS average_complete_order_profit,
    -- Margen calculado únicamente con pedidos que tienen
    -- ventas y beneficios completamente disponibles.
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
    -- Desempeño logístico.
    AVG(vos.shipping_days) AS average_shipping_days,
    MIN(vos.shipping_days) AS minimum_shipping_days,
    MAX(vos.shipping_days) AS maximum_shipping_days,
    -- Cobertura de información.
    SUM(vos.unknown_sales_lines) AS unknown_sales_lines,
    SUM(vos.unknown_quantity_lines) AS unknown_quantity_lines,
    SUM(vos.unknown_profit_lines) AS unknown_profit_lines,

    SUM(
        CASE
            WHEN vos.unknown_sales_lines > 0 THEN 1
            ELSE 0
        END
    ) AS orders_with_unknown_sales,

    SUM(
        CASE
            WHEN vos.unknown_quantity_lines > 0 THEN 1
            ELSE 0
        END
    ) AS orders_with_unknown_quantity,

    SUM(
        CASE
            WHEN vos.unknown_profit_lines > 0 THEN 1
            ELSE 0
        END
    ) AS orders_with_unknown_profit,
    -- Pedidos con beneficio completo cuyo resultado
    -- comercial fue negativo.
    SUM(
        CASE
            WHEN vos.unknown_profit_lines = 0
             AND vos.total_profit < 0
                THEN 1
            ELSE 0
        END
    ) AS complete_loss_making_orders

FROM vw_order_summary AS vos

GROUP BY vos.segment;


-- Comparamos los segmentos del catálogo con las filas
-- generadas en la vista.
SELECT
    (SELECT COUNT(*) FROM segments)
        AS segmentos_modelo,

    (SELECT COUNT(*) FROM vw_segment_performance)
        AS segmentos_vista,

    (SELECT COUNT(*) FROM vw_segment_performance)
    -
    (SELECT COUNT(*) FROM segments)
        AS diferencia;


-- Verificamos que ningún segmento del catálogo haya
-- quedado fuera de la vista analítica.
SELECT
    s.segment_id,
    s.segment_name
FROM segments AS s

LEFT JOIN vw_segment_performance AS vsp
    ON vsp.segment = s.segment_name

WHERE vsp.segment IS NULL;



-- Comprobamos que la agrupación por segmento conserve
-- todos los pedidos y líneas del modelo.
SELECT
    resumen.total_pedidos AS pedidos_resumen,
    segmentos.total_pedidos AS pedidos_segmentos,

    segmentos.total_pedidos
    -
    resumen.total_pedidos AS diferencia_pedidos,

    resumen.total_lineas AS lineas_resumen,
    segmentos.total_lineas AS lineas_segmentos,

    segmentos.total_lineas
    -
    resumen.total_lineas AS diferencia_lineas

FROM
(
    SELECT
        COUNT(*) AS total_pedidos,
        SUM(total_order_lines) AS total_lineas
    FROM vw_order_summary
) AS resumen

CROSS JOIN
(
    SELECT
        SUM(total_orders) AS total_pedidos,
        SUM(total_order_lines) AS total_lineas
    FROM vw_segment_performance
) AS segmentos;



-- Verificamos que los totales comerciales acumulados
-- por segmento coincidan con la vista por pedido.
SELECT
    resumen.total_ventas AS ventas_resumen,
    segmentos.total_ventas AS ventas_segmentos,

    segmentos.total_ventas
    -
    resumen.total_ventas AS diferencia_ventas,

    resumen.total_cantidad AS cantidad_resumen,
    segmentos.total_cantidad AS cantidad_segmentos,

    segmentos.total_cantidad
    -
    resumen.total_cantidad AS diferencia_cantidad,

    resumen.total_beneficio AS beneficio_resumen,
    segmentos.total_beneficio AS beneficio_segmentos,

    segmentos.total_beneficio
    -
    resumen.total_beneficio AS diferencia_beneficio

FROM
(
    SELECT
        SUM(total_sales) AS total_ventas,
        SUM(total_quantity) AS total_cantidad,
        SUM(total_profit) AS total_beneficio
    FROM vw_order_summary
) AS resumen

CROSS JOIN
(
    SELECT
        SUM(total_sales) AS total_ventas,
        SUM(total_quantity) AS total_cantidad,
        SUM(total_profit) AS total_beneficio
    FROM vw_segment_performance
) AS segmentos;


-- Consultamos los resultados
SELECT
    segment,
    distinct_customers,
    total_orders,
    total_order_lines,
    total_sales,
    total_quantity,
    total_profit,
    average_complete_order_value,
    average_complete_order_profit,
    comparable_profit_margin_percentage,
    average_shipping_days,
    complete_loss_making_orders,
    orders_with_unknown_sales,
    orders_with_unknown_profit
FROM vw_segment_performance
ORDER BY total_sales DESC;