/*
Archivo      : 01_load_raw_data.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Carga del archivo CSV original en la tabla raw_sales.
*/

-- Seleccionamos la base de datos.
USE superstore_analytics;

-- Cargamos el archivo CSV en la tabla raw_sales.
-- IMPORTANTE: Sustituir la ruta por la ubicación del archivo en cada equipo.
LOAD DATA LOCAL INFILE '../../../../Documents/Proyectos/Repositorios Remotos/superstore-analytics/data/raw/sales_superstore_raw.csv'
INTO TABLE raw_sales
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
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
);

-- Verificamos que la carga se haya realizado correctamente.
SELECT COUNT(*) AS total_registros
FROM raw_sales;

-- Visualizamos una muestra de los datos importados.
SELECT * FROM raw_sales LIMIT 10;

/*
- La tabla raw_sales debe contener todos los registros del archivo CSV.
- No se modifica ningún dato durante la carga.
- La cantidad de registros debe coincidir con el número de filas del archivo,
  excluyendo la fila de encabezados.
*/