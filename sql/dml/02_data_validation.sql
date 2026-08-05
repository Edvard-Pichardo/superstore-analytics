/*
Archivo      : 02_data_validation.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Validación y perfilado inicial del conjunto de datos.
*/

-- Seleccionamos la base de datos.
USE superstore_analytics;

-- Verificamos que la cantidad de registros importados
-- coincida con el archivo CSV original (10703).
SELECT COUNT(*) AS total_registros
FROM raw_sales;

-- Verificamos el número de columnas (21)
SELECT COUNT(*) AS total_columnas
FROM information_schema.columns
WHERE table_schema = 'superstore_analytics'
  AND table_name = 'raw_sales';


-- Mostramos una vista previa de los datos
SELECT * FROM raw_sales
LIMIT 10;


-- Necesitamos ver cuántos valores son NULL
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


-- Identificamos los campos de texto que contienen una cadena
-- vacía en lugar de un valor válido.
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


-- Identificamos los registros completamente duplicados.
SELECT
    COUNT(*) AS total_duplicados
FROM
(
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
) AS duplicados;

-- Identificamos la cantidad de valores distintos en cada columna.
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

-- Valores únicos por categoría
SELECT DISTINCT segment
FROM raw_sales
ORDER BY segment;

SELECT DISTINCT category
FROM raw_sales
ORDER BY category;

SELECT DISTINCT sub_category
FROM raw_sales
ORDER BY sub_category;

SELECT DISTINCT region
FROM raw_sales
ORDER BY region;


-- Formato de fechas
SELECT
CASE
WHEN order_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} 00:00:00$'
THEN 'YYYY-MM-DD HH:MM:SS'
WHEN order_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
THEN 'DD-MMM-YYYY'
WHEN order_date REGEXP '^[0-9]{2}\\.[0-9]{2}\\.[0-9]{4}$'
THEN 'DD.MM.YYYY'
WHEN order_date REGEXP '^[0-9]{8}$'
THEN 'YYYYMMDD'
ELSE 'OTRO'
END AS formato,
COUNT(*) cantidad
FROM raw_sales
GROUP BY formato;

-- Distribución de la columna Segment
SELECT
    segment,
    COUNT(*) AS total
FROM raw_sales
GROUP BY segment
ORDER BY total DESC;

-- Distribución de la columna Category
SELECT
    category,
    COUNT(*) AS total
FROM raw_sales
GROUP BY category
ORDER BY total DESC;