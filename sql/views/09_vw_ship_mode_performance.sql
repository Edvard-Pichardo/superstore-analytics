/*
Archivo      : 09_vw_ship_mode_performance.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Vista de desempeño por modo de envío
               Resume el desempeño comercial y logístico de cada
               modalidad de envío.
*/

USE superstore_analytics;

-- Cada fila representa un modo de envío. Los pedidos cuyo
-- ship_mode es NULL se agrupan bajo la etiqueta 'Unknown'
-- para conservarlos dentro del análisis.
CREATE OR REPLACE VIEW vw_ship_mode_performance AS
SELECT
    -- Modalidad logística.
    COALESCE(
        vos.ship_mode,
        'Unknown'
    ) AS ship_mode,
    -- Permite distinguir explícitamente los pedidos
    -- cuyo modo de envío permanece desconocido.
    CASE
        WHEN vos.ship_mode IS NULL THEN 1
        ELSE 0
    END AS is_unknown_ship_mode,
    -- Periodo de actividad.
    MIN(vos.order_date) AS first_order_date,
    MAX(vos.order_date) AS last_order_date,
    -- Actividad comercial.
    COUNT(*) AS total_orders,

    COUNT(DISTINCT vos.customer_id)
        AS distinct_customers,

    SUM(vos.total_order_lines)
        AS total_order_lines,

    SUM(vos.distinct_products)
        AS total_product_references,
    -- Métricas comerciales conocidas.
    SUM(vos.total_sales)
        AS total_sales,

    SUM(vos.total_quantity)
        AS total_quantity,

    SUM(vos.total_profit)
        AS total_profit,
    -- Valor promedio de pedidos cuyas ventas
    -- se encuentran completamente disponibles.
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
    -- Margen calculado únicamente con pedidos cuyas
    -- ventas y beneficios están completos.
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
    AVG(vos.shipping_days)
        AS average_shipping_days,

    MIN(vos.shipping_days)
        AS minimum_shipping_days,

    MAX(vos.shipping_days)
        AS maximum_shipping_days,
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
    -- Pedidos completos cuyo beneficio total fue negativo.
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
    vos.ship_mode;


-- Comparamos los modos de envío presentes en los pedidos
-- con las filas creadas en la vista.
-- COALESCE permite contar también el grupo desconocido.
SELECT
    (
        SELECT COUNT(
            DISTINCT COALESCE(ship_mode, 'Unknown')
        )
        FROM vw_order_summary
    ) AS modalidades_resumen,

    (
        SELECT COUNT(*)
        FROM vw_ship_mode_performance
    ) AS modalidades_vista,

    (
        SELECT COUNT(*)
        FROM vw_ship_mode_performance
    )
    -
    (
        SELECT COUNT(
            DISTINCT COALESCE(ship_mode, 'Unknown')
        )
        FROM vw_order_summary
    ) AS diferencia;


-- Verificamos que cada modalidad presente en los pedidos
-- tenga correspondencia en la vista.
SELECT
    COALESCE(
        vos.ship_mode,
        'Unknown'
    ) AS ship_mode
FROM vw_order_summary AS vos

LEFT JOIN vw_ship_mode_performance AS vsmp
    ON vsmp.ship_mode = COALESCE(
        vos.ship_mode,
        'Unknown'
    )

WHERE vsmp.ship_mode IS NULL

GROUP BY
    COALESCE(
        vos.ship_mode,
        'Unknown'
    );


-- Comprobamos que la agrupación por modo de envío
-- conserve todos los pedidos y líneas del modelo.
SELECT
    resumen.total_pedidos AS pedidos_resumen,
    modalidades.total_pedidos AS pedidos_modalidades,

    modalidades.total_pedidos
    -
    resumen.total_pedidos AS diferencia_pedidos,

    resumen.total_lineas AS lineas_resumen,
    modalidades.total_lineas AS lineas_modalidades,

    modalidades.total_lineas
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
    FROM vw_ship_mode_performance
) AS modalidades;



-- Verificamos que los totales comerciales acumulados
-- por modalidad coincidan con la vista por pedido.
SELECT
    resumen.total_ventas AS ventas_resumen,
    modalidades.total_ventas AS ventas_modalidades,

    modalidades.total_ventas
    -
    resumen.total_ventas AS diferencia_ventas,

    resumen.total_cantidad AS cantidad_resumen,
    modalidades.total_cantidad AS cantidad_modalidades,

    modalidades.total_cantidad
    -
    resumen.total_cantidad AS diferencia_cantidad,

    resumen.total_beneficio AS beneficio_resumen,
    modalidades.total_beneficio AS beneficio_modalidades,

    modalidades.total_beneficio
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
    FROM vw_ship_mode_performance
) AS modalidades;


-- Consultamos los resultados
SELECT
    ship_mode,
    is_unknown_ship_mode,
    total_orders,
    distinct_customers,
    total_order_lines,
    total_sales,
    total_quantity,
    total_profit,
    average_complete_order_value,
    comparable_profit_margin_percentage,
    average_shipping_days,
    minimum_shipping_days,
    maximum_shipping_days,
    complete_loss_making_orders,
    orders_with_unknown_sales,
    orders_with_unknown_profit
FROM vw_ship_mode_performance
ORDER BY
    is_unknown_ship_mode,
    total_orders DESC;