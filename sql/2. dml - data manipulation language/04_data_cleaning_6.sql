/*
Archivo: 04_data_cleaning_6
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Limpieza y estandarización de los datos almacenados
             en la tabla stg_sales.
             Validación en la consistencia de los productos, 
             solución a los ids asociados a diferentes productos,
             solución de varios customer_id asignados a la misma persona. 

*/

USE superstore_analytics;

-- Comprobamos si un mismo product_id está asociado con más de un nombre de producto.
SELECT
    COUNT(*) AS productos_con_nombres_inconsistentes
FROM
(
    SELECT
        product_id
    FROM stg_sales
    WHERE product_id IS NOT NULL
    GROUP BY product_id
    HAVING COUNT(DISTINCT product_name) > 1
) AS productos_inconsistentes;

-- En este caso, hay 32 productos que tienen nombres inconsistentes. 

-- Comprobamos si un mismo product_id está asociado con más de una categoría.
SELECT
    COUNT(*) AS productos_con_categorias_inconsistentes
FROM
(
    SELECT
        product_id
    FROM stg_sales
    WHERE product_id IS NOT NULL
    GROUP BY product_id
    HAVING COUNT(DISTINCT category) > 1
) AS productos_inconsistentes;

-- En este caso, no hay productos inconsistentes. 

-- Comprobamos si un mismo product_id está asociado con más de una subcategoría.
SELECT
    COUNT(*) AS productos_con_subcategorias_inconsistentes
FROM
(
    SELECT
        product_id
    FROM stg_sales
    WHERE product_id IS NOT NULL
    GROUP BY product_id
    HAVING COUNT(DISTINCT sub_category) > 1
) AS productos_inconsistentes;

-- Tampoco hay productos inconsistentes en esta parte. 

-- Mostramos productos asociados con diferentes nombres.
SELECT
    product_id,
    GROUP_CONCAT(
        DISTINCT product_name
        ORDER BY product_name
        SEPARATOR ' | | '
    ) AS nombres_encontrados,
    COUNT(DISTINCT product_name) AS total_nombres
FROM stg_sales
WHERE product_id IS NOT NULL
GROUP BY product_id
HAVING COUNT(DISTINCT product_name) > 1
ORDER BY product_id DESC;


-- Mostramos cada nombre asociado con los Product ID que presentan más de un nombre de producto.
-- También incluimos la frecuencia y el intervalo temporal para determinar si se trata de 
-- variaciones de escritura o de productos realmente diferentes.
SELECT
    s.product_id,
    s.category,
    s.sub_category,
    s.product_name,
    COUNT(*) AS total_registros,
    MIN(s.order_date) AS primera_aparicion,
    MAX(s.order_date) AS ultima_aparicion
FROM stg_sales AS s
INNER JOIN
(
    SELECT
        product_id
    FROM stg_sales
    WHERE product_id IS NOT NULL
    GROUP BY product_id
    HAVING COUNT(DISTINCT product_name) > 1
) AS inconsistentes
    ON s.product_id = inconsistentes.product_id
GROUP BY
    s.product_id,
    s.category,
    s.sub_category,
    s.product_name
ORDER BY
    s.product_id,
    total_registros DESC,
    s.product_name;

-- Aquí hay un problema y es que existen productos diferentes que comparten el mismo id. 


-- Para solucionarlo vamos a cambiarle el id a los productos que menos se venden. 
DROP TEMPORARY TABLE IF EXISTS mapeo_split;

-- Creamos una tabla temporal en la que le asignaremos un número a cada producto con el mismo id
-- acorde a la frecuencia de cada producto.
-- Este número lo identificará para renombrar el id, siendo el producto que tenga más frecuencia
-- el que conserve el id original. 
CREATE TEMPORARY TABLE mapeo_split AS
WITH conteos AS (
    SELECT
        product_id,
        product_name,
        category,
        sub_category,
        COUNT(*) AS total,
        ROW_NUMBER() OVER (
            PARTITION BY product_id
            ORDER BY COUNT(*) DESC, product_name ASC
        ) AS rn
    FROM stg_sales
    WHERE product_id IN (
        SELECT product_id
        FROM stg_sales
        WHERE product_id IS NOT NULL
        GROUP BY product_id
        HAVING COUNT(DISTINCT product_name) > 1
    )
    GROUP BY product_id, product_name, category, sub_category
)
SELECT
    product_name,
    category,
    sub_category,
    total,
    rn,
    product_id AS old_product_id,
    CASE
        WHEN rn = 1 THEN product_id
        ELSE CONCAT(product_id, '-', LPAD(rn - 1, 1, '0'))
    END AS new_product_id
