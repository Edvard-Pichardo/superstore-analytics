/*
Archivo      : 04_data_cleaning.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Limpieza y estandarización de los datos almacenados
               en la tabla stg_sales.
*/

-- Seleccionamos la base de datos.
USE superstore_analytics;

-- Diagnóstico de registros duplicados

-- Agrupamos los registros idénticos para conocer:
-- 1. Cuántos grupos duplicados existen.
-- 2. Cuántas filas participan en esos grupos.
-- 3. Cuántas filas excedentes deberían eliminarse.

WITH grupos_duplicados AS
(
    SELECT
        row_id,
        order_id,
        order_date,
        ship_date,
        ship_mode,
        customer_id,
        customer_name,
        segment,
        country,
        city,
        state,
        postal_code,
        region,
        product_id,
        category,
        sub_category,
        product_name,
        sales,
        quantity,
        discount,
        profit,
        COUNT(*) AS repeticiones
    FROM stg_sales
    GROUP BY
        row_id,
        order_id,
        order_date,
        ship_date,
        ship_mode,
        customer_id,
        customer_name,
        segment,
        country,
        city,
        state,
        postal_code,
        region,
        product_id,
        category,
        sub_category,
        product_name,
        sales,
        quantity,
        discount,
        profit
    HAVING COUNT(*) > 1
)

SELECT
    COUNT(*) AS grupos_duplicados,
    SUM(repeticiones) AS filas_involucradas,
    SUM(repeticiones - 1) AS filas_excedentes
FROM grupos_duplicados;


-- Eliminamos los registros duplicados (deberían ser 509 registros duplicados)
-- Desactivamos temporalmente el modo de actualizaciones seguras,
-- ya que eliminaremos y recargaremos todos los registros de staging.
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

-- Eliminamos la tabla temporal si quedó creada en una ejecución anterior.
DROP TEMPORARY TABLE IF EXISTS tmp_stg_sales;

-- Creamos una tabla temporal con la misma estructura de stg_sales.
CREATE TEMPORARY TABLE tmp_stg_sales
LIKE stg_sales;

-- DISTINCT conserva una sola copia de cada fila idéntica.
INSERT INTO tmp_stg_sales
SELECT DISTINCT *
FROM stg_sales;

-- Vaciamos la tabla de staging.
DELETE FROM stg_sales;

-- Regresamos únicamente los registros únicos.
INSERT INTO stg_sales
SELECT *
FROM tmp_stg_sales;

DROP TEMPORARY TABLE tmp_stg_sales;
COMMIT;

-- Restauramos la configuración original.
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;

-- Verificamos el total de registros después de la eliminación (10703 - 509 = 10194 registros).
SELECT COUNT(*) AS total_registros_sin_duplicados
FROM stg_sales;
-- También se puede confirmar que no quedaron duplicados volviendo a ejecutar 
-- el diagnóstico del principio



-- Limpieza de espacios y cadenas vacías
-- Guardamos la configuración actual y desactivamos temporalmente
-- el modo de actualizaciones seguras.
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

-- TRIM elimina espacios al inicio y al final.
-- NULLIF convierte las cadenas vacías en valores NULL.
UPDATE stg_sales
SET
    row_id          = NULLIF(TRIM(row_id), ''),
    order_id        = NULLIF(TRIM(order_id), ''),
    order_date      = NULLIF(TRIM(order_date), ''),
    ship_date       = NULLIF(TRIM(ship_date), ''),
    ship_mode       = NULLIF(TRIM(ship_mode), ''),
    customer_id     = NULLIF(TRIM(customer_id), ''),
    customer_name   = NULLIF(TRIM(customer_name), ''),
    segment         = NULLIF(TRIM(segment), ''),
    country         = NULLIF(TRIM(country), ''),
    city            = NULLIF(TRIM(city), ''),
    state           = NULLIF(TRIM(state), ''),
    postal_code     = NULLIF(TRIM(postal_code), ''),
    region          = NULLIF(TRIM(region), ''),
    product_id      = NULLIF(TRIM(product_id), ''),
    category        = NULLIF(TRIM(category), ''),
    sub_category    = NULLIF(TRIM(sub_category), ''),
    product_name    = NULLIF(TRIM(product_name), ''),
    sales           = NULLIF(TRIM(sales), ''),
    quantity        = NULLIF(TRIM(quantity), ''),
    discount        = NULLIF(TRIM(discount), ''),
    profit          = NULLIF(TRIM(profit), '');

COMMIT;

-- Restauramos la configuración original.
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;


-- Verificamos que ya no existan cadenas vacías.
SELECT
    SUM(TRIM(COALESCE(ship_mode, '')) = '') AS ship_mode_vacios,
    SUM(TRIM(COALESCE(sales, '')) = '')     AS sales_vacios,
    SUM(TRIM(COALESCE(quantity, '')) = '')  AS quantity_vacios,
    SUM(TRIM(COALESCE(profit, '')) = '')    AS profit_vacios
FROM stg_sales;

-- Aquí esos valores seguirán apareciendo contabilizados porque COALESCE(NULL, '') 
-- convierte temporalmente los NULL en cadenas vacías para la comprobación.
-- Checamos si todos son null, deberían aparecer los mismos valores que en la consulta anterior.
SELECT
    SUM(ship_mode IS NULL) AS ship_mode_null,
    SUM(sales IS NULL)     AS sales_null,
    SUM(quantity IS NULL)  AS quantity_null,
    SUM(profit IS NULL)    AS profit_null
FROM stg_sales;

-- Comprobamos que la columna Category esté corregida sin espacios extra
SELECT
    category,
    COUNT(*) AS total
FROM stg_sales
GROUP BY category
ORDER BY total DESC;


