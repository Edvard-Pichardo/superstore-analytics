/*
Archivo      : 11_vw_business_overview.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Vista ejecutiva del negocio
               Presenta los principales indicadores generales del negocio.
*/

USE superstore_analytics;

-- La vista contiene exactamente una fila y utiliza
-- vw_order_summary para conservar el nivel de pedido.
CREATE OR REPLACE VIEW vw_business_overview AS
SELECT
    -- Periodo analizado.
    MIN(vos.order_date) AS first_order_date,
    MAX(vos.order_date) AS last_order_date,

    DATEDIFF(
        MAX(vos.order_date),
        MIN(vos.order_date)
    ) + 1 AS analysis_period_days,
    -- Tamaño general del modelo.
    COUNT(*) AS total_orders,

    COUNT(DISTINCT vos.customer_id)
        AS total_customers,

    (
        SELECT COUNT(*)
        FROM products
    ) AS total_products,

    (
        SELECT COUNT(*)
        FROM categories
    ) AS total_categories,

    (
        SELECT COUNT(*)
        FROM sub_categories
    ) AS total_subcategories,

    (
        SELECT COUNT(*)
        FROM locations
    ) AS total_locations,

    (
        SELECT COUNT(*)
        FROM regions
    ) AS total_regions,

    SUM(vos.total_order_lines)
        AS total_order_lines,
    -- Métricas comerciales conocidas.
    SUM(vos.total_sales)
        AS total_sales,

    SUM(vos.total_quantity)
        AS total_quantity,

    SUM(vos.total_profit)
        AS total_profit,
    -- Promedios calculados únicamente con pedidos
    -- cuya métrica se encuentra completamente disponible.
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
    -- Margen calculado solo con pedidos donde ventas
    -- y beneficios se encuentran completos.
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
    -- Actividad promedio por cliente.
    COUNT(*)
    /
    NULLIF(
        COUNT(DISTINCT vos.customer_id),
        0
    ) AS average_orders_per_customer,
    -- Desempeño logístico.
    AVG(vos.shipping_days)
        AS average_shipping_days,

    MIN(vos.shipping_days)
        AS minimum_shipping_days,

    MAX(vos.shipping_days)
        AS maximum_shipping_days,
    -- Valores desconocidos a nivel de línea.
    SUM(vos.unknown_sales_lines)
        AS unknown_sales_lines,

    SUM(vos.unknown_quantity_lines)
        AS unknown_quantity_lines,

    SUM(vos.unknown_profit_lines)
        AS unknown_profit_lines,
    -- Cobertura porcentual de las métricas.
    100.0
    *
    (
        SUM(vos.total_order_lines)
        -
        SUM(vos.unknown_sales_lines)
    )
    /
    NULLIF(
        SUM(vos.total_order_lines),
        0
    ) AS sales_coverage_percentage,

    100.0
    *
    (
        SUM(vos.total_order_lines)
        -
        SUM(vos.unknown_quantity_lines)
    )
    /
    NULLIF(
        SUM(vos.total_order_lines),
        0
    ) AS quantity_coverage_percentage,

    100.0
    *
    (
        SUM(vos.total_order_lines)
        -
        SUM(vos.unknown_profit_lines)
    )
    /
    NULLIF(
        SUM(vos.total_order_lines),
        0
    ) AS profit_coverage_percentage,
    -- Pedidos con información incompleta.
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

    SUM(
        CASE
            WHEN vos.ship_mode IS NULL THEN 1
            ELSE 0
        END
    ) AS orders_with_unknown_ship_mode,
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

FROM vw_order_summary AS vos;


-- Verificamos que la vista represente un único
-- resumen ejecutivo del negocio.
SELECT COUNT(*) AS total_filas
FROM vw_business_overview;


-- Comparamos los indicadores principales con
-- vw_order_summary.
SELECT
    resumen.total_pedidos AS pedidos_resumen,
    ejecutivo.total_orders AS pedidos_ejecutivo,

    ejecutivo.total_orders
    -
    resumen.total_pedidos AS diferencia_pedidos,

    resumen.total_lineas AS lineas_resumen,
    ejecutivo.total_order_lines AS lineas_ejecutivo,

    ejecutivo.total_order_lines
    -
    resumen.total_lineas AS diferencia_lineas,

    resumen.total_ventas AS ventas_resumen,
    ejecutivo.total_sales AS ventas_ejecutivo,

    ejecutivo.total_sales
    -
    resumen.total_ventas AS diferencia_ventas,

    resumen.total_cantidad AS cantidad_resumen,
    ejecutivo.total_quantity AS cantidad_ejecutivo,

    ejecutivo.total_quantity
    -
    resumen.total_cantidad AS diferencia_cantidad,

    resumen.total_beneficio AS beneficio_resumen,
    ejecutivo.total_profit AS beneficio_ejecutivo,

    ejecutivo.total_profit
    -
    resumen.total_beneficio AS diferencia_beneficio

FROM
(
    SELECT
        COUNT(*) AS total_pedidos,
        SUM(total_order_lines) AS total_lineas,
        SUM(total_sales) AS total_ventas,
        SUM(total_quantity) AS total_cantidad,
        SUM(total_profit) AS total_beneficio
    FROM vw_order_summary
) AS resumen

CROSS JOIN vw_business_overview AS ejecutivo;


-- Comprobamos los conteos generales del modelo.
SELECT
    total_orders,
    total_customers,
    total_products,
    total_categories,
    total_subcategories,
    total_locations,
    total_regions,
    total_order_lines
FROM vw_business_overview;

-- Consultamos
SELECT
    first_order_date,
    last_order_date,
    analysis_period_days,

    total_orders,
    total_customers,
    total_products,
    total_locations,

    total_sales,
    total_quantity,
    total_profit,

    average_complete_order_value,
    average_complete_order_profit,
    comparable_profit_margin_percentage,
    average_orders_per_customer,

    average_shipping_days,
    sales_coverage_percentage,
    quantity_coverage_percentage,
    profit_coverage_percentage,

    complete_loss_making_orders,
    orders_with_unknown_sales,
    orders_with_unknown_profit,
    orders_with_unknown_ship_mode

FROM vw_business_overview;