/*
Archivo      : 02_create_staging_tables.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Motor        : MySQL 8
Descripción  : Creación de la tabla raw_sales para almacenar
               el archivo CSV sin modificaciones.
*/

-- Seleccionamos la base de datos.
USE superstore_analytics;

-- Creamos la tabla que almacenará el contenido original del archivo CSV.
-- En esta etapa todos los campos se almacenan como VARCHAR para evitar
-- errores durante la importación. La conversión de tipos se realizará
-- posteriormente durante el proceso de limpieza.
CREATE TABLE raw_sales (

    row_id            VARCHAR(50),
    order_id          VARCHAR(50),
    order_date        VARCHAR(50),
    ship_date         VARCHAR(50),
    ship_mode         VARCHAR(100),

    customer_id       VARCHAR(50),
    customer_name     VARCHAR(255),
    segment           VARCHAR(100),

    country           VARCHAR(100),
    city              VARCHAR(100),
    state             VARCHAR(100),
    postal_code       VARCHAR(50),
    region            VARCHAR(100),

    product_id        VARCHAR(50),
    category          VARCHAR(100),
    sub_category      VARCHAR(100),
    product_name      VARCHAR(255),

    sales             VARCHAR(50),
    quantity          VARCHAR(50),
    discount          VARCHAR(50),
    profit            VARCHAR(50)

);

/*
Resultado esperado:
- La base de datos contiene una tabla llamada raw_sales.
- La tabla tiene 21 columnas.
- No existen restricciones ni claves primarias en esta etapa.
*/