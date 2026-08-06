/*
Archivo      : 04_vw_subcategory_performance.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Vista de desempeño por subcategoría
               Resume el desempeño comercial de cada subcategoría.
*/

USE superstore_analytics;

-- Cada fila representa una subcategoría dentro de su
-- categoría correspondiente.

CREATE OR REPLACE VIEW vw_subcategory_performance AS
SELECT
    -- Clasificación del producto.
    vsd.category,
    vsd.sub_category,
    -- Actividad comercial.
    COUNT(*) AS total_order_lines,
    COUNT(DISTINCT vsd.order_key) AS total_orders,
    COUNT(DISTINCT vsd.customer_id) AS distinct_customers,
    COUNT(DISTINCT vsd.product_key) AS distinct_products,
    -- Métricas conocidas.
    SUM(vsd.sales) AS total_sales,
    SUM(vsd.quantity) AS total_quantity,
    SUM(vsd.profit) AS total_profit,

    AVG(vsd.discount) AS average_line_discount,
    -- Margen calculado únicamente con filas donde
    -- tanto sales como profit son conocidos.
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

    SUM(
        CASE
            WHEN vsd.profit < 0 THEN 1
            ELSE 0
        END
    ) AS loss_making_lines

FROM vw_sales_detail AS vsd

GROUP BY
    vsd.category,
    vsd.sub_category;


-- Comparamos las subcategorías del modelo con las
-- filas de la vista analítica.
SELECT
    (SELECT COUNT(*) FROM sub_categories)
        AS subcategorias_modelo,

    (SELECT COUNT(*) FROM vw_subcategory_performance)
        AS subcategorias_vista,

    (SELECT COUNT(*) FROM vw_subcategory_performance)
    -
    (SELECT COUNT(*) FROM sub_categories)
        AS diferencia;



-- Verificamos que ninguna subcategoría del catálogo
-- haya quedado fuera de la vista. (Debe devolver cero filas)
SELECT
    c.category_name,
    sc.sub_category_name
FROM sub_categories AS sc

INNER JOIN categories AS c
    ON c.category_id = sc.category_id

LEFT JOIN vw_subcategory_performance AS vsp
    ON vsp.category = c.category_name
   AND vsp.sub_category = sc.sub_category_name

WHERE vsp.sub_category IS NULL;


-- Comprobamos que la agrupación por subcategoría
-- conserve todas las líneas y métricas comerciales.
SELECT
    detalle.total_lineas AS lineas_detalle,
    resumen.total_lineas AS lineas_subcategorias,
    resumen.total_lineas - detalle.total_lineas
        AS diferencia_lineas,

    detalle.total_ventas AS ventas_detalle,
    resumen.total_ventas AS ventas_subcategorias,
    resumen.total_ventas - detalle.total_ventas
        AS diferencia_ventas,

    detalle.total_cantidad AS cantidad_detalle,
    resumen.total_cantidad AS cantidad_subcategorias,
    resumen.total_cantidad - detalle.total_cantidad
        AS diferencia_cantidad,

    detalle.total_beneficio AS beneficio_detalle,
    resumen.total_beneficio AS beneficio_subcategorias,
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
    FROM vw_subcategory_performance
) AS resumen;

-- Mostramos una parte de la vista
SELECT
    category,
    sub_category,
    total_orders,
    distinct_products,
    total_sales,
    total_quantity,
    total_profit,
    comparable_profit_margin_percentage,
    loss_making_lines,
    unknown_sales_lines,
    unknown_profit_lines
FROM vw_subcategory_performance
ORDER BY
    total_sales DESC,
    sub_category;