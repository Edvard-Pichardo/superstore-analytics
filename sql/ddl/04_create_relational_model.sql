/*
Archivo      : 04_create_relational_model.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Creación de las tablas que conforman el modelo
               relacional de la base de datos.
*/

-- Seleccionamos la base de datos.
USE superstore_analytics;

-- Creamos las tablas de catálogo

-- Eliminamos las tablas si existen para permitir reconstruir
-- el modelo durante el desarrollo.
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS sub_categories;
DROP TABLE IF EXISTS segments;
DROP TABLE IF EXISTS ship_modes;
DROP TABLE IF EXISTS regions;
DROP TABLE IF EXISTS categories;


-- Tabla: segments
-- Almacena los segmentos comerciales a los que pertenecen
-- los clientes: Consumer, Corporate y Home Office.
CREATE TABLE segments
(
    segment_id      TINYINT UNSIGNED AUTO_INCREMENT,
    segment_name    VARCHAR(20) NOT NULL,

    CONSTRAINT pk_segments
        PRIMARY KEY (segment_id),

    CONSTRAINT uq_segments_name
        UNIQUE (segment_name)
);

-- Tabla: ship_modes
-- Almacena los modos de envío disponibles.
CREATE TABLE ship_modes
(
    ship_mode_id      TINYINT UNSIGNED AUTO_INCREMENT,
    ship_mode_name    VARCHAR(20) NOT NULL,

    CONSTRAINT pk_ship_modes
        PRIMARY KEY (ship_mode_id),

    CONSTRAINT uq_ship_modes_name
        UNIQUE (ship_mode_name)
);

-- Tabla: regions
-- Almacena las regiones comerciales utilizadas para
-- clasificar las ubicaciones geográficas.
CREATE TABLE regions
(
    region_id      TINYINT UNSIGNED AUTO_INCREMENT,
    region_name    VARCHAR(20) NOT NULL,

    CONSTRAINT pk_regions
        PRIMARY KEY (region_id),

    CONSTRAINT uq_regions_name
        UNIQUE (region_name)
);

-- Tabla: categories
-- Almacena las categorías principales de los productos.
CREATE TABLE categories
(
    category_id      TINYINT UNSIGNED AUTO_INCREMENT,
    category_name    VARCHAR(30) NOT NULL,

    CONSTRAINT pk_categories
        PRIMARY KEY (category_id),

    CONSTRAINT uq_categories_name
        UNIQUE (category_name)
);


-- Verificamos que las tablas de catálogo hayan sido creadas.
SHOW TABLES LIKE 'segments';
SHOW TABLES LIKE 'ship_modes';
SHOW TABLES LIKE 'regions';
SHOW TABLES LIKE 'categories';

-- Revisamos su estructura
DESCRIBE segments;
DESCRIBE ship_modes;
DESCRIBE regions;
DESCRIBE categories;



-- Creamos la tabla de subcategorías

-- Tabla: sub_categories
-- Almacena las subcategorías de productos y las relaciona
-- con su categoría principal.
CREATE TABLE sub_categories
(
    sub_category_id      TINYINT UNSIGNED AUTO_INCREMENT,
    category_id          TINYINT UNSIGNED NOT NULL,
    sub_category_name    VARCHAR(30) NOT NULL,

    CONSTRAINT pk_sub_categories
        PRIMARY KEY (sub_category_id),
    -- Una subcategoría no puede repetirse dentro
    -- de la misma categoría.
    CONSTRAINT uq_sub_categories
        UNIQUE (
            category_id,
            sub_category_name
        ),

    CONSTRAINT fk_sub_categories_category
        FOREIGN KEY (category_id)
        REFERENCES categories (category_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Verificamos que la tabla haya sido creada.
SHOW TABLES LIKE 'sub_categories';

-- Revisamos sus columnas.
DESCRIBE sub_categories;

-- Revisamos la definición completa, incluyendo
-- claves y restricciones.
SHOW CREATE TABLE sub_categories;



-- Creamos la tabla de ubicaciones

-- Tabla: locations
-- Almacena las ubicaciones geográficas asociadas con los pedidos.
-- La ubicación se separa del cliente porque un mismo cliente puede
-- realizar compras desde diferentes ciudades o códigos postales.
CREATE TABLE locations
(
    location_id    SMALLINT UNSIGNED AUTO_INCREMENT,
    region_id      TINYINT UNSIGNED NOT NULL,
    country        VARCHAR(100) NOT NULL,
    city           VARCHAR(100) NOT NULL,
    state          VARCHAR(100) NOT NULL,
    postal_code    VARCHAR(20) NOT NULL,

    CONSTRAINT pk_locations
        PRIMARY KEY (location_id),
    -- Evita registrar más de una vez exactamente
    -- la misma ubicación geográfica.
    CONSTRAINT uq_locations
        UNIQUE (
            country,
            state,
            city,
            postal_code,
            region_id
        ),

    CONSTRAINT fk_locations_region
        FOREIGN KEY (region_id)
        REFERENCES regions (region_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Verificamos que la tabla haya sido creada.
SHOW TABLES LIKE 'locations';

-- Revisamos sus columnas y tipos.
DESCRIBE locations;

-- Revisamos la definición completa, incluyendo
-- la restricción única y la clave foránea.
SHOW CREATE TABLE locations;



-- Creamos la tabla de clientes

-- Tabla: customers
-- Almacena la información principal de cada cliente.
-- La ubicación no se incluye porque un mismo cliente puede
-- realizar pedidos desde diferentes ciudades o códigos postales.
CREATE TABLE customers
(
    customer_id      VARCHAR(20) NOT NULL,
    segment_id       TINYINT UNSIGNED NOT NULL,
    customer_name    VARCHAR(100) NOT NULL,

    CONSTRAINT pk_customers
        PRIMARY KEY (customer_id),

    INDEX idx_customers_segment_id (segment_id),

    CONSTRAINT fk_customers_segment
        FOREIGN KEY (segment_id)
        REFERENCES segments (segment_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Verificamos que la tabla haya sido creada.
SHOW TABLES LIKE 'customers';

-- Revisamos sus columnas y tipos.
DESCRIBE customers;

-- Revisamos la clave primaria, el índice y la clave foránea.
SHOW CREATE TABLE customers;



-- Creamos la tabla de productos

-- Tabla: products
-- Almacena los productos disponibles en el dataset.

-- Se utiliza product_key como clave primaria interna porque
-- algunos product_id del archivo original están asociados con
-- más de un nombre de producto.
CREATE TABLE products
(
    product_key          INT UNSIGNED AUTO_INCREMENT,
    source_product_id    VARCHAR(20) NOT NULL,
    sub_category_id      TINYINT UNSIGNED NOT NULL,
    product_name         VARCHAR(255) NOT NULL,

    CONSTRAINT pk_products
        PRIMARY KEY (product_key),
    -- La combinación del identificador original y el nombre
    -- distingue los productos cuyos códigos fueron reutilizados.
    CONSTRAINT uq_products_source_id_name
        UNIQUE (
            source_product_id,
            product_name
        ),

    INDEX idx_products_sub_category_id (sub_category_id),

    CONSTRAINT fk_products_sub_category
        FOREIGN KEY (sub_category_id)
        REFERENCES sub_categories (sub_category_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Verificamos que la tabla haya sido creada.
SHOW TABLES LIKE 'products';

-- Revisamos sus columnas y tipos.
DESCRIBE products;

-- Revisamos la clave primaria, la restricción única
-- y la clave foránea.
SHOW CREATE TABLE products;