-- Estándarizamos la columna Segment con vista previa
SELECT DISTINCT
    segment AS segment_original,
    CASE
        WHEN LOWER(segment) IN (
            'consumer',
            'counsumer',
            'consumr'
        )
            THEN 'Consumer'

        WHEN LOWER(segment) IN (
            'corporate',
            'corp.',
            'corperate'
        )
            THEN 'Corporate'

        WHEN LOWER(segment) IN (
            'home office',
            'home-office',
            'homeoffice'
        )
            THEN 'Home Office'

        ELSE segment
    END AS segment_limpio
FROM stg_sales
ORDER BY segment_original;

-- Aplicamos la estandarización de Segment
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

UPDATE stg_sales
SET segment =
    CASE
        WHEN LOWER(segment) IN (
            'consumer',
            'counsumer',
            'consumr'
        )
            THEN 'Consumer'

        WHEN LOWER(segment) IN (
            'corporate',
            'corp.',
            'corperate'
        )
            THEN 'Corporate'

        WHEN LOWER(segment) IN (
            'home office',
            'home-office',
            'homeoffice'
        )
            THEN 'Home Office'

        ELSE segment
    END
WHERE segment IS NOT NULL;
COMMIT;
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;


-- Verificamos que únicamente existan los tres segmentos válidos.
SELECT
    segment,
    COUNT(*) AS total
FROM stg_sales
GROUP BY segment
ORDER BY total DESC;

-- Comprobamos que no quedó ninguna variante inesperada de los tres segmentos
SELECT COUNT(*) AS segmentos_no_validos
FROM stg_sales
WHERE segment NOT IN (
    'Consumer',
    'Corporate',
    'Home Office'
)
   OR segment IS NULL;




-- Normalización de Order Date

-- Configuramos los nombres de los meses en inglés para interpretar
-- correctamente fechas como 04-Jan-2023.
SET lc_time_names = 'en_US';

SELECT
    order_date AS fecha_original,
    CASE
        -- Formato ya normalizado: 2023-01-04
        WHEN order_date REGEXP
            '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN order_date
        -- Formato: 2023-01-04 00:00:00
        WHEN order_date REGEXP
            '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
            THEN DATE_FORMAT(
                STR_TO_DATE(order_date, '%Y-%m-%d %H:%i:%s'),
                '%Y-%m-%d'
            )
        -- Formato: 04-Jan-2023
        WHEN order_date REGEXP
            '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
            THEN DATE_FORMAT(
                STR_TO_DATE(order_date, '%d-%b-%Y'),
                '%Y-%m-%d'
            )
        -- Formato: 03.01.2023
        WHEN order_date REGEXP
            '^[0-9]{2}[.][0-9]{2}[.][0-9]{4}$'
            THEN DATE_FORMAT(
                STR_TO_DATE(order_date, '%d.%m.%Y'),
                '%Y-%m-%d'
            )
        -- Formato: 20230106
        WHEN order_date REGEXP
            '^[0-9]{8}$'
            THEN DATE_FORMAT(
                STR_TO_DATE(order_date, '%Y%m%d'),
                '%Y-%m-%d'
            )
        -- Conservamos los valores no reconocidos para investigarlos.
        ELSE order_date
    END AS fecha_normalizada
FROM stg_sales
ORDER BY order_date
LIMIT 100;


-- Aplicación de la normalización de Order Date
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;
UPDATE stg_sales
SET order_date =
    CASE
        WHEN order_date REGEXP
            '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN order_date

        WHEN order_date REGEXP
            '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
            THEN DATE_FORMAT(
                STR_TO_DATE(order_date, '%Y-%m-%d %H:%i:%s'),
                '%Y-%m-%d'
            )

        WHEN order_date REGEXP
            '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
            THEN DATE_FORMAT(
                STR_TO_DATE(order_date, '%d-%b-%Y'),
                '%Y-%m-%d'
            )

        WHEN order_date REGEXP
            '^[0-9]{2}[.][0-9]{2}[.][0-9]{4}$'
            THEN DATE_FORMAT(
                STR_TO_DATE(order_date, '%d.%m.%Y'),
                '%Y-%m-%d'
            )

        WHEN order_date REGEXP
            '^[0-9]{8}$'
            THEN DATE_FORMAT(
                STR_TO_DATE(order_date, '%Y%m%d'),
                '%Y-%m-%d'
            )

        ELSE order_date
    END
WHERE order_date IS NOT NULL;

COMMIT;
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;


-- Verificamos que todas las fechas tengan el formato YYYY-MM-DD.
SELECT COUNT(*) AS fechas_no_normalizadas
FROM stg_sales
WHERE order_date IS NULL
   OR order_date NOT REGEXP
        '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';

-- Revisamos el intervalo temporal
SELECT
    MIN(order_date) AS primera_fecha,
    MAX(order_date) AS ultima_fecha
FROM stg_sales;



-- Diagnóstico de Ship Mode
-- Como varias filas pertenecen al mismo pedido, podemos recuperar el modo de 
-- envío desde otra línea con el mismo order_id. 
-- Solo lo haremos cuando el pedido tenga un único modo de envío conocido, 
-- así evitamos asignaciones ambiguas.
SELECT
    COALESCE(ship_mode, '[NULL]') AS ship_mode,
    COUNT(*) AS total
FROM stg_sales
GROUP BY ship_mode
ORDER BY total DESC;

-- Identificamos los pedidos que poseen exactamente
-- un modo de envío conocido.
DROP TEMPORARY TABLE IF EXISTS tmp_ship_mode_por_pedido;

CREATE TEMPORARY TABLE tmp_ship_mode_por_pedido AS
SELECT
    order_id,
    MAX(ship_mode) AS ship_mode_inferido
FROM stg_sales
WHERE ship_mode IS NOT NULL
GROUP BY order_id
HAVING COUNT(DISTINCT ship_mode) = 1;


