/*
Archivo      : 06_load_relational_model.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Carga de los datos limpios en las tablas
               que conforman el modelo relacional.
*/

-- Seleccionamos la base de datos.
USE superstore_analytics;

-- Cargamos las tablas de catálogo

-- Tabla: segments
-- Insertamos los segmentos distintos que todavía no existen
-- en la tabla de catálogo.
INSERT INTO segments
(
    segment_name
)
SELECT DISTINCT
    cs.segment
FROM clean_sales AS cs
WHERE cs.segment IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM segments AS s
      WHERE s.segment_name = cs.segment
  )
ORDER BY cs.segment;


-- Tabla: ship_modes
-- Los valores NULL no se incluyen en el catálogo porque
-- representan modos de envío desconocidos.
INSERT INTO ship_modes
(
    ship_mode_name
)
SELECT DISTINCT
    cs.ship_mode
FROM clean_sales AS cs
WHERE cs.ship_mode IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM ship_modes AS sm
      WHERE sm.ship_mode_name = cs.ship_mode
  )
ORDER BY cs.ship_mode;


-- Tabla: regions
INSERT INTO regions
(
    region_name
)
SELECT DISTINCT
    cs.region
FROM clean_sales AS cs
WHERE cs.region IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM regions AS r
      WHERE r.region_name = cs.region
  )
ORDER BY cs.region;


-- Tabla: categories
INSERT INTO categories
(
    category_name
)
SELECT DISTINCT
    cs.category
FROM clean_sales AS cs
WHERE cs.category IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM categories AS c
      WHERE c.category_name = cs.category
  )
ORDER BY cs.category;


-- Verificamos los valores cargados en cada catálogo.

SELECT
    segment_id,
    segment_name
FROM segments
ORDER BY segment_id;

SELECT
    ship_mode_id,
    ship_mode_name
FROM ship_modes
ORDER BY ship_mode_id;

SELECT
    region_id,
    region_name
FROM regions
ORDER BY region_id;

SELECT
    category_id,
    category_name
FROM categories
ORDER BY category_id;

SELECT
    (SELECT COUNT(*) FROM segments) AS total_segments,
    (SELECT COUNT(*) FROM ship_modes) AS total_ship_modes,
    (SELECT COUNT(*) FROM regions) AS total_regions,
    (SELECT COUNT(*) FROM categories) AS total_categories;



-- Cargamos las subcategorías

-- Insertamos cada combinación única de categoría y subcategoría.
-- El JOIN permite sustituir el nombre de la categoría por su
-- identificador interno category_id.

INSERT INTO sub_categories
(
    category_id,
    sub_category_name
)
SELECT DISTINCT
    c.category_id,
    cs.sub_category
FROM clean_sales AS cs
INNER JOIN categories AS c
    ON c.category_name = cs.category
WHERE cs.sub_category IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM sub_categories AS sc
      WHERE sc.category_id = c.category_id
        AND sc.sub_category_name = cs.sub_category
  )
ORDER BY
    c.category_id,
    cs.sub_category;


-- Verificamos las subcategorías y su categoría correspondiente.
SELECT
    sc.sub_category_id,
    c.category_name,
    sc.sub_category_name
FROM sub_categories AS sc
INNER JOIN categories AS c
    ON sc.category_id = c.category_id
ORDER BY
    c.category_name,
    sc.sub_category_name;


-- Confirmamos la cantidad total de subcategorías. (17)
SELECT COUNT(*) AS total_subcategorias
FROM sub_categories;


-- Verificamos que ninguna combinación del conjunto limpio
-- haya quedado sin representación en el modelo relacional. (Debe devolver cero)
SELECT
    cs.category,
    cs.sub_category
FROM clean_sales AS cs
LEFT JOIN categories AS c
    ON c.category_name = cs.category
LEFT JOIN sub_categories AS sc
    ON sc.category_id = c.category_id
   AND sc.sub_category_name = cs.sub_category
WHERE c.category_id IS NULL
   OR sc.sub_category_id IS NULL
GROUP BY
    cs.category,
    cs.sub_category;




-- Cargamos las ubicaciones