FROM conteos;

-- Revisamos la tabla temporal
SELECT * FROM mapeo_split
ORDER BY old_product_id, rn;

-- Aquí posiblemente se debería de crear una copia de la columna original para no perder los datos
-- en caso de que haya problemas al momento de actualizarlos. 

-- Actualizamos stg_sales con los nuevos nombres de product_id
UPDATE stg_sales s
INNER JOIN mapeo_split m
    ON s.product_id_original = m.old_product_id
   AND (s.product_name  <=> m.product_name)
   AND (s.category      <=> m.category)
   AND (s.sub_category  <=> m.sub_category)
SET s.product_id = m.new_product_id;

-- Revisamos que no hayan productos compartiendo el mismo ID
SELECT
    s.product_id,
    s.category,
    s.sub_category,
    s.product_name,
    COUNT(*) AS total_registros,
    MIN(s.order_date) AS primera_aparicion,
    MAX(s.order_date) AS ultima_aparicion
FROM stg_sales AS s
INNER JOIN
(
    SELECT
        product_id
    FROM stg_sales
    WHERE product_id IS NOT NULL
    GROUP BY product_id
    HAVING COUNT(DISTINCT product_name) > 1
) AS inconsistentes
    ON s.product_id = inconsistentes.product_id
GROUP BY
    s.product_id,
    s.category,
    s.sub_category,
    s.product_name
ORDER BY
    s.product_id,
    total_registros DESC,
    s.product_name;
-- Quedó solucionado el problema.


-- Ahora, vamos a validar la consistencia de los pedidos.
-- Para ello, calculamos cuántos valores diferentes aparecen dentro de cada pedido 
-- para los atributos que deberían ser únicos.
WITH consistencia_pedidos AS
(
    SELECT
        order_id,
        COUNT(DISTINCT order_date)      AS total_order_dates,
        COUNT(DISTINCT ship_date)       AS total_ship_dates,
        COUNT(DISTINCT ship_mode)       AS total_ship_modes,
        COUNT(DISTINCT customer_id)     AS total_customer_ids,
        COUNT(DISTINCT customer_name)   AS total_customer_names,
        COUNT(DISTINCT segment)         AS total_segments,
        COUNT(DISTINCT country)         AS total_countries,
        COUNT(DISTINCT city)            AS total_cities,
        COUNT(DISTINCT state)           AS total_states,
        COUNT(DISTINCT postal_code)     AS total_postal_codes,
        COUNT(DISTINCT region)          AS total_regions
    FROM stg_sales
    WHERE order_id IS NOT NULL
    GROUP BY order_id
)

SELECT
    SUM(total_order_dates > 1)      AS pedidos_con_order_date_inconsistente,
    SUM(total_ship_dates > 1)       AS pedidos_con_ship_date_inconsistente,
    SUM(total_ship_modes > 1)       AS pedidos_con_ship_mode_inconsistente,
    SUM(total_customer_ids > 1)     AS pedidos_con_customer_id_inconsistente,
    SUM(total_customer_names > 1)   AS pedidos_con_customer_name_inconsistente,
    SUM(total_segments > 1)         AS pedidos_con_segment_inconsistente,
    SUM(total_countries > 1)        AS pedidos_con_country_inconsistente,
    SUM(total_cities > 1)           AS pedidos_con_city_inconsistente,
    SUM(total_states > 1)           AS pedidos_con_state_inconsistente,
    SUM(total_postal_codes > 1)     AS pedidos_con_postal_code_inconsistente,
    SUM(total_regions > 1)          AS pedidos_con_region_inconsistente
FROM consistencia_pedidos;