-- Calculamos cuántos valores faltantes pueden recuperarse
-- y cuántos permanecerán sin información.
SELECT
    SUM(s.ship_mode IS NULL) AS ship_mode_null_iniciales,

    SUM(
        s.ship_mode IS NULL
        AND t.order_id IS NOT NULL
    ) AS ship_mode_recuperables,

    SUM(
        s.ship_mode IS NULL
        AND t.order_id IS NULL
    ) AS ship_mode_no_recuperables

FROM stg_sales AS s
LEFT JOIN tmp_ship_mode_por_pedido AS t
    ON s.order_id = t.order_id;

-- Aplicamos
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

UPDATE stg_sales AS destino
INNER JOIN tmp_ship_mode_por_pedido AS origen
    ON destino.order_id = origen.order_id
SET destino.ship_mode = origen.ship_mode_inferido
WHERE destino.ship_mode IS NULL;

COMMIT;
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;
DROP TEMPORARY TABLE tmp_ship_mode_por_pedido;


-- Verificamos los valores finales de Ship Mode.
SELECT
    COALESCE(ship_mode, '[NULL]') AS ship_mode,
    COUNT(*) AS total
FROM stg_sales
GROUP BY ship_mode
ORDER BY total DESC;


-- Contamos los valores que no pudieron recuperarse.
SELECT
    COUNT(*) AS ship_mode_null_restantes
FROM stg_sales
WHERE ship_mode IS NULL;

-- Los NULL restantes corresponden a pedidos donde 
-- ninguna fila contiene un modo de envío conocido. 




-- Validamos que todas las columnas tengan tengan formatos válidos.
-- Verificamos los valores NULL y los registros que no pueden
-- interpretarse como números decimales.

SELECT
    SUM(sales IS NULL) AS sales_null,
    SUM(
        sales IS NOT NULL
        AND sales NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
    ) AS sales_formato_invalido,

    SUM(quantity IS NULL) AS quantity_null,
    SUM(
        quantity IS NOT NULL
        AND quantity NOT REGEXP '^[0-9]+([.]0+)?$'
    ) AS quantity_formato_invalido,

    SUM(discount IS NULL) AS discount_null,
    SUM(
        discount IS NOT NULL
        AND discount NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
    ) AS discount_formato_invalido,

    SUM(profit IS NULL) AS profit_null,
    SUM(
        profit IS NOT NULL
        AND profit NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
    ) AS profit_formato_invalido
FROM stg_sales;


-- Ahora, verificamos reglas básicas de negocio:
-- Sales debe ser mayor que cero.
-- Quantity debe ser mayor que cero y representar unidades enteras.
-- Discount debe encontrarse entre 0 y 1.
-- Profit puede ser positivo, negativo o cero.
SELECT
    SUM(
        CAST(sales AS DECIMAL(30, 15)) <= 0
    ) AS sales_no_positivas,

    SUM(
        CAST(quantity AS DECIMAL(30, 15)) <= 0
    ) AS quantity_no_positivas,

    SUM(
        CAST(quantity AS DECIMAL(30, 15))
        <> FLOOR(CAST(quantity AS DECIMAL(30, 15)))
    ) AS quantity_no_enteras,

    SUM(
        CAST(discount AS DECIMAL(30, 15)) < 0
        OR CAST(discount AS DECIMAL(30, 15)) > 1
    ) AS discount_fuera_de_rango

FROM stg_sales;


-- Mostramos los valores de descuento fuera del intervalo permitido.
SELECT
    discount,
    COUNT(*) AS total
FROM stg_sales
WHERE CAST(discount AS DECIMAL(30, 15)) < 0
   OR CAST(discount AS DECIMAL(30, 15)) > 1
GROUP BY discount
ORDER BY total DESC;



-- Vista previa de la corrección de Discount
-- Supondré que el 5.5 de descuento es debido a un error de escala y debería ser 0.55
SELECT
    discount AS discount_original,
    CASE
        WHEN CAST(discount AS DECIMAL(10, 4)) = 5.5
            THEN '0.55'
        ELSE discount
    END AS discount_corregido,
    COUNT(*) AS total_registros
FROM stg_sales
GROUP BY
    discount,
    CASE
        WHEN CAST(discount AS DECIMAL(10, 4)) = 5.5
            THEN '0.55'
        ELSE discount
    END
ORDER BY CAST(discount AS DECIMAL(10, 4));


-- Aplicación de la corrección de Discount
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

UPDATE stg_sales
SET discount = '0.55'
WHERE CAST(discount AS DECIMAL(10, 4)) = 5.5;

COMMIT;
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;


-- Verificamos que no existan descuentos fuera del intervalo [0, 1].
SELECT
    COUNT(*) AS descuentos_fuera_de_rango
FROM stg_sales
WHERE discount IS NOT NULL
  AND (
        CAST(discount AS DECIMAL(10, 4)) < 0
        OR CAST(discount AS DECIMAL(10, 4)) > 1
      );

-- Confirmamos la distribución final
SELECT
    discount,
    COUNT(*) AS total
FROM stg_sales
GROUP BY discount
ORDER BY CAST(discount AS DECIMAL(10, 4));