-- Insertamos las ubicaciones únicas presentes en clean_sales.
-- El JOIN permite sustituir el nombre de la región por su
-- identificador interno region_id.
INSERT INTO locations
(
    region_id,
    country,
    city,
    state,
    postal_code
)
SELECT DISTINCT
    r.region_id,
    cs.country,
    cs.city,
    cs.state,
    cs.postal_code
FROM clean_sales AS cs
INNER JOIN regions AS r
    ON r.region_name = cs.region
WHERE cs.country IS NOT NULL
  AND cs.city IS NOT NULL
  AND cs.state IS NOT NULL
  AND cs.postal_code IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM locations AS l
      WHERE l.region_id = r.region_id
        AND l.country = cs.country
        AND l.city = cs.city
        AND l.state = cs.state
        AND l.postal_code = cs.postal_code
  )
ORDER BY
    cs.country,
    cs.state,
    cs.city,
    cs.postal_code;


-- Consultamos la cantidad total de ubicaciones únicas.
SELECT COUNT(*) AS total_ubicaciones
FROM locations;

-- Visualizamos una muestra de las ubicaciones junto con
-- el nombre de su región.
SELECT
    l.location_id,
    l.country,
    l.state,
    l.city,
    l.postal_code,
    r.region_name
FROM locations AS l
INNER JOIN regions AS r
    ON l.region_id = r.region_id
ORDER BY
    l.country,
    l.state,
    l.city,
    l.postal_code
LIMIT 20;


-- Verificamos que ninguna ubicación del conjunto limpio
-- haya quedado fuera del modelo relacional. (Debe devolver cero)
SELECT
    cs.country,
    cs.state,
    cs.city,
    cs.postal_code,
    cs.region,
    COUNT(*) AS total_registros
FROM clean_sales AS cs
LEFT JOIN regions AS r
    ON r.region_name = cs.region
LEFT JOIN locations AS l
    ON l.region_id = r.region_id
   AND l.country = cs.country
   AND l.state = cs.state
   AND l.city = cs.city
   AND l.postal_code = cs.postal_code
WHERE r.region_id IS NULL
   OR l.location_id IS NULL
GROUP BY
    cs.country,
    cs.state,
    cs.city,
    cs.postal_code,
    cs.region;



-- Cargamos los clientes

-- Insertamos los clientes únicos presentes en clean_sales.
-- El JOIN sustituye el nombre textual del segmento por su
-- identificador interno segment_id.

INSERT INTO customers
(
    customer_id,
    segment_id,
    customer_name
)
SELECT DISTINCT
    cs.customer_id,
    s.segment_id,
    cs.customer_name
FROM clean_sales AS cs
INNER JOIN segments AS s
    ON s.segment_name = cs.segment
WHERE cs.customer_id IS NOT NULL
  AND cs.customer_name IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM customers AS c
      WHERE c.customer_id = cs.customer_id
  )
ORDER BY cs.customer_id;

-- Consultamos la cantidad total de clientes cargados.
SELECT COUNT(*) AS total_clientes
FROM customers;

-- Visualizamos una muestra de clientes junto con
-- el nombre de su segmento.
SELECT
    c.customer_id,
    c.customer_name,
    s.segment_name
FROM customers AS c
INNER JOIN segments AS s
    ON c.segment_id = s.segment_id
ORDER BY
    c.customer_name,
    c.customer_id
LIMIT 20;


-- Verificamos que todos los clientes de clean_sales
-- tengan correspondencia en la tabla customers. (Debe devolver cero)
SELECT
    cs.customer_id,
    cs.customer_name,
    cs.segment,
    COUNT(*) AS total_registros
FROM clean_sales AS cs
LEFT JOIN customers AS c
    ON c.customer_id = cs.customer_id
LEFT JOIN segments AS s
    ON s.segment_id = c.segment_id
WHERE c.customer_id IS NULL
   OR s.segment_name <> cs.segment
GROUP BY
    cs.customer_id,
    cs.customer_name,
    cs.segment;


-- Comparamos la cantidad de clientes únicos del conjunto limpio
-- con la cantidad cargada en el modelo relacional.
SELECT
    (
        SELECT COUNT(DISTINCT customer_id)
        FROM clean_sales
    ) AS clientes_unicos_clean,

    (
        SELECT COUNT(*)
        FROM customers
    ) AS clientes_modelo,

    (
        SELECT COUNT(DISTINCT customer_id)
        FROM clean_sales
    )
    -
    (
        SELECT COUNT(*)
        FROM customers
    ) AS diferencia;




