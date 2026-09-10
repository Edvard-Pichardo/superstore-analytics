/*
Archivo: 02_create_staging_tables
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Creación de la tabla raw_sales para almacenar
             el archivo CSV sin modificaciones.
*/

-- Seleccionamos la base de datos.
USE superstore_analytics;

-- Vamos a crear una tabla que contenga toda la base de datos.
-- De esa forma, podemos modificarla sin cambiar el contenido de la base de datos original.
-- Vamos a almacenar todos los datos como VARCHAR para evitar errores durante la importación.
-- Esto se deberá cambiar posteriormente, aunque es mejor hacerlo durante el análisis de datos.
CREATE TABLE raw_sales (
    row_id          VARCHAR(50),
    order_id        VARCHAR(50),
    order_date      VARCHAR(50),
    ship_date       VARCHAR(50),
    ship_mode       VARCHAR(100),
    customer_id     VARCHAR(50),
    customer_name   VARCHAR(255),
    segment         VARCHAR(100),
    country         VARCHAR(100),
    city            VARCHAR(100),
    state           VARCHAR(100),
    postal_code     VARCHAR(50),
    region          VARCHAR(100),
    product_id      VARCHAR(50),
    category        VARCHAR(100),
    subcategory     VARCHAR(100),
    product_name    VARCHAR(255),
    sales           VARCHAR(50),
    quantity        VARCHAR(50),
    discount        VARCHAR(50),
    profit          VARCHAR(50)
);