-- Diagnóstico de valores numéricos faltantes
-- Clasificamos los registros según la combinación de valores
-- faltantes en Sales, Quantity y Profit.
SELECT
    COUNT(*) AS total_registros,

    SUM(
        sales IS NOT NULL
        AND quantity IS NOT NULL
        AND profit IS NOT NULL
    ) AS registros_completos,

    SUM(
        sales IS NULL
        AND quantity IS NOT NULL
        AND profit IS NOT NULL
    ) AS solo_sales_null,

    SUM(
        sales IS NOT NULL
        AND quantity IS NULL
        AND profit IS NOT NULL
    ) AS solo_quantity_null,

    SUM(
        sales IS NOT NULL
        AND quantity IS NOT NULL
        AND profit IS NULL
    ) AS solo_profit_null,

    SUM(
        sales IS NULL
        AND quantity IS NULL
        AND profit IS NOT NULL
    ) AS sales_quantity_null,

    SUM(
        sales IS NULL
        AND quantity IS NOT NULL
        AND profit IS NULL
    ) AS sales_profit_null,

    SUM(
        sales IS NOT NULL
        AND quantity IS NULL
        AND profit IS NULL
    ) AS quantity_profit_null,

    SUM(
        sales IS NULL
        AND quantity IS NULL
        AND profit IS NULL
    ) AS sales_quantity_profit_null

FROM stg_sales;


-- Mostramos los registros donde faltan las tres métricas principales.
SELECT
    row_id,
    order_id,
    product_id,
    product_name,
    discount,
    sales,
    quantity,
    profit
FROM stg_sales
WHERE sales IS NULL
  AND quantity IS NULL
  AND profit IS NULL
ORDER BY row_id;



-- Identificamos las métricas que se pueden recuperar

-- Eliminamos la tabla temporal si existe por una ejecución anterior.
DROP TEMPORARY TABLE IF EXISTS tmp_precio_unitario_producto;

-- Calculamos el precio de venta unitario observado para cada
-- combinación de producto y descuento.

-- Solo conservamos las combinaciones que tienen un único precio
-- unitario en todo el dataset, evitando imputaciones ambiguas.
CREATE TEMPORARY TABLE tmp_precio_unitario_producto AS
SELECT
    product_id,
    CAST(discount AS DECIMAL(10, 4)) AS discount,
    MIN(
        ROUND(
            CAST(sales AS DECIMAL(20, 6))
            / CAST(quantity AS DECIMAL(20, 6)),
            6
        )
    ) AS precio_unitario
FROM stg_sales
WHERE sales IS NOT NULL
  AND quantity IS NOT NULL
  AND discount IS NOT NULL
  AND CAST(quantity AS DECIMAL(20, 6)) > 0
GROUP BY
    product_id,
    CAST(discount AS DECIMAL(10, 4))
HAVING COUNT(
    DISTINCT ROUND(
        CAST(sales AS DECIMAL(20, 6))
        / CAST(quantity AS DECIMAL(20, 6)),
        6
    )
) = 1;

-- Calculamos cuántos valores faltantes pueden recuperarse
-- mediante un precio unitario conocido y no ambiguo.
SELECT
    SUM(
        s.sales IS NULL
        AND s.quantity IS NOT NULL
        AND p.product_id IS NOT NULL
    ) AS sales_recuperables,

    SUM(
        s.quantity IS NULL
        AND s.sales IS NOT NULL
        AND p.product_id IS NOT NULL
        AND p.precio_unitario > 0
        AND ABS(
            CAST(s.sales AS DECIMAL(20, 6))
            / p.precio_unitario
            - ROUND(
                CAST(s.sales AS DECIMAL(20, 6))
                / p.precio_unitario
            )
        ) < 0.000001
    ) AS quantity_recuperables

FROM stg_sales AS s
LEFT JOIN tmp_precio_unitario_producto AS p
    ON s.product_id = p.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = p.discount;

-- Mostramos ejemplos de Sales que podrían recuperarse.
SELECT
    s.row_id,
    s.product_id,
    s.discount,
    s.quantity,
    s.sales AS sales_original,
    ROUND(
        CAST(s.quantity AS DECIMAL(20, 6))
        * p.precio_unitario,
        6
    ) AS sales_calculado
FROM stg_sales AS s
INNER JOIN tmp_precio_unitario_producto AS p
    ON s.product_id = p.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = p.discount
WHERE s.sales IS NULL
  AND s.quantity IS NOT NULL
LIMIT 20;

-- Mostramos ejemplos de Quantity que podrían recuperarse.
SELECT
    s.row_id,
    s.product_id,
    s.discount,
    s.sales,
    s.quantity AS quantity_original,
    ROUND(
        CAST(s.sales AS DECIMAL(20, 6))
        / p.precio_unitario
    ) AS quantity_calculada
FROM stg_sales AS s
INNER JOIN tmp_precio_unitario_producto AS p
    ON s.product_id = p.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = p.discount
WHERE s.quantity IS NULL
  AND s.sales IS NOT NULL
  AND p.precio_unitario > 0
  AND ABS(
        CAST(s.sales AS DECIMAL(20, 6))
        / p.precio_unitario
        - ROUND(
            CAST(s.sales AS DECIMAL(20, 6))
            / p.precio_unitario
        )
      ) < 0.000001
LIMIT 20;


-- =====================================================
-- BLOQUE 11
-- Recuperación de Sales y Quantity
-- =====================================================

SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;

START TRANSACTION;


-- -----------------------------------------------------
-- 11.1 Recuperación de Sales
-- -----------------------------------------------------

-- Calculamos Sales multiplicando la cantidad vendida por el
-- precio unitario consistente del mismo producto y descuento.
UPDATE stg_sales AS s
INNER JOIN tmp_precio_unitario_producto AS p
    ON s.product_id = p.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = p.discount
SET s.sales = CAST(
    ROUND(
        CAST(s.quantity AS DECIMAL(20, 6))
        * p.precio_unitario,
        6
    ) AS CHAR
)
WHERE s.sales IS NULL
  AND s.quantity IS NOT NULL;




-- Calculamos Quantity dividiendo Sales entre el precio unitario.
-- Solo actualizamos cuando el resultado es positivo y corresponde
-- prácticamente a un número entero.
UPDATE stg_sales AS s
INNER JOIN tmp_precio_unitario_producto AS p
    ON s.product_id = p.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = p.discount
