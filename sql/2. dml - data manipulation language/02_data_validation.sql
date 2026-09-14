/*
Archivo: 02_data_validation
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Validación y perfilado inicial del conjunto de datos.
*/

USE superstore_analytics;

-- Verificamos la cantidad de registros importados.
-- Deben de ser 10703 registros en total. 
SELECT count(*) AS "Registros Totales" 
FROM raw_sales;


-- Verificamos el número de columnas (21)
SELECT count(*) AS "Columnas totales"
FROM information_schema.COLUMNS
WHERE table_schema = 'superstore_analytics'
    AND table_name = 'raw_sales';


-- Mostramos una vista previa de los datos.
SELECT * FROM raw_sales LIMIT 10;


-- Necesitamos saber cuántos valores son nulos en cada una de las columnas de la base de datos
SELECT
    SUM(row_id IS NULL)           AS row_id_null,
    SUM(order_id IS NULL)         AS order_id_null,
    SUM(order_date IS NULL)       AS order_date_null,
    SUM(ship_date IS NULL)        AS ship_date_null,
    SUM(ship_mode IS NULL)        AS ship_mode_null,
    SUM(customer_id IS NULL)      AS customer_id_null,
    SUM(customer_name IS NULL)    AS customer_name_null,
    SUM(segment IS NULL)          AS segment_null,
    SUM(country IS NULL)          AS country_null,
    SUM(city IS NULL)             AS city_null,
    SUM(state IS NULL)            AS state_null,
    SUM(postal_code IS NULL)      AS postal_code_null,
    SUM(region IS NULL)           AS region_null,
    SUM(product_id IS NULL)       AS product_id_null,
    SUM(category IS NULL)         AS category_null,
    SUM(sub_category IS NULL)     AS sub_category_null,
    SUM(product_name IS NULL)     AS product_name_null,
    SUM(sales IS NULL)            AS sales_null,
    SUM(quantity IS NULL)         AS quantity_null,
    SUM(discount IS NULL)         AS discount_null,
    SUM(profit IS NULL)           AS profit_null
FROM raw_sales;


-- Según esta primera revisión, no hay nulos en las tablas.
-- Sin embargo, cuando vimos la muestra de los datos sí hay datos faltantes o espacios vacíos en la tabla.
-- Posiblemente haya una cadena vacía en lugar de un valor nulo. 


-- Revisemos entonces cuántas cadenas vacías hay en nuestra base de datos. 
SELECT
    SUM(TRIM(row_id) = '')            AS row_id_vacios,
    SUM(TRIM(order_id) = '')          AS order_id_vacios,
    SUM(TRIM(order_date) = '')        AS order_date_vacios,
    SUM(TRIM(ship_date) = '')         AS ship_date_vacios,
    SUM(TRIM(ship_mode) = '')         AS ship_mode_vacios,
    SUM(TRIM(customer_id) = '')       AS customer_id_vacios,
    SUM(TRIM(customer_name) = '')     AS customer_name_vacios,
    SUM(TRIM(segment) = '')           AS segment_vacios,
    SUM(TRIM(country) = '')           AS country_vacios,
    SUM(TRIM(city) = '')              AS city_vacios,
    SUM(TRIM(state) = '')             AS state_vacios,
    SUM(TRIM(postal_code) = '')       AS postal_code_vacios,
    SUM(TRIM(region) = '')            AS region_vacios,
    SUM(TRIM(product_id) = '')        AS product_id_vacios,
    SUM(TRIM(category) = '')          AS category_vacios,
    SUM(TRIM(sub_category) = '')      AS sub_category_vacios,
    SUM(TRIM(product_name) = '')      AS product_name_vacios,
    SUM(TRIM(sales) = '')             AS sales_vacios,
    SUM(TRIM(quantity) = '')          AS quantity_vacios,
    SUM(TRIM(discount) = '')          AS discount_vacios,
    SUM(TRIM(profit) = '')            AS profit_vacios
FROM raw_sales;

-- Obtenemos que:
-- ship_mode_vacios     = 1071
-- sales_vacios         = 2038
-- quantity_vacios      = 537
-- profit_vacios        = 1076

