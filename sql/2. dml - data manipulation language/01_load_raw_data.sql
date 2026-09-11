/*
Archivo: 01_load_raw_data
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Carga del archivo CSV original en la tabla raw_sales.
*/

USE superstore_analytics;

-- Cargamos el archivo CVS original en la tabla raw_sales
-- Importante: Se debe sustituir la ruta por la ubicación del archivo en cada equipo.
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
-- Debe tener los 10703 registros del CSV original.
SELECT count(*) AS "Registros totales"
FROM raw_sales;

-- Visualizamos una muestra de los datos que importamos para ver que todo haya salido bien. 
SELECT * FROM raw_sales LIMIT 10;