-- Tenemos que:
-- Hay 2  pedidos con customer_id inconsistente,
-- 2 pedidos con city inconsistente
-- y 2 con postal code inconsistente. 


-- Mostramos los pedidos con alguna inconsistencia.
WITH consistencia_pedidos AS
(
    SELECT
        order_id,
        COUNT(DISTINCT order_date)      AS total_order_dates,
        COUNT(DISTINCT ship_date)       AS total_ship_dates,
        COUNT(DISTINCT ship_mode)       AS total_ship_modes,
        COUNT(DISTINCT customer_id)     AS total_customer_ids,
        COUNT(DISTINCT customer_name)   AS total_customer_names,
        COUNT(DISTINCT segment)         AS total_segments,
        COUNT(DISTINCT country)         AS total_countries,
        COUNT(DISTINCT city)            AS total_cities,
        COUNT(DISTINCT state)           AS total_states,
        COUNT(DISTINCT postal_code)     AS total_postal_codes,
        COUNT(DISTINCT region)          AS total_regions
    FROM stg_sales
    WHERE order_id IS NOT NULL
    GROUP BY order_id
)
SELECT *
FROM consistencia_pedidos
WHERE total_order_dates > 1
   OR total_ship_dates > 1
   OR total_ship_modes > 1
   OR total_customer_ids > 1
   OR total_customer_names > 1
   OR total_segments > 1
   OR total_countries > 1
   OR total_cities > 1
   OR total_states > 1
   OR total_postal_codes > 1
   OR total_regions > 1
ORDER BY order_id;

-- Prácticamente son los que tienen el order_id:
-- CA-2023-131807
-- CA-2025-121465
-- CA-2026-130494
-- CA-2026-131807


-- Ahora veamos los clientes y las ubicaciones asociados con cada order_id que presenta alguna inconsistencia.
WITH pedidos_inconsistentes AS
(
    SELECT
        order_id
    FROM stg_sales
    WHERE order_id IS NOT NULL
    GROUP BY order_id
    HAVING COUNT(DISTINCT customer_id) > 1
        OR COUNT(DISTINCT city) > 1
        OR COUNT(DISTINCT postal_code) > 1
)

SELECT
    s.order_id,

    GROUP_CONCAT(
        DISTINCT s.customer_id
        ORDER BY s.customer_id
        SEPARATOR ' | '
    ) AS customer_ids,

    GROUP_CONCAT(
        DISTINCT s.customer_name
        ORDER BY s.customer_name
        SEPARATOR ' | '
    ) AS customer_names,

    GROUP_CONCAT(
        DISTINCT s.city
        ORDER BY s.city
        SEPARATOR ' | '
    ) AS cities,

    GROUP_CONCAT(
        DISTINCT s.state
        ORDER BY s.state
        SEPARATOR ' | '
    ) AS states,

    GROUP_CONCAT(
        DISTINCT s.postal_code
        ORDER BY s.postal_code
        SEPARATOR ' | '
    ) AS postal_codes,

    COUNT(*) AS total_lineas

FROM stg_sales AS s
INNER JOIN pedidos_inconsistentes AS p
    ON s.order_id = p.order_id

GROUP BY s.order_id
ORDER BY s.order_id;

-- Tenemos que:
-- CA-2023-131807 tiene dos ciudades: Calgary y Edmonton. Y dos postal_code: T1Y y T5A
-- CA-2025-121465 tiene cuatro customer_id: HO-15231 | HO-15232 | HO-15233 | HO-15234
-- CA-2026-130494 tiene cuatro customer_id: HO-15231 | HO-15232 | HO-15233 | HO-15234
-- CA-2026-131807 tiene dos ciudades: Calgary y Edmonton. Y dos postal_code: T1Y y T5A

-- Mostramos las líneas completas de los pedidos problemáticos
-- para determinar si el order_id representa varios pedidos distintos.
WITH pedidos_inconsistentes AS
(
    SELECT
        order_id
    FROM stg_sales
    WHERE order_id IS NOT NULL
    GROUP BY order_id
    HAVING COUNT(DISTINCT customer_id) > 1
        OR COUNT(DISTINCT city) > 1
        OR COUNT(DISTINCT postal_code) > 1
)