-- Ahora, veamos cuántos registros están duplicados
SELECT count(*) AS "Duplicados totales"
FROM (
    SELECT *,
    COUNT(*) AS repeticiones
    FROM raw_sales
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
) AS duplicados

-- Existen 509 filas que están duplicadas


--Ahora, vamos a identificar la cantidad de valores diferentes en cada columna
SELECT
    COUNT(DISTINCT order_id)      AS pedidos,
    COUNT(DISTINCT customer_id)   AS clientes,
    COUNT(DISTINCT product_id)    AS productos,
    COUNT(DISTINCT city)          AS ciudades,
    COUNT(DISTINCT state)         AS estados,
    COUNT(DISTINCT region)        AS regiones,
    COUNT(DISTINCT category)      AS categorias,
    COUNT(DISTINCT sub_category)  AS subcategorias,
    COUNT(DISTINCT segment)       AS segmentos
FROM raw_sales;

-- Tenemos que:
-- pedidos      - order_id      - 5111
-- clientes     - customer_id   - 804
-- productos    - product_id    - 1862
-- ciudades     - city          - 542
-- estados      - state         - 59
-- regiones     - region        - 4
-- categorias   - category      - 4
-- subcategoria - subcategory   - 17
-- segmentos    - segment       - 10


-- Revisemos los datos por cada categoría
-- Segment
SELECT DISTINCT segment
FROM raw_sales
ORDER BY segment;

-- Notemos que existen incosnsistencias en los datos debido a faltas de ortográfia. 
-- Además, hay espacios en blanco antes o después de cada palabra.
-- Consumer - Consumr - Counsumer
-- Corp. - Coperate - Corporate
-- Home Office - Home-Office - HomeOffice

-- Revisemos la distribución de la columna segment
SELECT segment,
       COUNT(*) AS total
FROM raw_sales
GROUP BY segment
ORDER BY total DESC;

-- Tenemos que:
-- Consumer     5178
-- Counsumer    138
--   Consumer   129
-- Consumr      114
-- Corp.        79
-- Corperate    74
-- Corporate    3090
-- Home Office  1796
-- Home-Office  59
-- HomeOffice   46
-- Total:       10703


-- Category
SELECT DISTINCT category
FROM raw_sales
ORDER BY category;

-- Aquí también hay inconsistencias debido a espacios antes o después de la palabra Furniture

-- Revisemos la distribución de la columna category-
SELECT category,
       COUNT(*) AS total
FROM raw_sales
GROUP BY category
ORDER BY total DESC;

-- Tenemos que:
-- Office Supplies  6436
-- Furniture        2148
-- Technology       1961
--  Furniture       158
-- Total:           1073


-- Subcategory
SELECT DISTINCT sub_category
FROM raw_sales
ORDER BY sub_category;

-- Notemos que sub_category no presenta ninguna inconsistencia


-- Region
SELECT DISTINCT region
FROM raw_sales
ORDER BY region;

-- Tampoco parece que haya ninguna inconsistencia en estos datos.


-- Una inconsistencia que se notaba a simple vista desde que se visualizaron los datos
-- es el formato de las fechas. Debemos homogenizarlo a uno solo. 
SELECT 
CASE 
    WHEN order_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} 00:00:00$' 
    THEN 'YYYY-MM-DD HH:MM:SS'
    WHEN order_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' 
    THEN 'DD-MMM-YYYY'
    WHEN order_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' 
    THEN 'YYYY-MM-DD'
    WHEN order_date REGEXP '^[0-9]{2}\\.[0-9]{2}\\.[0-9]{4}$' 
    THEN 'DD.MM.YYYY'
    WHEN order_date REGEXP '^[0-9]{8}$'
    THEN 'YYYYMMDD'
    ELSE 'OTRO'
END AS formato,
COUNT(*) AS cantidad
FROM raw_sales
GROUP BY formato;

-- Tenemos que:
-- DD-MM.YYYY           - 1069
-- DD-MMM-YYYY          - 1059
-- YYY-MM-DD HH:MM:SS   - 7500
-- YYYYMMDD             - 1075
-- Total: 10703