SET s.quantity = CAST(
    ROUND(
        CAST(s.sales AS DECIMAL(20, 6))
        / p.precio_unitario
    ) AS CHAR
)
WHERE s.quantity IS NULL
  AND s.sales IS NOT NULL
  AND p.precio_unitario > 0
  AND ROUND(
        CAST(s.sales AS DECIMAL(20, 6))
        / p.precio_unitario
      ) > 0
  AND ABS(
        CAST(s.sales AS DECIMAL(20, 6))
        / p.precio_unitario
        - ROUND(
            CAST(s.sales AS DECIMAL(20, 6))
            / p.precio_unitario
        )
      ) < 0.000001;

COMMIT;
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;

-- Comprobamos cuántos valores faltantes permanecen.
SELECT
    SUM(sales IS NULL) AS sales_null_restantes,
    SUM(quantity IS NULL) AS quantity_null_restantes
FROM stg_sales;

-- Comprobamos que las cantidades recuperadas sigan siendo positivas y enteras.
SELECT
    SUM(
        quantity IS NOT NULL
        AND CAST(quantity AS DECIMAL(20, 6)) <= 0
    ) AS cantidades_no_positivas,

    SUM(
        quantity IS NOT NULL
        AND CAST(quantity AS DECIMAL(20, 6))
            <> FLOOR(CAST(quantity AS DECIMAL(20, 6)))
    ) AS cantidades_no_enteras
FROM stg_sales;

-- Eliminamos la tabla temporal
DROP TEMPORARY TABLE IF EXISTS tmp_precio_unitario_producto;



-- Identificación de valores recuperables de Profit
DROP TEMPORARY TABLE IF EXISTS tmp_margen_producto;

-- Calculamos el margen observado para cada combinación
-- de producto y descuento.

-- Solo conservamos combinaciones con al menos dos registros
-- completos y un margen único, evitando imputaciones ambiguas.
CREATE TEMPORARY TABLE tmp_margen_producto AS
SELECT
    product_id,
    CAST(discount AS DECIMAL(10, 4)) AS discount,

    MIN(
        ROUND(
            CAST(profit AS DECIMAL(30, 15))
            / CAST(sales AS DECIMAL(30, 15)),
            10
        )
    ) AS margen_profit

FROM stg_sales
WHERE product_id IS NOT NULL
  AND discount IS NOT NULL
  AND sales IS NOT NULL
  AND profit IS NOT NULL
  AND CAST(sales AS DECIMAL(30, 15)) <> 0

GROUP BY
    product_id,
    CAST(discount AS DECIMAL(10, 4))

HAVING COUNT(*) >= 2
   AND COUNT(
        DISTINCT ROUND(
            CAST(profit AS DECIMAL(30, 15))
            / CAST(sales AS DECIMAL(30, 15)),
            10
        )
   ) = 1;


-- Calculamos cuántos valores faltantes de Profit pueden
-- recuperarse mediante un margen conocido y consistente.
SELECT
    SUM(s.profit IS NULL) AS profit_null_actuales,

    SUM(
        s.profit IS NULL
        AND s.sales IS NOT NULL
        AND m.product_id IS NOT NULL
    ) AS profit_recuperables,

    SUM(
        s.profit IS NULL
        AND (
            s.sales IS NULL
            OR m.product_id IS NULL
        )
    ) AS profit_no_recuperables

FROM stg_sales AS s
LEFT JOIN tmp_margen_producto AS m
    ON s.product_id = m.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = m.discount;


-- Mostramos ejemplos de los valores que podrían recuperarse.
SELECT
    s.row_id,
    s.product_id,
    s.discount,
    s.sales,
    s.profit AS profit_original,
    m.margen_profit,

    ROUND(
        CAST(s.sales AS DECIMAL(30, 15))
        * m.margen_profit,
        6
    ) AS profit_calculado

FROM stg_sales AS s
INNER JOIN tmp_margen_producto AS m
    ON s.product_id = m.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = m.discount

WHERE s.profit IS NULL
  AND s.sales IS NOT NULL

LIMIT 20;


-- Recuperación de Profit
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

-- Calculamos Profit multiplicando Sales por el margen
-- consistente observado para el mismo producto y descuento.
UPDATE stg_sales AS s
INNER JOIN tmp_margen_producto AS m
    ON s.product_id = m.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = m.discount
SET s.profit = CAST(
    ROUND(
        CAST(s.sales AS DECIMAL(30, 15))
        * m.margen_profit,
        6
    ) AS CHAR
)
WHERE s.profit IS NULL
  AND s.sales IS NOT NULL;

COMMIT;
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;


-- Verificamos cuántos valores faltantes de Profit permanecen.
SELECT
    SUM(profit IS NULL) AS profit_null_restantes
FROM stg_sales;

-- Validamos que todos los valores no nulos tengan formato numérico.
SELECT
    SUM(
        profit IS NOT NULL
        AND profit NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
    ) AS profit_formato_invalido
FROM stg_sales;

DROP TEMPORARY TABLE IF EXISTS tmp_margen_producto;



-- Validamos las fechas de Ship Date

-- Verificamos que todas las fechas de envío tengan
-- el formato YYYY-MM-DD.
SELECT
    COUNT(*) AS ship_dates_formato_invalido
FROM stg_sales
WHERE ship_date IS NULL
   OR ship_date NOT REGEXP
        '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';


-- Verificamos que las fechas de envío puedan convertirse
-- correctamente al tipo DATE.
SELECT
    COUNT(*) AS ship_dates_no_validas
FROM stg_sales
WHERE ship_date IS NOT NULL
  AND STR_TO_DATE(ship_date, '%Y-%m-%d') IS NULL;