SELECT
    s.row_id,
    s.order_id,
    s.order_date,
    s.ship_date,
    s.ship_mode,
    s.customer_id,
    s.customer_name,
    s.segment,
    s.city,
    s.state,
    s.postal_code,
    s.product_id,
    s.product_name,
    s.sales,
    s.quantity

FROM stg_sales AS s
INNER JOIN pedidos_inconsistentes AS p
    ON s.order_id = p.order_id

ORDER BY
    s.order_id,
    s.customer_id,
    s.city,
    s.row_id;

-- ahí podemos revisar la frecuencia de los datos. Esto nos servirá para determinar el error
-- y, en dado caso, corregirlo. 


-- Fijemonos en los nombres asociados con varios customer_id.
-- Anteriormente comprobamos que cada customer_id pertenece a un único nombre. 
-- Ahora veamos si un mismo nombre aparece asociado con varios identificadores.
SELECT
    COUNT(*) AS nombres_con_multiples_customer_id
FROM
(
    SELECT
        customer_name
    FROM stg_sales
    WHERE customer_name IS NOT NULL
      AND customer_id IS NOT NULL
    GROUP BY customer_name
    HAVING COUNT(DISTINCT customer_id) > 1
) AS clientes;

-- Solo hay un nombre con multiples customer_id, que también es el que detectamos antes. 
-- Podemos ver el nombre problematico y sus ids asociados. 
SELECT
    customer_name,

    GROUP_CONCAT(
        DISTINCT customer_id
        ORDER BY customer_id
        SEPARATOR ' | '
    ) AS customer_ids,

    COUNT(DISTINCT customer_id) AS total_customer_ids,

    COUNT(*) AS total_registros

FROM stg_sales
WHERE customer_name IS NOT NULL
  AND customer_id IS NOT NULL

GROUP BY customer_name
HAVING COUNT(DISTINCT customer_id) > 1

ORDER BY
    total_customer_ids DESC,
    customer_name;


-- Para identificar el id principal debemos ver la frecuencia de cada customer_id.
SELECT
    customer_id,
    customer_name,
    city,
    state,
    postal_code,
    COUNT(*) AS total_registros,
    COUNT(DISTINCT order_id) AS total_pedidos,
    MIN(order_date) AS primera_aparicion,
    MAX(order_date) AS ultima_aparicion
FROM stg_sales
WHERE customer_name = 'Harry Olson'
GROUP BY
    customer_id,
    customer_name,
    city,
    state,
    postal_code
ORDER BY
    total_registros DESC,
    primera_aparicion,
    customer_id;

-- Podemos notra que cada customer_id tiene dos registros cada uno.
-- Sin embargo, el primero que se registró fue: HO-15230 el 30 de diciembre del 2023.
-- Por lo que ese es el id canónico. 

-- Antes de actualizarlo, comprobemos si alguno de los identificadores asociados
-- con Harry Olson pertenece también a otro cliente.
SELECT
    customer_id,
    GROUP_CONCAT(
        DISTINCT customer_name
        ORDER BY customer_name
        SEPARATOR ' | '
    ) AS nombres_asociados,
    COUNT(DISTINCT customer_name) AS total_nombres,
    COUNT(*) AS total_registros
FROM stg_sales
WHERE customer_id IN (
    'HO-15230',
    'HO-15231',
    'HO-15232',
    'HO-15233',
    'HO-15234'
)
GROUP BY customer_id
ORDER BY customer_id;
-- No, todos les pertenecen a Harry Olson


-- Ahora, con esto, podemos unificar el customer_id de Harry Olson
-- De esa forma, los identificadores HO-15231, HO-15232, HO-15233 y HO-15234 desaparecen
-- y solo se conserva HO-15230 como identificador canónico porque es
-- el código con la primera aparición histórica en el dataset.

SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

UPDATE stg_sales
SET customer_id = 'HO-15230'
WHERE customer_name = 'Harry Olson'
  AND customer_id IN (
      'HO-15231',
      'HO-15232',
      'HO-15233',
      'HO-15234'
  );

COMMIT;
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;


