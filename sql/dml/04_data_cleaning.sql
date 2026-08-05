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