-- Identificamos registros donde la fecha de envío
-- es anterior a la fecha del pedido.
SELECT
    COUNT(*) AS envios_anteriores_al_pedido
FROM stg_sales
WHERE order_date IS NOT NULL
  AND ship_date IS NOT NULL
  AND STR_TO_DATE(ship_date, '%Y-%m-%d')
      < STR_TO_DATE(order_date, '%Y-%m-%d');


-- Mostramos los registros con inconsistencias temporales.
SELECT
    row_id,
    order_id,
    order_date,
    ship_date,
    ship_mode
FROM stg_sales
WHERE order_date IS NOT NULL
  AND ship_date IS NOT NULL
  AND STR_TO_DATE(ship_date, '%Y-%m-%d')
      < STR_TO_DATE(order_date, '%Y-%m-%d')
ORDER BY
    order_date,
    ship_date;

-- Calculamos el intervalo mínimo, máximo y promedio
-- entre la fecha del pedido y la fecha de envío.
SELECT
    MIN(
        DATEDIFF(
            STR_TO_DATE(ship_date, '%Y-%m-%d'),
            STR_TO_DATE(order_date, '%Y-%m-%d')
        )
    ) AS dias_envio_minimos,

    MAX(
        DATEDIFF(
            STR_TO_DATE(ship_date, '%Y-%m-%d'),
            STR_TO_DATE(order_date, '%Y-%m-%d')
        )
    ) AS dias_envio_maximos,

    ROUND(
        AVG(
            DATEDIFF(
                STR_TO_DATE(ship_date, '%Y-%m-%d'),
                STR_TO_DATE(order_date, '%Y-%m-%d')
            )
        ),
        2
    ) AS dias_envio_promedio

FROM stg_sales
WHERE order_date IS NOT NULL
  AND ship_date IS NOT NULL;



-- Validamos la consistencia de clientes
-- Comprobamos si un mismo customer_id está asociado
-- con más de un nombre de cliente.
SELECT
    COUNT(*) AS clientes_con_nombres_inconsistentes
FROM
(
    SELECT
        customer_id
    FROM stg_sales
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
    HAVING COUNT(DISTINCT customer_name) > 1
) AS clientes_inconsistentes;


-- Comprobamos si un mismo customer_id está asociado
-- con más de un segmento.
SELECT
    COUNT(*) AS clientes_con_segmentos_inconsistentes
FROM
(
    SELECT
        customer_id
    FROM stg_sales
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
    HAVING COUNT(DISTINCT segment) > 1
) AS clientes_inconsistentes;

/*
Como tenemos 0 en ambas consultas, no necesitamos hacer nada más.

-- Mostramos los clientes asociados con más de un nombre.
SELECT
    customer_id,
    GROUP_CONCAT(
        DISTINCT customer_name
        ORDER BY customer_name
        SEPARATOR ' | '
    ) AS nombres_encontrados,
    COUNT(DISTINCT customer_name) AS total_nombres
FROM stg_sales
WHERE customer_id IS NOT NULL
GROUP BY customer_id
HAVING COUNT(DISTINCT customer_name) > 1
ORDER BY customer_id;

--Mostramos los clientes asociados con más de un segmento.
SELECT
    customer_id,
    GROUP_CONCAT(
        DISTINCT segment
        ORDER BY segment
        SEPARATOR ' | '
    ) AS segmentos_encontrados,
    COUNT(DISTINCT segment) AS total_segmentos
FROM stg_sales
WHERE customer_id IS NOT NULL
GROUP BY customer_id
HAVING COUNT(DISTINCT segment) > 1
ORDER BY customer_id;
*/




-- Validamos la consistencia de productos
-- Comprobamos si un mismo product_id está asociado
-- con más de un nombre de producto.
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

-- Comprobamos si un mismo product_id está asociado
-- con más de una categoría.
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

-- Comprobamos si un mismo product_id está asociado
-- con más de una subcategoría.
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


-- Mostramos productos asociados con diferentes nombres.
SELECT
    product_id,
    GROUP_CONCAT(
        DISTINCT product_name
        ORDER BY product_name
        SEPARATOR ' | '
    ) AS nombres_encontrados,
    COUNT(DISTINCT product_name) AS total_nombres
FROM stg_sales
WHERE product_id IS NOT NULL
GROUP BY product_id
HAVING COUNT(DISTINCT product_name) > 1
ORDER BY product_id;

/*
No hay productos con la misma categoría ni subcategoría

-- Mostramos productos asociados con diferentes categorías.
SELECT
    product_id,
    GROUP_CONCAT(
        DISTINCT category
        ORDER BY category
        SEPARATOR ' | '
    ) AS categorias_encontradas,
    COUNT(DISTINCT category) AS total_categorias
FROM stg_sales
WHERE product_id IS NOT NULL
GROUP BY product_id
HAVING COUNT(DISTINCT category) > 1
ORDER BY product_id;


-- Mostramos productos asociados con diferentes subcategorías.
SELECT
    product_id,
    GROUP_CONCAT(
        DISTINCT sub_category
        ORDER BY sub_category
        SEPARATOR ' | '
    ) AS subcategorias_encontradas,
    COUNT(DISTINCT sub_category) AS total_subcategorias
FROM stg_sales
WHERE product_id IS NOT NULL
GROUP BY product_id
HAVING COUNT(DISTINCT sub_category) > 1
ORDER BY product_id;
*/

-- =====================================================
-- BLOQUE 17
-- Diagnóstico de Product ID reutilizados
-- =====================================================


-- Mostramos cada nombre asociado con los Product ID
-- que presentan más de un nombre de producto.
-- También incluimos la frecuencia y el intervalo temporal
-- para determinar si se trata de variaciones de escritura
-- o de productos realmente diferentes.
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


