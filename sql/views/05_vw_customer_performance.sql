/*
Archivo      : 05_vw_customer_performance.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Vista de desempeño por cliente
               Resume la actividad comercial de cada cliente.
*/

USE superstore_analytics;

-- Cada fila representa un cliente e integra sus pedidos,
-- ventas, cantidades, beneficios y cobertura de datos.
CREATE OR REPLACE VIEW vw_customer_performance AS
SELECT
    -- Información del cliente.
    vos.customer_id,
    vos.customer_name,
    vos.segment,
    -- Frecuencia y periodo de compra.
    COUNT(*) AS total_orders,
    MIN(vos.order_date) AS first_order_date,
    MAX(vos.order_date) AS last_order_date,

    DATEDIFF(
        MAX(vos.order_date),
        MIN(vos.order_date)
    ) AS purchase_span_days,
    -- Cantidad de ubicaciones distintas utilizadas
    -- por el cliente en sus pedidos.
    COUNT(
        DISTINCT
        vos.country,
        vos.state,
        vos.city,
        vos.postal_code,
        vos.region
    ) AS distinct_locations,
    -- Actividad comercial.
    SUM(vos.total_order_lines) AS total_order_lines,
    -- Suma de productos distintos dentro de cada pedido.
    -- Un mismo producto comprado en pedidos diferentes
    -- puede contabilizarse más de una vez.
    SUM(vos.distinct_products) AS total_product_references,
    -- Métricas comerciales conocidas.
    SUM(vos.total_sales) AS total_sales,
    SUM(vos.total_quantity) AS total_quantity,
    SUM(vos.total_profit) AS total_profit,
    -- Valor promedio calculado únicamente con pedidos
    -- cuyas ventas están completamente disponibles.
    AVG(
        CASE
            WHEN vos.unknown_sales_lines = 0
                THEN vos.total_sales
        END
    ) AS average_complete_order_value,
    -- Margen calculado únicamente con pedidos donde
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
    -- Desempeño logístico.
    AVG(vos.shipping_days) AS average_shipping_days,
    -- Cobertura de información.
    SUM(vos.unknown_sales_lines)
        AS unknown_sales_lines,

    SUM(vos.unknown_quantity_lines)
        AS unknown_quantity_lines,

    SUM(vos.unknown_profit_lines)
        AS unknown_profit_lines,

    SUM(
        CASE
            WHEN vos.unknown_sales_lines > 0 THEN 1
            ELSE 0
        END
    ) AS orders_with_unknown_sales,

    SUM(
        CASE
            WHEN vos.unknown_profit_lines > 0 THEN 1
            ELSE 0
        END
    ) AS orders_with_unknown_profit,
    -- Solo clasificamos como pérdida los pedidos cuyo
    -- beneficio se encuentra completamente disponible.
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
    vos.customer_id,
    vos.customer_name,
    vos.segment;



-- Comparamos los clientes del modelo con los
-- clientes incluidos en la vista.
SELECT
    (SELECT COUNT(*) FROM customers)
        AS clientes_modelo,

    (SELECT COUNT(*) FROM vw_customer_performance)
        AS clientes_vista,

    (SELECT COUNT(*) FROM vw_customer_performance)
    -
    (SELECT COUNT(*) FROM customers)
        AS diferencia;


-- Verificamos que ningún cliente del modelo haya
-- quedado fuera de la vista analítica. (Debe devolver cero filas)
SELECT
    c.customer_id,
    c.customer_name
FROM customers AS c

LEFT JOIN vw_customer_performance AS vcp
    ON vcp.customer_id = c.customer_id

WHERE vcp.customer_id IS NULL;


-- Comprobamos que la agrupación por cliente conserve
-- todos los pedidos y líneas de venta.
SELECT
    resumen.total_pedidos AS pedidos_resumen,
    clientes.total_pedidos AS pedidos_clientes,

    clientes.total_pedidos
    -
    resumen.total_pedidos AS diferencia_pedidos,

    resumen.total_lineas AS lineas_resumen,
    clientes.total_lineas AS lineas_clientes,

    clientes.total_lineas
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
    FROM vw_customer_performance
) AS clientes;



-- Verificamos que las métricas acumuladas por cliente
-- coincidan con los totales de la vista por pedido.
SELECT
    resumen.total_ventas AS ventas_resumen,
    clientes.total_ventas AS ventas_clientes,

    clientes.total_ventas
    -
    resumen.total_ventas AS diferencia_ventas,

    resumen.total_cantidad AS cantidad_resumen,
    clientes.total_cantidad AS cantidad_clientes,

    clientes.total_cantidad
    -
    resumen.total_cantidad AS diferencia_cantidad,

    resumen.total_beneficio AS beneficio_resumen,
    clientes.total_beneficio AS beneficio_clientes,

    clientes.total_beneficio
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
    FROM vw_customer_performance
) AS clientes;


-- Mostramos los clientes con mayores ventas conocidas.
SELECT
    customer_id,
    customer_name,
    segment,
    total_orders,
    first_order_date,
    last_order_date,
    purchase_span_days,
    distinct_locations,
    total_sales,
    total_profit,
    average_complete_order_value,
    comparable_profit_margin_percentage,
    complete_loss_making_orders,
    orders_with_unknown_sales
FROM vw_customer_performance
ORDER BY
    total_sales DESC,
    customer_name
LIMIT 20;