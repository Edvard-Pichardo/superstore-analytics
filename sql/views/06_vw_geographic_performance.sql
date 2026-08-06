/*
Archivo      : 06_vw_geographic_performance.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Vista de desempeño geográfico
               Resume el desempeño comercial de cada ciudad.
*/

USE superstore_analytics;

-- Cada fila representa una combinación única de región,
-- país, estado y ciudad. Los diferentes códigos postales
-- de una misma ciudad se agrupan en una sola fila.
CREATE OR REPLACE VIEW vw_geographic_performance AS
SELECT
    -- Información geográfica.
    vos.region,
    vos.country,
    vos.state,
    vos.city,

    COUNT(DISTINCT vos.postal_code)
        AS distinct_postal_codes,
    -- Actividad comercial.
    COUNT(*) AS total_orders,
    COUNT(DISTINCT vos.customer_id)
        AS distinct_customers,

    SUM(vos.total_order_lines)
        AS total_order_lines,
    -- Métricas comerciales conocidas.
    SUM(vos.total_sales)
        AS total_sales,

    SUM(vos.total_quantity)
        AS total_quantity,

    SUM(vos.total_profit)
        AS total_profit,
    -- Valor promedio calculado únicamente con pedidos
    -- cuyas ventas se encuentran completamente disponibles.
    AVG(
        CASE
            WHEN vos.unknown_sales_lines = 0
                THEN vos.total_sales
        END
    ) AS average_complete_order_value,
    -- Margen calculado con pedidos cuyas ventas y
    -- beneficios se encuentran completamente disponibles.
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
    vos.region,
    vos.country,
    vos.state,
    vos.city;


-- Verificamos que exista una fila por cada combinación
-- única de región, país, estado y ciudad.
SELECT
    (
        SELECT COUNT(*)
        FROM
        (
            SELECT
                region,
                country,
                state,
                city
            FROM vw_order_summary
            GROUP BY
                region,
                country,
                state,
                city
        ) AS ciudades_unicas
    ) AS ciudades_resumen,

    (
        SELECT COUNT(*)
        FROM vw_geographic_performance
    ) AS ciudades_vista,

    (
        SELECT COUNT(*)
        FROM vw_geographic_performance
    )
    -
    (
        SELECT COUNT(*)
        FROM
        (
            SELECT
                region,
                country,
                state,
                city
            FROM vw_order_summary
            GROUP BY
                region,
                country,
                state,
                city
        ) AS ciudades_unicas
    ) AS diferencia;



-- Verificamos que ninguna ciudad presente en los pedidos
-- haya quedado fuera de la vista geográfica. (Debe devolver cero filas)
SELECT
    vos.region,
    vos.country,
    vos.state,
    vos.city
FROM vw_order_summary AS vos

LEFT JOIN vw_geographic_performance AS vgp
    ON vgp.region = vos.region
   AND vgp.country = vos.country
   AND vgp.state = vos.state
   AND vgp.city = vos.city

WHERE vgp.city IS NULL

GROUP BY
    vos.region,
    vos.country,
    vos.state,
    vos.city;


-- Comprobamos que la agrupación geográfica conserve
-- todos los pedidos y líneas de venta.
SELECT
    resumen.total_pedidos AS pedidos_resumen,
    geografia.total_pedidos AS pedidos_geografia,

    geografia.total_pedidos
    -
    resumen.total_pedidos AS diferencia_pedidos,

    resumen.total_lineas AS lineas_resumen,
    geografia.total_lineas AS lineas_geografia,

    geografia.total_lineas
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
    FROM vw_geographic_performance
) AS geografia;


-- Verificamos que los totales comerciales de la vista
-- geográfica coincidan con la vista por pedido.
SELECT
    resumen.total_ventas AS ventas_resumen,
    geografia.total_ventas AS ventas_geografia,

    geografia.total_ventas
    -
    resumen.total_ventas AS diferencia_ventas,

    resumen.total_cantidad AS cantidad_resumen,
    geografia.total_cantidad AS cantidad_geografia,

    geografia.total_cantidad
    -
    resumen.total_cantidad AS diferencia_cantidad,

    resumen.total_beneficio AS beneficio_resumen,
    geografia.total_beneficio AS beneficio_geografia,

    geografia.total_beneficio
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
    FROM vw_geographic_performance
) AS geografia;


-- Mostramos las ciudades con mayores ventas conocidas.
SELECT
    region,
    country,
    state,
    city,
    distinct_postal_codes,
    total_orders,
    distinct_customers,
    total_sales,
    total_profit,
    average_complete_order_value,
    comparable_profit_margin_percentage,
    average_shipping_days,
    complete_loss_making_orders
FROM vw_geographic_performance
ORDER BY
    total_sales DESC,
    country,
    state,
    city
LIMIT 20;