-- Verificamos que Harry Olson tenga un único identificador.
SELECT
    customer_name,
    GROUP_CONCAT(
        DISTINCT customer_id
        ORDER BY customer_id
        SEPARATOR ' | '
    ) AS customer_ids,
    COUNT(DISTINCT customer_id) AS total_customer_ids,
    COUNT(*) AS total_registros
FROM stg_sales
WHERE customer_name = 'Harry Olson'
GROUP BY customer_name;
-- Quedó perfecta la actualización. 

-- Verificamos que ningún nombre esté asociado con varios Customer ID.
SELECT
    COUNT(*) AS nombres_con_multiples_customer_id
FROM
(
    SELECT
        customer_name
    FROM stg_sales
    WHERE customer_name IS NOT NULL
      AND customer_id IS NOT NULL
    GROUP BY customer_name
    HAVING COUNT(DISTINCT customer_id) > 1
) AS clientes;
-- Ninguna de ellas. 


-- Verificamos que los identificadores principales no contengan
-- valores NULL después del proceso de limpieza.
SELECT
    SUM(row_id IS NULL)      AS row_id_null,
    SUM(order_id IS NULL)    AS order_id_null,
    SUM(customer_id IS NULL) AS customer_id_null,
    SUM(product_id IS NULL)  AS product_id_null
FROM stg_sales;

-- Comprobamos si algún row_id aparece en más de un registro.
SELECT
    COUNT(*) AS row_id_duplicados
FROM
(
    SELECT
        row_id
    FROM stg_sales
    WHERE row_id IS NOT NULL
    GROUP BY row_id
    HAVING COUNT(*) > 1
) AS duplicados;

-- Comparamos el total de registros con la cantidad de Row ID únicos.
SELECT
    COUNT(*) AS total_registros,
    COUNT(DISTINCT row_id) AS row_id_unicos
FROM stg_sales;


-- Bien. Ahora, recordando lo que todavía no hemos resuelto. Había dos registros con diferentes postal_code
-- y diferentes city, pero con el mismo order_id.
-- Para ello, veamos los registros asociados a este problema. 
SELECT
    order_id,
    customer_name,

    GROUP_CONCAT(
        DISTINCT postal_code
        ORDER BY postal_code
        SEPARATOR ' | '
    ) AS customer_postal_code,

    GROUP_CONCAT(
        DISTINCT city
        ORDER BY city
        SEPARATOR ' | '
    ) AS customer_city,

    COUNT(DISTINCT postal_code) AS total_postal_code,
    COUNT(DISTINCT city) AS total_city,

    COUNT(*) AS total_registros

FROM stg_sales
WHERE order_id IS NOT NULL
GROUP BY order_id, customer_name
HAVING COUNT(DISTINCT customer_id) > 1
        OR COUNT(DISTINCT city) > 1
        OR COUNT(DISTINCT postal_code) > 1
ORDER BY
    total_postal_code DESC,
    total_city,
    order_id;
 
-- Tenemos a Greg Guthrie con dos order_id que tienen, cada uno, dos ciudades y dos códigos postales.
-- Muy probablemente, lo que pasó es que alguno de los registrosse confundió por el otro. 
-- Para identificar el problema principal, vamos a desglosar los datos asociados a las ciudades y códigos postales.
SELECT
    order_id,
    customer_id,
    customer_name,
    city,
    state,
    postal_code,
    COUNT(*) AS total_registros,
    COUNT(DISTINCT order_id) AS total_pedidos,
    MIN(order_date) AS primera_aparicion,
    MAX(order_date) AS ultima_aparicion
FROM stg_sales
WHERE customer_name = 'Greg Guthrie' 
     AND city = 'Calgary'
     Or city = 'Edmonton'
GROUP BY
    order_id,
    customer_id,
    customer_name,
    city,
    state,
    postal_code
ORDER BY
    order_id DESC,
    total_registros;

-- Aquí tenemos un problema que no sé solucionar a principio. 
-- Tenemos dos order_id que apuntan hacia diferentes ciudades y códigos postales dentro de un mismo estado.
-- Esto puede ser un error o no puede serlo. 
-- Creo que se necesitarían más datos para confirmar lo uno o lo otro. 