-- Contamos los identificadores reutilizados y la cantidad
-- total de combinaciones Product ID - Product Name.
SELECT
    COUNT(*) AS product_id_reutilizados,
    SUM(total_nombres) AS combinaciones_id_nombre
FROM
(
    SELECT
        product_id,
        COUNT(DISTINCT product_name) AS total_nombres
    FROM stg_sales
    WHERE product_id IS NOT NULL
    GROUP BY product_id
    HAVING COUNT(DISTINCT product_name) > 1
) AS productos;



-- Validamos la consistencia de pedidos
-- Calculamos cuántos valores diferentes aparecen dentro
-- de cada pedido para los atributos que deberían ser únicos.
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


-- Diagnóstico detallado de pedidos inconsistentes
-- Resumimos los clientes y ubicaciones asociados con cada
-- order_id que presenta alguna inconsistencia.
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



-- Validamos los nombres asociados con varios Customer ID
-- Anteriormente comprobamos que cada customer_id pertenece
-- a un único nombre. Ahora validamos la relación inversa:
-- si un mismo nombre aparece asociado con varios identificadores.
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

-- Mostramos los nombres relacionados con más de un Customer ID.
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


-- Mostramos la frecuencia de cada Customer ID dentro
-- de los pedidos que contienen más de uno.
SELECT
    order_id,
    customer_name,
    customer_id,
    city,
    state,
    postal_code,
    COUNT(*) AS total_lineas
FROM stg_sales
WHERE order_id IN (
    'CA-2025-121465',
    'CA-2026-130494'
)
GROUP BY
    order_id,
    customer_name,
    customer_id,
    city,
    state,
    postal_code
ORDER BY
    order_id,
    total_lineas DESC,
    customer_id;



-- Determinamos el Customer ID canónico de Harry Olson
-- Revisamos la frecuencia y el periodo de aparición de cada
-- identificador asociado con Harry Olson.

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


-- Comprobamos si alguno de los identificadores asociados
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


-- Unificamos el Customer ID de Harry Olson
-- Los identificadores HO-15231, HO-15232, HO-15233 y HO-15234
-- pertenecen al mismo cliente que HO-15230.

-- Se conserva HO-15230 como identificador canónico porque es
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


-- Validamos los identificadores de origen
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



-- Validamos la consistencia geográfica
-- Comprobamos si un mismo código postal aparece asociado
-- con diferentes ciudades, estados, países o regiones.
WITH consistencia_postal AS
(
    SELECT
        postal_code,
        COUNT(DISTINCT city)      AS total_cities,
        COUNT(DISTINCT state)     AS total_states,
        COUNT(DISTINCT country)   AS total_countries,
        COUNT(DISTINCT region)    AS total_regions
    FROM stg_sales
    WHERE postal_code IS NOT NULL
    GROUP BY postal_code
)

SELECT
    SUM(total_cities > 1)      AS codigos_con_ciudades_inconsistentes,
    SUM(total_states > 1)      AS codigos_con_estados_inconsistentes,
    SUM(total_countries > 1)   AS codigos_con_paises_inconsistentes,
    SUM(total_regions > 1)     AS codigos_con_regiones_inconsistentes
FROM consistencia_postal;

-- Mostramos los códigos postales asociados con más de una
-- ciudad, estado, país o región.
SELECT
    postal_code,

    GROUP_CONCAT(
        DISTINCT city
        ORDER BY city
        SEPARATOR ' | '
    ) AS cities,

    GROUP_CONCAT(
        DISTINCT state
        ORDER BY state
        SEPARATOR ' | '
    ) AS states,

    GROUP_CONCAT(
        DISTINCT country
        ORDER BY country
        SEPARATOR ' | '
    ) AS countries,

    GROUP_CONCAT(
        DISTINCT region
        ORDER BY region
        SEPARATOR ' | '
    ) AS regions,

    COUNT(*) AS total_registros

FROM stg_sales
WHERE postal_code IS NOT NULL

GROUP BY postal_code

HAVING COUNT(DISTINCT city) > 1
    OR COUNT(DISTINCT state) > 1
    OR COUNT(DISTINCT country) > 1
    OR COUNT(DISTINCT region) > 1

ORDER BY postal_code;


-- Diagnóstico del código postal 92024
-- Revisamos cuántas veces aparece cada ciudad asociada
-- con el código postal 92024.
SELECT
    postal_code,
    city,
    state,
    country,
    region,
    COUNT(*) AS total_registros,
    COUNT(DISTINCT order_id) AS total_pedidos,
    COUNT(DISTINCT customer_id) AS total_clientes,
    MIN(order_date) AS primera_aparicion,
    MAX(order_date) AS ultima_aparicion
FROM stg_sales
WHERE postal_code = '92024'
GROUP BY
    postal_code,
    city,
    state,
    country,
    region
ORDER BY total_registros DESC;

-- Mostramos los clientes y pedidos asociados con cada ciudad
-- para determinar si se trata de un error aislado o sistemático.
SELECT
    city,
    customer_id,
    customer_name,
    order_id,
    order_date,
    COUNT(*) AS total_lineas
FROM stg_sales
WHERE postal_code = '92024'
GROUP BY
    city,
    customer_id,
    customer_name,
    order_id,
    order_date
ORDER BY
    city,
    customer_name,
    order_date,
    order_id;

-- Revisamos el historial geográfico de los clientes relacionados
-- con el código postal inconsistente.
SELECT
    customer_id,
    customer_name,
    city,
    state,
    postal_code,
    COUNT(*) AS total_registros
FROM stg_sales
WHERE customer_id IN
(
    SELECT DISTINCT customer_id
    FROM stg_sales
    WHERE postal_code = '92024'
)
GROUP BY
    customer_id,
    customer_name,
    city,
    state,
    postal_code
