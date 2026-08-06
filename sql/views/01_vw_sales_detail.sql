/*
Archivo      : 01_vw_sales_detail.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Vista detallada de ventas.
               Integra las principales tablas del modelo relacional
               de líneas de venta.
*/

USE superstore_analytics;

-- Cada fila representa un producto incluido en un pedido.
-- Esta vista servirá como fuente base para las consultas
-- analíticas y los indicadores comerciales posteriores.
CREATE OR REPLACE VIEW vw_sales_detail AS
SELECT
    -- Identificadores internos y originales.
    od.order_detail_key,
    od.source_row_id,

    o.order_key,
    o.source_order_id AS order_id,
    -- Información temporal y logística.
    o.order_date,
    o.ship_date,
    DATEDIFF(o.ship_date, o.order_date) AS shipping_days,
    sm.ship_mode_name AS ship_mode,
    -- Información del cliente.
    c.customer_id,
    c.customer_name,
    s.segment_name AS segment,
    -- Información geográfica.
    l.country,
    l.state,
    l.city,
    l.postal_code,
    r.region_name AS region,
    -- Información del producto.
    p.product_key,
    p.source_product_id AS product_id,
    p.product_name,
    cat.category_name AS category,
    sc.sub_category_name AS sub_category,
    -- Métricas comerciales.
    od.sales,
    od.quantity,
    od.discount,
    od.profit

FROM order_details AS od

INNER JOIN orders AS o
    ON o.order_key = od.order_key

LEFT JOIN ship_modes AS sm
    ON sm.ship_mode_id = o.ship_mode_id

INNER JOIN customers AS c
    ON c.customer_id = o.customer_id

INNER JOIN segments AS s
    ON s.segment_id = c.segment_id

INNER JOIN locations AS l
    ON l.location_id = o.location_id

INNER JOIN regions AS r
    ON r.region_id = l.region_id

INNER JOIN products AS p
    ON p.product_key = od.product_key

INNER JOIN sub_categories AS sc
    ON sc.sub_category_id = p.sub_category_id

INNER JOIN categories AS cat
    ON cat.category_id = sc.category_id;


-- La vista debe conservar exactamente una fila
-- por cada registro de order_details.
SELECT
    (SELECT COUNT(*) FROM order_details) AS filas_modelo,
    (SELECT COUNT(*) FROM vw_sales_detail) AS filas_vista,
    (SELECT COUNT(*) FROM vw_sales_detail)
        -
    (SELECT COUNT(*) FROM order_details) AS diferencia;


-- Comprobamos que ninguna línea se haya duplicado
-- durante las relaciones entre tablas.
SELECT
    COUNT(*) AS total_filas,
    COUNT(DISTINCT source_row_id) AS filas_originales_unicas,
    COUNT(*) - COUNT(DISTINCT source_row_id)
        AS duplicados
FROM vw_sales_detail;


-- Mostramos una parte de la vista
SELECT
    source_row_id,
    order_id,
    order_date,
    customer_name,
    city,
    product_name,
    category,
    sales,
    quantity,
    discount,
    profit
FROM vw_sales_detail
ORDER BY source_row_id
LIMIT 20;