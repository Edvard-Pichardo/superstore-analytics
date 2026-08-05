/*
Archivo      : 03_create_staging_data.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Creación de la tabla de trabajo para el proceso de limpieza.
*/

USE superstore_analytics;

-- Eliminamos la tabla si existe.
DROP TABLE IF EXISTS stg_sales;

-- Creamos una copia de la estructura y los datos.
CREATE TABLE stg_sales AS
SELECT *
FROM raw_sales;

-- Verificamos que la copia se haya realizado correctamente.
SELECT COUNT(*) AS total_registros -- 10703 igual que la tabla original
FROM stg_sales;