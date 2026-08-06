/*
Archivo      : 03_vw_monthly_performance.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Vista de desempeño mensual
               Resume los pedidos y métricas comerciales por año y mes.
*/

USE superstore_analytics;

-- Se utiliza vw_order_summary como fuente porque contiene
-- exactamente una fila por cada pedido lógico.
CREATE OR REPLACE VIEW vw_monthly_performance AS
SELECT
    -- Periodo analizado.
    vos.order_year,
    vos.order_month,
    vos.order_year_month,
    -- Actividad comercial.
    COUNT(*) AS total_orders,
    COUNT(DISTINCT vos.customer_id) AS distinct_customers,
    SUM(vos.total_order_lines) AS total_order_lines,
    SUM(vos.distinct_products) AS total_product_references,
    -- Métricas comerciales conocidas.
    SUM(vos.total_sales) AS total_sales,
    SUM(vos.total_quantity) AS total_quantity,
    SUM(vos.total_profit) AS total_profit,
    -- Promedios calculados únicamente con pedidos
    -- completamente conocidos para cada métrica.
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
    -- Margen calculado sobre los valores disponibles.
    SUM(vos.total_profit)
        / NULLIF(SUM(vos.total_sales), 0) * 100
        AS profit_margin_percentage,
    -- Indicadores de información incompleta.
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
            WHEN vos.unknown_profit_lines > 0 THEN 1
            ELSE 0
        END
    ) AS orders_with_unknown_profit

FROM vw_order_summary AS vos

GROUP BY
    vos.order_year,
    vos.order_month,
    vos.order_year_month;


-- Comparamos los periodos distintos de los pedidos
-- con las filas generadas en la vista mensual.
SELECT
    (
        SELECT COUNT(DISTINCT order_year_month)
        FROM vw_order_summary
    ) AS periodos_pedidos,

    (
        SELECT COUNT(*)
        FROM vw_monthly_performance
    ) AS periodos_vista,

    (
        SELECT COUNT(*)
        FROM vw_monthly_performance
    )
    -
    (
        SELECT COUNT(DISTINCT order_year_month)
        FROM vw_order_summary
    ) AS diferencia;



-- Verificamos que la agrupación mensual conserve
-- todos los pedidos y todas las líneas de venta.
SELECT
    resumen.total_pedidos AS pedidos_resumen,
    mensual.total_pedidos AS pedidos_mensual,
    mensual.total_pedidos - resumen.total_pedidos
        AS diferencia_pedidos,

    resumen.total_lineas AS lineas_resumen,
    mensual.total_lineas AS lineas_mensual,
    mensual.total_lineas - resumen.total_lineas
        AS diferencia_lineas

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
    FROM vw_monthly_performance
) AS mensual;


-- Comparamos las métricas de la vista por pedido
-- con las métricas de la vista mensual.
SELECT
    resumen.total_ventas AS ventas_resumen,
    mensual.total_ventas AS ventas_mensual,
    mensual.total_ventas - resumen.total_ventas
        AS diferencia_ventas,

    resumen.total_cantidad AS cantidad_resumen,
    mensual.total_cantidad AS cantidad_mensual,
    mensual.total_cantidad - resumen.total_cantidad
        AS diferencia_cantidad,

    resumen.total_beneficio AS beneficio_resumen,
    mensual.total_beneficio AS beneficio_mensual,
    mensual.total_beneficio - resumen.total_beneficio
        AS diferencia_beneficio

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
    FROM vw_monthly_performance
) AS mensual;


-- Mostramos una parte de la vista
SELECT
    order_year_month,
    total_orders,
    distinct_customers,
    total_sales,
    total_quantity,
    total_profit,
    average_complete_order_value,
    profit_margin_percentage,
    orders_with_unknown_sales,
    orders_with_unknown_profit
FROM vw_monthly_performance
ORDER BY
    order_year,
    order_month;