ORDER BY
    customer_name,
    total_registros DESC;



-- Corregimos geográfica del código postal 92024
-- El código postal 92024 corresponde a Encinitas, California.
-- Los registros identificados como San Diego se normalizan
-- utilizando Encinitas como ciudad canónica.
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

UPDATE stg_sales
SET city = 'Encinitas'
WHERE postal_code = '92024'
  AND city <> 'Encinitas';

COMMIT;
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;


-- Verificamos la ubicación final asociada con el código postal 92024.
SELECT
    postal_code,
    city,
    state,
    country,
    region,
    COUNT(*) AS total_registros
FROM stg_sales
WHERE postal_code = '92024'
GROUP BY
    postal_code,
    city,
    state,
    country,
    region;

-- Verificamos
WITH consistencia_postal AS
(
    SELECT
        postal_code,
        COUNT(DISTINCT city)    AS total_cities,
        COUNT(DISTINCT state)   AS total_states,
        COUNT(DISTINCT country) AS total_countries,
        COUNT(DISTINCT region)  AS total_regions
    FROM stg_sales
    WHERE postal_code IS NOT NULL
    GROUP BY postal_code
)

SELECT
    SUM(total_cities > 1)    AS codigos_con_ciudades_inconsistentes,
    SUM(total_states > 1)    AS codigos_con_estados_inconsistentes,
    SUM(total_countries > 1) AS codigos_con_paises_inconsistentes,
    SUM(total_regions > 1)   AS codigos_con_regiones_inconsistentes
FROM consistencia_postal;



-- Validamos los modos de envío
-- Mostramos la distribución de Ship Mode después de recuperar
-- los valores faltantes desde otras líneas del mismo pedido.
SELECT
    COALESCE(ship_mode, '[NULL]') AS ship_mode,
    COUNT(*) AS total_registros
FROM stg_sales
GROUP BY ship_mode
ORDER BY total_registros DESC;

-- Contamos los valores distintos de Ship Mode que no pertenecen
-- al catálogo esperado.
SELECT
    COUNT(DISTINCT ship_mode) AS ship_modes_no_validos
FROM stg_sales
WHERE ship_mode IS NOT NULL
  AND ship_mode NOT IN (
      'Standard Class',
      'Second Class',
      'First Class',
      'Same Day'
  );

/*
-- Mostramos los valores no reconocidos para inspeccionarlos.
SELECT
    ship_mode,
    COUNT(*) AS total_registros
FROM stg_sales
WHERE ship_mode IS NOT NULL
  AND ship_mode NOT IN (
      'Standard Class',
      'Second Class',
      'First Class',
      'Same Day'
  )
GROUP BY ship_mode
ORDER BY total_registros DESC;
*/


-- Validación final del proceso de limpieza
-- Verificamos el volumen, la unicidad de Row ID y las principales
-- reglas de calidad aplicadas durante la limpieza.

SELECT
    COUNT(*) AS total_registros,
    COUNT(DISTINCT row_id) AS row_id_unicos,

    SUM(row_id IS NULL) AS row_id_null,
    SUM(order_id IS NULL) AS order_id_null,
    SUM(customer_id IS NULL) AS customer_id_null,
    SUM(product_id IS NULL) AS product_id_null,

    SUM(
        order_date IS NULL
        OR order_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    ) AS order_dates_invalidas,

    SUM(
        ship_date IS NULL
        OR ship_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    ) AS ship_dates_invalidas,

    SUM(
        order_date IS NOT NULL
        AND ship_date IS NOT NULL
        AND STR_TO_DATE(ship_date, '%Y-%m-%d')
            < STR_TO_DATE(order_date, '%Y-%m-%d')
    ) AS envios_anteriores_al_pedido,

    SUM(
        segment IS NULL
        OR segment NOT IN (
            'Consumer',
            'Corporate',
            'Home Office'
        )
    ) AS segmentos_invalidos,

    SUM(
        category IS NULL
        OR category NOT IN (
            'Furniture',
            'Office Supplies',
            'Technology'
        )
    ) AS categorias_invalidas,

    SUM(
        ship_mode IS NOT NULL
        AND ship_mode NOT IN (
            'Standard Class',
            'Second Class',
            'First Class',
            'Same Day'
        )
    ) AS ship_modes_invalidos,

    SUM(
        discount IS NOT NULL
        AND (
            CAST(discount AS DECIMAL(10, 4)) < 0
            OR CAST(discount AS DECIMAL(10, 4)) > 1
        )
    ) AS descuentos_fuera_de_rango,

    SUM(
        quantity IS NOT NULL
        AND (
            CAST(quantity AS DECIMAL(20, 6)) <= 0
            OR CAST(quantity AS DECIMAL(20, 6))
                <> FLOOR(CAST(quantity AS DECIMAL(20, 6)))
        )
    ) AS cantidades_invalidas

FROM stg_sales;


-- Verificamos que no permanezcan filas completamente duplicadas.
SELECT
    COUNT(*) AS grupos_duplicados
FROM
(
    SELECT
        row_id,
        order_id,
        order_date,
        ship_date,
        ship_mode,
        customer_id,
        customer_name,
        segment,
        country,
        city,
        state,
        postal_code,
        region,
        product_id,
        category,
        sub_category,
        product_name,
        sales,
        quantity,
        discount,
        profit
    FROM stg_sales
    GROUP BY
        row_id,
        order_id,
        order_date,
        ship_date,
        ship_mode,
        customer_id,
        customer_name,
        segment,
        country,
        city,
        state,
        postal_code,
        region,
        product_id,
        category,
        sub_category,
        product_name,
        sales,
        quantity,
        discount,
        profit
    HAVING COUNT(*) > 1
) AS duplicados;