-- Cargamos los productos

-- Insertamos cada combinación única de identificador original
-- y nombre de producto.

-- Se utilizan categories y sub_categories para recuperar
-- el sub_category_id correspondiente a cada producto.

INSERT INTO products
(
    source_product_id,
    sub_category_id,
    product_name
)
SELECT DISTINCT
    cs.product_id,
    sc.sub_category_id,
    cs.product_name
FROM clean_sales AS cs
INNER JOIN categories AS c
    ON c.category_name = cs.category
INNER JOIN sub_categories AS sc
    ON sc.category_id = c.category_id
   AND sc.sub_category_name = cs.sub_category
WHERE cs.product_id IS NOT NULL
  AND cs.product_name IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM products AS p
      WHERE p.source_product_id = cs.product_id
        AND p.product_name = cs.product_name
  )
ORDER BY
    cs.product_id,
    cs.product_name;


-- Consultamos la cantidad total de productos cargados.
SELECT COUNT(*) AS total_productos
FROM products;

-- Visualizamos una muestra de productos junto con
-- su subcategoría y categoría.
SELECT
    p.product_key,
    p.source_product_id,
    p.product_name,
    sc.sub_category_name,
    c.category_name
FROM products AS p
INNER JOIN sub_categories AS sc
    ON sc.sub_category_id = p.sub_category_id
INNER JOIN categories AS c
    ON c.category_id = sc.category_id
ORDER BY
    p.source_product_id,
    p.product_name
LIMIT 20;

-- Verificamos que todas las combinaciones de código y nombre
-- presentes en clean_sales tengan correspondencia en products. (Debe devolver cero filas)
SELECT
    cs.product_id,
    cs.product_name,
    cs.category,
    cs.sub_category,
    COUNT(*) AS total_registros
FROM clean_sales AS cs
LEFT JOIN products AS p
    ON p.source_product_id = cs.product_id
   AND p.product_name = cs.product_name
LEFT JOIN sub_categories AS sc
    ON sc.sub_category_id = p.sub_category_id
LEFT JOIN categories AS c
    ON c.category_id = sc.category_id
WHERE p.product_key IS NULL
   OR sc.sub_category_name <> cs.sub_category
   OR c.category_name <> cs.category
GROUP BY
    cs.product_id,
    cs.product_name,
    cs.category,
    cs.sub_category;

-- Comparamos los productos únicos del conjunto limpio
-- con los productos cargados en el modelo relacional.
SELECT
    (
        SELECT COUNT(DISTINCT product_id, product_name)
        FROM clean_sales
    ) AS productos_unicos_clean,

    (
        SELECT COUNT(*)
        FROM products
    ) AS productos_modelo,

    (
        SELECT COUNT(DISTINCT product_id, product_name)
        FROM clean_sales
    )
    -
    (
        SELECT COUNT(*)
        FROM products
    ) AS diferencia;



-- Cargamos los pedidos

-- Insertamos cada pedido lógico presente en clean_sales.

-- Un mismo identificador original puede representar más de
-- un pedido cuando aparece asociado con ubicaciones distintas.
-- Por esta razón, la identidad se determina mediante:
-- source_order_id + customer_id + location_id

INSERT INTO orders
(
    source_order_id,
    customer_id,
    location_id,
    ship_mode_id,
    order_date,
    ship_date
)
SELECT DISTINCT
    cs.order_id,
    cs.customer_id,
    l.location_id,
    sm.ship_mode_id,
    cs.order_date,
    cs.ship_date
FROM clean_sales AS cs

INNER JOIN customers AS c
    ON c.customer_id = cs.customer_id

INNER JOIN regions AS r
    ON r.region_name = cs.region

INNER JOIN locations AS l
    ON l.region_id = r.region_id
   AND l.country = cs.country
   AND l.state = cs.state
   AND l.city = cs.city
   AND l.postal_code = cs.postal_code

LEFT JOIN ship_modes AS sm
    ON sm.ship_mode_name = cs.ship_mode

