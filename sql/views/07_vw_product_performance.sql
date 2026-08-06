/*
Archivo      : 07_vw_product_performance.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Vista de desempeño por producto
               Resume el desempeño comercial de cada producto.
*/

USE superstore_analytics;

-- Cada fila representa un producto identificado mediante
-- product_key, incluso cuando su código original haya sido
-- reutilizado para otro nombre de producto.
CREATE OR REPLACE VIEW vw_product_performance AS
SELECT
    -- Identificación y clasificación.
    vsd.product_key,
    vsd.product_id,
    vsd.product_name,
    vsd.category,
    vsd.sub_category,
    -- Periodo de actividad.
    MIN(vsd.order_date) AS first_order_date,
    MAX(vsd.order_date) AS last_order_date,
    -- Actividad comercial.
    COUNT(*) AS total_order_lines,
    COUNT(DISTINCT vsd.order_key) AS total_orders,
    COUNT(DISTINCT vsd.customer_id) AS distinct_customers,
    -- Métricas conocidas.
    SUM(vsd.sales) AS total_sales,
    SUM(vsd.quantity) AS total_quantity,
    SUM(vsd.profit) AS total_profit,
    AVG(vsd.discount) AS average_line_discount,
    -- Valor promedio de venta por unidad calculado
    -- únicamente con líneas donde sales y quantity
    -- están disponibles simultáneamente.
    SUM(
        CASE
            WHEN vsd.sales IS NOT NULL
             AND vsd.quantity IS NOT NULL
                THEN vsd.sales
        END
    )
    /
    NULLIF(
        SUM(
            CASE
                WHEN vsd.sales IS NOT NULL
                 AND vsd.quantity IS NOT NULL
                    THEN vsd.quantity
            END
        ),
        0
    ) AS comparable_average_unit_sales,
    -- Margen calculado únicamente con líneas donde
    -- sales y profit son conocidos simultáneamente.
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
    -- Cobertura de información.
    COUNT(*) - COUNT(vsd.sales)
        AS unknown_sales_lines,

    COUNT(*) - COUNT(vsd.quantity)
        AS unknown_quantity_lines,

    COUNT(*) - COUNT(vsd.profit)
        AS unknown_profit_lines,
    -- Líneas conocidas que produjeron pérdidas.
    SUM(
        CASE
            WHEN vsd.profit < 0 THEN 1
            ELSE 0
        END
    ) AS loss_making_lines

FROM vw_sales_detail AS vsd

GROUP BY
    vsd.product_key,
    vsd.product_id,
    vsd.product_name,
    vsd.category,
    vsd.sub_category;


-- Comparamos los productos registrados con las filas
-- generadas en la vista analítica.
SELECT
    (SELECT COUNT(*) FROM products)
        AS productos_modelo,

    (SELECT COUNT(*) FROM vw_product_performance)
        AS productos_vista,

    (SELECT COUNT(*) FROM vw_product_performance)
    -
    (SELECT COUNT(*) FROM products)
        AS diferencia;

    
-- Cada product_key debe aparecer exactamente una vez.
SELECT
    COUNT(*) AS total_productos,
    COUNT(DISTINCT product_key) AS productos_unicos,
    COUNT(*) - COUNT(DISTINCT product_key)
        AS duplicados
FROM vw_product_performance;


-- Verificamos que ningún producto del modelo haya
-- quedado fuera de la vista. (Debe devolver cero filas)
SELECT
    p.product_key,
    p.source_product_id,
    p.product_name
FROM products AS p

LEFT JOIN vw_product_performance AS vpp
    ON vpp.product_key = p.product_key

WHERE vpp.product_key IS NULL;



-- Comprobamos que la agrupación por producto conserve
-- todas las líneas y los totales comerciales.
SELECT
    detalle.total_lineas AS lineas_detalle,
    productos.total_lineas AS lineas_productos,

    productos.total_lineas
    -
    detalle.total_lineas AS diferencia_lineas,

    detalle.total_ventas AS ventas_detalle,
    productos.total_ventas AS ventas_productos,

    productos.total_ventas
    -
    detalle.total_ventas AS diferencia_ventas,

    detalle.total_cantidad AS cantidad_detalle,
    productos.total_cantidad AS cantidad_productos,

    productos.total_cantidad
    -
    detalle.total_cantidad AS diferencia_cantidad,

    detalle.total_beneficio AS beneficio_detalle,
    productos.total_beneficio AS beneficio_productos,

    productos.total_beneficio
    -
    detalle.total_beneficio AS diferencia_beneficio

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
    FROM vw_product_performance
) AS productos;


-- Mostramos los productos con mayores ventas conocidas.
SELECT
    product_key,
    product_id,
    product_name,
    category,
    sub_category,
    total_orders,
    distinct_customers,
    total_sales,
    total_quantity,
    total_profit,
    comparable_average_unit_sales,
    comparable_profit_margin_percentage,
    loss_making_lines,
    unknown_sales_lines,
    unknown_profit_lines
FROM vw_product_performance
ORDER BY
    total_sales DESC,
    product_name
LIMIT 20;