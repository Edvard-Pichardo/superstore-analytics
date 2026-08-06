/*
Archivo      : 10_vw_category_performance.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Vista de desempeño por categoría
               Resume el desempeño comercial de cada categoría.
*/

USE superstore_analytics;

-- Se utiliza vw_sales_detail porque un mismo pedido puede
-- contener productos pertenecientes a varias categorías.
CREATE OR REPLACE VIEW vw_category_performance AS
SELECT
    -- Clasificación principal.
    vsd.category,
    -- Periodo de actividad.
    MIN(vsd.order_date) AS first_order_date,
    MAX(vsd.order_date) AS last_order_date,
    -- Actividad comercial.
    COUNT(*) AS total_order_lines,
    COUNT(DISTINCT vsd.order_key) AS total_orders,
    COUNT(DISTINCT vsd.customer_id) AS distinct_customers,
    COUNT(DISTINCT vsd.product_key) AS distinct_products,
    COUNT(DISTINCT vsd.sub_category) AS distinct_subcategories,
    -- Métricas comerciales conocidas.
    SUM(vsd.sales) AS total_sales,
    SUM(vsd.quantity) AS total_quantity,
    SUM(vsd.profit) AS total_profit,

    AVG(vsd.discount) AS average_line_discount,
    -- Venta promedio por línea con valor conocido.
    AVG(vsd.sales) AS average_known_line_sales,
    -- Beneficio promedio por línea con valor conocido.
    AVG(vsd.profit) AS average_known_line_profit,
    -- Margen calculado únicamente con líneas donde
    -- sales y profit están disponibles simultáneamente.
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
    -- Líneas con beneficio conocido negativo.
    SUM(
        CASE
            WHEN vsd.profit < 0 THEN 1
            ELSE 0
        END
    ) AS loss_making_lines

FROM vw_sales_detail AS vsd

GROUP BY
    vsd.category;


-- Comparamos las categorías del catálogo con las filas
-- generadas en la vista analítica.
SELECT
    (SELECT COUNT(*) FROM categories)
        AS categorias_modelo,

    (SELECT COUNT(*) FROM vw_category_performance)
        AS categorias_vista,

    (SELECT COUNT(*) FROM vw_category_performance)
    -
    (SELECT COUNT(*) FROM categories)
        AS diferencia;


-- Verificamos que ninguna categoría del catálogo haya
-- quedado fuera de la vista.
SELECT
    c.category_id,
    c.category_name
FROM categories AS c

LEFT JOIN vw_category_performance AS vcp
    ON vcp.category = c.category_name

WHERE vcp.category IS NULL;



-- Comprobamos que la agrupación por categoría conserve
-- todas las líneas y los totales comerciales.
SELECT
    detalle.total_lineas AS lineas_detalle,
    categorias.total_lineas AS lineas_categorias,

    categorias.total_lineas
    -
    detalle.total_lineas AS diferencia_lineas,

    detalle.total_ventas AS ventas_detalle,
    categorias.total_ventas AS ventas_categorias,

    categorias.total_ventas
    -
    detalle.total_ventas AS diferencia_ventas,

    detalle.total_cantidad AS cantidad_detalle,
    categorias.total_cantidad AS cantidad_categorias,

    categorias.total_cantidad
    -
    detalle.total_cantidad AS diferencia_cantidad,

    detalle.total_beneficio AS beneficio_detalle,
    categorias.total_beneficio AS beneficio_categorias,

    categorias.total_beneficio
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
    FROM vw_category_performance
) AS categorias;


-- Consultamos resultados
SELECT
    category,
    distinct_subcategories,
    distinct_products,
    distinct_customers,
    total_orders,
    total_order_lines,
    total_sales,
    total_quantity,
    total_profit,
    average_line_discount,
    comparable_profit_margin_percentage,
    loss_making_lines,
    unknown_sales_lines,
    unknown_profit_lines
FROM vw_category_performance
ORDER BY total_sales DESC;