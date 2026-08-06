/*
Archivo      : 02_vw_order_summary.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Vista resumida por pedido.
               Resume las líneas de venta de cada pedido.
*/

USE superstore_analytics;

-- Cada fila representa un pedido lógico identificado por
-- order_key, independientemente de que el order_id original
-- haya sido reutilizado en el conjunto de origen.
CREATE OR REPLACE VIEW vw_order_summary AS
SELECT
    -- Identificadores del pedido.
    vsd.order_key,
    vsd.order_id,
    -- Información temporal y logística.
    vsd.order_date,
    YEAR(vsd.order_date) AS order_year,
    MONTH(vsd.order_date) AS order_month,
    DATE_FORMAT(vsd.order_date, '%Y-%m') AS order_year_month,

    vsd.ship_date,
    vsd.shipping_days,
    vsd.ship_mode,
    -- Información del cliente.
    vsd.customer_id,
    vsd.customer_name,
    vsd.segment,
    -- Información geográfica del pedido.
    vsd.country,
    vsd.state,
    vsd.city,
    vsd.postal_code,
    vsd.region,
    -- Cantidad de líneas y productos diferentes.
    COUNT(*) AS total_order_lines,
    COUNT(DISTINCT vsd.product_key) AS distinct_products,
    -- Métricas comerciales del pedido.
    SUM(vsd.sales) AS total_sales,
    SUM(vsd.quantity) AS total_quantity,
    AVG(vsd.discount) AS average_line_discount,
    SUM(vsd.profit) AS total_profit,
    -- Indicadores de información incompleta.
    COUNT(*) - COUNT(vsd.sales)
        AS unknown_sales_lines,

    COUNT(*) - COUNT(vsd.quantity)
        AS unknown_quantity_lines,

    COUNT(*) - COUNT(vsd.profit)
        AS unknown_profit_lines

FROM vw_sales_detail AS vsd

GROUP BY
    vsd.order_key,
    vsd.order_id,
    vsd.order_date,
    vsd.ship_date,
    vsd.shipping_days,
    vsd.ship_mode,
    vsd.customer_id,
    vsd.customer_name,
    vsd.segment,
    vsd.country,
    vsd.state,
    vsd.city,
    vsd.postal_code,
    vsd.region;


-- Comparamos la cantidad de pedidos del modelo
-- con la cantidad de filas de la vista.
SELECT
    (SELECT COUNT(*) FROM orders) AS pedidos_modelo,
    (SELECT COUNT(*) FROM vw_order_summary) AS pedidos_vista,

    (SELECT COUNT(*) FROM vw_order_summary)
    -
    (SELECT COUNT(*) FROM orders) AS diferencia;


-- Cada order_key debe aparecer una sola vez.
SELECT
    COUNT(*) AS total_pedidos,
    COUNT(DISTINCT order_key) AS pedidos_unicos,
    COUNT(*) - COUNT(DISTINCT order_key) AS duplicados
FROM vw_order_summary;


-- Verificamos que la agregación por pedido conserve
-- la cantidad de líneas y los totales comerciales.
SELECT
    detalle.total_lineas AS lineas_detalle,
    resumen.total_lineas AS lineas_resumen,
    resumen.total_lineas - detalle.total_lineas
        AS diferencia_lineas,

    detalle.total_ventas AS ventas_detalle,
    resumen.total_ventas AS ventas_resumen,
    resumen.total_ventas - detalle.total_ventas
        AS diferencia_ventas,

    detalle.total_cantidad AS cantidad_detalle,
    resumen.total_cantidad AS cantidad_resumen,
    resumen.total_cantidad - detalle.total_cantidad
        AS diferencia_cantidad,

    detalle.total_beneficio AS beneficio_detalle,
    resumen.total_beneficio AS beneficio_resumen,
    resumen.total_beneficio - detalle.total_beneficio
        AS diferencia_beneficio

FROM
(
    SELECT
        COUNT(*) AS total_lineas,
        SUM(sales) AS total_ventas,
        SUM(quantity) AS total_cantidad,
        SUM(profit) AS total_beneficio
    FROM vw_sales_detail
) AS detalle

CROSS JOIN
(
    SELECT
        SUM(total_order_lines) AS total_lineas,
        SUM(total_sales) AS total_ventas,
        SUM(total_quantity) AS total_cantidad,
        SUM(total_profit) AS total_beneficio
    FROM vw_order_summary
) AS resumen;

-- Mostramos una parte de la vista
SELECT
    order_key,
    order_id,
    order_date,
    customer_name,
    city,
    total_order_lines,
    distinct_products,
    total_sales,
    total_quantity,
    average_line_discount,
    total_profit
FROM vw_order_summary
ORDER BY order_date, order_key
LIMIT 20;