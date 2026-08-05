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