WHERE NOT EXISTS
(
    SELECT 1
    FROM orders AS o
    WHERE o.source_order_id = cs.order_id
      AND o.customer_id = cs.customer_id
      AND o.location_id = l.location_id
)

ORDER BY
    cs.order_id,
    cs.customer_id,
    l.location_id;


-- Consultamos el total de pedidos normalizados.
SELECT COUNT(*) AS total_pedidos
FROM orders;

-- Comparamos la cantidad de pedidos lógicos del conjunto limpio
-- con la cantidad almacenada en el modelo relacional.
SELECT
    (
        SELECT COUNT(*)
        FROM
        (
            SELECT
                cs.order_id,
                cs.customer_id,
                cs.country,
                cs.state,
                cs.city,
                cs.postal_code,
                cs.region
            FROM clean_sales AS cs
            GROUP BY
                cs.order_id,
                cs.customer_id,
                cs.country,
                cs.state,
                cs.city,
                cs.postal_code,
                cs.region
        ) AS pedidos_unicos
    ) AS pedidos_clean,

    (
        SELECT COUNT(*)
        FROM orders
    ) AS pedidos_modelo,

    (
        SELECT COUNT(*)
        FROM
        (
            SELECT
                cs.order_id,
                cs.customer_id,
                cs.country,
                cs.state,
                cs.city,
                cs.postal_code,
                cs.region
            FROM clean_sales AS cs
            GROUP BY
                cs.order_id,
                cs.customer_id,
                cs.country,
                cs.state,
                cs.city,
                cs.postal_code,
                cs.region
        ) AS pedidos_unicos
    )
    -
    (
        SELECT COUNT(*)
        FROM orders
    ) AS diferencia;


-- Visualizamos una muestra con los datos descriptivos
-- provenientes de las tablas relacionadas.
SELECT
    o.order_key,
    o.source_order_id,
    o.order_date,
    o.ship_date,
    c.customer_name,
    l.city,
    l.state,
    sm.ship_mode_name
FROM orders AS o

INNER JOIN customers AS c
    ON c.customer_id = o.customer_id

INNER JOIN locations AS l
    ON l.location_id = o.location_id

LEFT JOIN ship_modes AS sm
    ON sm.ship_mode_id = o.ship_mode_id

ORDER BY
    o.order_date,
    o.source_order_id,
    o.order_key

LIMIT 20;


-- Verificamos que cada fila de clean_sales pueda localizar
-- correctamente su pedido dentro del modelo relacional. (Debe devolver cero filas)
SELECT
    cs.order_id,
    cs.customer_id,
    cs.order_date,
    cs.ship_date,
    cs.country,
    cs.state,
    cs.city,
    cs.postal_code,
    cs.ship_mode,
    COUNT(*) AS total_registros
FROM clean_sales AS cs

LEFT JOIN regions AS r
    ON r.region_name = cs.region

LEFT JOIN locations AS l
    ON l.region_id = r.region_id
   AND l.country = cs.country
   AND l.state = cs.state
   AND l.city = cs.city
   AND l.postal_code = cs.postal_code

LEFT JOIN ship_modes AS sm
    ON sm.ship_mode_name = cs.ship_mode

LEFT JOIN orders AS o
    ON o.source_order_id = cs.order_id
   AND o.customer_id = cs.customer_id
   AND o.location_id = l.location_id
   AND o.order_date = cs.order_date
   AND o.ship_date = cs.ship_date
   AND (o.ship_mode_id <=> sm.ship_mode_id)

WHERE o.order_key IS NULL

GROUP BY
    cs.order_id,
    cs.customer_id,
    cs.order_date,
    cs.ship_date,
    cs.country,
    cs.state,
    cs.city,
    cs.postal_code,
    cs.ship_mode;



-- Cargamos los detalles de pedidos

-- Insertamos cada línea de venta presente en clean_sales.

-- Para localizar el pedido se utilizan su identificador original,
-- cliente, ubicación, fechas y modo de envío.

-- Para localizar el producto se utiliza la combinación:
-- product_id + product_name.

INSERT INTO order_details
(
    source_row_id,
    order_key,
    product_key,
    sales,
    quantity,
    discount,
    profit
)
SELECT
    cs.row_id,
    o.order_key,
    p.product_key,
    cs.sales,
    cs.quantity,
    cs.discount,
    cs.profit
