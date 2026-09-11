/*
Archivo: 04_data_cleaning_2
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Limpieza y estandarización de los datos almacenados
             en la tabla stg_sales.
             Corregir faltas de ortografía y formato de fecha. 
*/

USE superstore_analytics;

-- Ahora, vamso a corregir las faltas de ortografía de la columna segment. 
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
    END AS clean_segment
FROM stg_sales
ORDER BY segment_original;

-- Quedaron bastante bien, por lo que podemos actualizar la tabla.

-- Actualizamos la información en stg_sales
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

-- Verificamos que únicamente estén los tres segmentos válidos. 
SELECT segment, COUNT(*) AS total
FROM stg_sales
GROUP BY segment
ORDER BY total DESC;

-- Tenemos que:
-- Consumer     5281
-- Corporate    3090
-- Home Office  1823
-- Total:       10194

-- Comprobamos que no quedó ninguna variante inesperada de los tres segmentos.
SELECT COUNT(*) AS segmentos_no_validos
FROM stg_sales
WHERE segment NOT IN (
    'Consumer',
    'Corporate',
    'Home Office'
)
   OR segment IS NULL;

-- No quedó ninguna variante


-- Ahora, vamos a normalizar los diferentes formatos de fecha. 
-- Debemos configurar los nombres de los meses en inglés para interpretar
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


-- Aplicamos los cambios de la normalización en stg_sales
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

-- No quedó ninguna fecha con algún otro formato


-- Revisamos el intervalo temporal
SELECT
    MIN(order_date) AS primera_fecha,
    MAX(order_date) AS ultima_fecha
FROM stg_sales;

-- El intervalo temporal es de 2023-01-03 a 2026-12-30





