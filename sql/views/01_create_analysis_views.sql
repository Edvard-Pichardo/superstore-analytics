/*
Archivo      : 01_create_analysis_views.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Creación de vistas destinadas al análisis
               comercial del modelo relacional.
*/

USE superstore_analytics;

-- Vista detallada de ventas

-- Vista: vw_sales_detail
-- Integra las principales tablas del modelo relacional.

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




-- Vista resumida por pedido

-- Vista: vw_order_summary
-- Resume las líneas de venta de cada pedido.

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



-- Vista de desempeño mensual

-- Vista: vw_monthly_performance
-- Resume los pedidos y métricas comerciales por año y mes.

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




-- Vista de desempeño por subcategoría

-- Vista: vw_subcategory_performance
-- Resume el desempeño comercial de cada subcategoría.

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



-- Vista de desempeño por cliente

-- Vista: vw_customer_performance
-- Resume la actividad comercial de cada cliente.

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




-- Vista de desempeño geográfico

-- Vista: vw_geographic_performance
-- Resume el desempeño comercial de cada ciudad.

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




-- Vista de desempeño por producto

-- Vista: vw_product_performance
-- Resume el desempeño comercial de cada producto.

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





-- Vista de desempeño por segmento

-- Vista: vw_segment_performance
-- Resume la actividad comercial de cada segmento.

-- Cada fila representa un segmento e incluye pedidos,
-- clientes, ventas, rentabilidad, logística y cobertura
-- de información.

CREATE OR REPLACE VIEW vw_segment_performance AS
SELECT
    -- Identificación del segmento.
    vos.segment,
    -- Periodo de actividad.
    MIN(vos.order_date) AS first_order_date,
    MAX(vos.order_date) AS last_order_date,
    -- Actividad comercial.
    COUNT(*) AS total_orders,
    COUNT(DISTINCT vos.customer_id) AS distinct_customers,
    SUM(vos.total_order_lines) AS total_order_lines,
    SUM(vos.distinct_products) AS total_product_references,
    -- Métricas comerciales conocidas.
    SUM(vos.total_sales) AS total_sales,
    SUM(vos.total_quantity) AS total_quantity,
    SUM(vos.total_profit) AS total_profit,
    -- Valor promedio calculado únicamente con pedidos
    -- cuyas ventas se encuentran completamente disponibles.
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
    -- Margen calculado únicamente con pedidos que tienen
    -- ventas y beneficios completamente disponibles.
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
    MIN(vos.shipping_days) AS minimum_shipping_days,
    MAX(vos.shipping_days) AS maximum_shipping_days,
    -- Cobertura de información.
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

FROM vw_order_summary AS vos

GROUP BY vos.segment;


-- Comparamos los segmentos del catálogo con las filas
-- generadas en la vista.
SELECT
    (SELECT COUNT(*) FROM segments)
        AS segmentos_modelo,

    (SELECT COUNT(*) FROM vw_segment_performance)
        AS segmentos_vista,

    (SELECT COUNT(*) FROM vw_segment_performance)
    -
    (SELECT COUNT(*) FROM segments)
        AS diferencia;


-- Verificamos que ningún segmento del catálogo haya
-- quedado fuera de la vista analítica.
SELECT
    s.segment_id,
    s.segment_name
FROM segments AS s

LEFT JOIN vw_segment_performance AS vsp
    ON vsp.segment = s.segment_name

WHERE vsp.segment IS NULL;



-- Comprobamos que la agrupación por segmento conserve
-- todos los pedidos y líneas del modelo.
SELECT
    resumen.total_pedidos AS pedidos_resumen,
    segmentos.total_pedidos AS pedidos_segmentos,

    segmentos.total_pedidos
    -
    resumen.total_pedidos AS diferencia_pedidos,

    resumen.total_lineas AS lineas_resumen,
    segmentos.total_lineas AS lineas_segmentos,

    segmentos.total_lineas
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
    FROM vw_segment_performance
) AS segmentos;



-- Verificamos que los totales comerciales acumulados
-- por segmento coincidan con la vista por pedido.
SELECT
    resumen.total_ventas AS ventas_resumen,
    segmentos.total_ventas AS ventas_segmentos,

    segmentos.total_ventas
    -
    resumen.total_ventas AS diferencia_ventas,

    resumen.total_cantidad AS cantidad_resumen,
    segmentos.total_cantidad AS cantidad_segmentos,

    segmentos.total_cantidad
    -
    resumen.total_cantidad AS diferencia_cantidad,

    resumen.total_beneficio AS beneficio_resumen,
    segmentos.total_beneficio AS beneficio_segmentos,

    segmentos.total_beneficio
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
    FROM vw_segment_performance
) AS segmentos;


-- Consultamos los resultados
SELECT
    segment,
    distinct_customers,
    total_orders,
    total_order_lines,
    total_sales,
    total_quantity,
    total_profit,
    average_complete_order_value,
    average_complete_order_profit,
    comparable_profit_margin_percentage,
    average_shipping_days,
    complete_loss_making_orders,
    orders_with_unknown_sales,
    orders_with_unknown_profit
FROM vw_segment_performance
ORDER BY total_sales DESC;


-- =====================================================
-- BLOQUE 9
-- Vista de desempeño por modo de envío
-- =====================================================

-- -----------------------------------------------------
-- Vista: vw_ship_mode_performance
-- -----------------------------------------------------

-- Resume el desempeño comercial y logístico de cada
-- modalidad de envío.
--
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