FROM clean_sales AS cs
-- Recuperamos la región y la ubicación normalizada.
INNER JOIN regions AS r
    ON r.region_name = cs.region

INNER JOIN locations AS l
    ON l.region_id = r.region_id
   AND l.country = cs.country
   AND l.state = cs.state
   AND l.city = cs.city
   AND l.postal_code = cs.postal_code
-- El LEFT JOIN conserva los registros cuyo modo
-- de envío continúa siendo desconocido.
LEFT JOIN ship_modes AS sm
    ON sm.ship_mode_name = cs.ship_mode
-- Recuperamos el pedido correspondiente a cada línea.
INNER JOIN orders AS o
    ON o.source_order_id = cs.order_id
   AND o.customer_id = cs.customer_id
   AND o.location_id = l.location_id
   AND o.order_date = cs.order_date
   AND o.ship_date = cs.ship_date
   AND (o.ship_mode_id <=> sm.ship_mode_id)
-- Recuperamos el producto utilizando el código original
-- y el nombre, ya que algunos códigos fueron reutilizados.
INNER JOIN products AS p
    ON p.source_product_id = cs.product_id
   AND p.product_name = cs.product_name
-- Evitamos insertar nuevamente una fila original
-- si el bloque se ejecuta más de una vez.
WHERE NOT EXISTS
(
    SELECT 1
    FROM order_details AS od
    WHERE od.source_row_id = cs.row_id
)

ORDER BY cs.row_id;


-- Verificamos la cantidad total de líneas cargadas.
SELECT COUNT(*) AS total_detalles
FROM order_details;

-- Comparamos la cantidad de filas del conjunto limpio
-- con la cantidad de detalles del modelo relacional.
SELECT
    (SELECT COUNT(*) FROM clean_sales) AS filas_clean,

    (SELECT COUNT(*) FROM order_details) AS filas_modelo,

    (SELECT COUNT(*) FROM clean_sales)
    -
    (SELECT COUNT(*) FROM order_details) AS diferencia;


-- Comprobamos que cada row_id original aparezca una sola vez.
SELECT
    COUNT(*) AS total_registros,
    COUNT(DISTINCT source_row_id) AS row_id_unicos,
    COUNT(*) - COUNT(DISTINCT source_row_id) AS duplicados
FROM order_details;

-- Verificamos que cada fila del conjunto limpio tenga
-- correspondencia en la tabla de detalles. (Debe devolver cero)
SELECT
    cs.row_id,
    cs.order_id,
    cs.product_id,
    cs.product_name
FROM clean_sales AS cs

LEFT JOIN order_details AS od
    ON od.source_row_id = cs.row_id

WHERE od.order_detail_key IS NULL

ORDER BY cs.row_id;



-- Comparamos los totales del conjunto limpio con los
-- almacenados en el modelo relacional.
SELECT
    clean.total_ventas AS ventas_clean,
    modelo.total_ventas AS ventas_modelo,
    clean.total_ventas - modelo.total_ventas AS diferencia_ventas,

    clean.total_cantidad AS cantidad_clean,
    modelo.total_cantidad AS cantidad_modelo,
    clean.total_cantidad - modelo.total_cantidad AS diferencia_cantidad,

    clean.total_descuento AS descuento_clean,
    modelo.total_descuento AS descuento_modelo,
    clean.total_descuento - modelo.total_descuento
        AS diferencia_descuento,

    clean.total_beneficio AS beneficio_clean,
    modelo.total_beneficio AS beneficio_modelo,
    clean.total_beneficio - modelo.total_beneficio
        AS diferencia_beneficio
FROM
(
    SELECT
        SUM(sales) AS total_ventas,
        SUM(quantity) AS total_cantidad,
        SUM(discount) AS total_descuento,
        SUM(profit) AS total_beneficio
    FROM clean_sales
) AS clean
CROSS JOIN
(
    SELECT
        SUM(sales) AS total_ventas,
        SUM(quantity) AS total_cantidad,
        SUM(discount) AS total_descuento,
        SUM(profit) AS total_beneficio
    FROM order_details
) AS modelo;

