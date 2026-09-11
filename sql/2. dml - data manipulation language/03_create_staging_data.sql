/*
Archivo: 03_create_staging_data
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Creación de la tabla de trabajo para el proceso de limpieza.
*/

USE superstore_analytics;

-- Eliminamos la tabla si existe
DROP TABLE IF EXISTS stg_sales;

-- Creamos una copia de la estructura y los datos de raw_sales.
CREATE TABLE stg_sales AS 
SELECT *
FROM raw_sales;

-- Verificamos que se haya copiado correctamente. 
SELECT COUNT(*) AS "Registros totales"
FROM stg_sales;
-- Deben ser 10703 como en la tabla raw_sales

-- Tambien podemos ver los primeros datos de la tabla
SELECT * FROM stg_sales LIMIT 10;
