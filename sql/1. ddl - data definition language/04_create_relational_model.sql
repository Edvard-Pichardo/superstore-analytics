/*
Archivo: 04_create_relational_model
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Creación de las tablas que conforman el 
             modelo relacional de la base de datos.
*/

-- Seleccionamos la base de datos. 
USE superstore_analytics;

-- Vamos a crear todas las tablas que conformen el modelo relacional. 
-- Para ello, ya se diseñó un modelo relacional acorde a las necesidades de la base de datos.

-- Eliminamos las tablas, si es que existen, para evitar problemas con ejecuciones anteriores. 
DROP TABLE IF EXISTS order_details;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS sub_categories;
DROP TABLE IF EXISTS segments;
DROP TABLE IF EXISTS ship_modes;
DROP TABLE IF EXISTS regions;
DROP TABLE IF EXISTS categories;


-- Nota: Es importante mencionar que el orden de la creación 
-- de las tablas es importante por las claves foráneas entre cada una de ellas. 


-- Tabla segments
-- Va a almacenar los segmentos comerciales de la base de datos:
-- Consumer, Corporate, Home Office.
CREATE TABLE segments (
    segment_id      TINYINT UNSIGNED AUTO_INCREMENT,
    segment_name    VARCHAR(20) NOT NULL,

    CONSTRAINT pk_segments
        PRIMARY KEY (segment_id),
    
    CONSTRAINT uq_segments_name
        UNIQUE (segment_name)
);


-- Tabla ship_modes
-- Va a almacenar todas las clases de envío disponibles:
-- Standar Class, Second Class, First Class y Same Day. 
CREATE TABLE ship_modes(
    ship_mode_id    TINYINT UNSIGNED AUTO_INCREMENT,
    ship_mode_name  VARCHAR(20) NOT NULL,

    CONSTRAINT pk_ship_modes
        PRIMARY KEY (ship_mode_id),
    
    CONSTRAINT uq_ship_modes_names
        UNIQUE (ship_mode_name)
);


-- Tabla regions
-- va a almacenar las regiones comerciales de la base de datos.
CREATE TABLE regions(
    region_id   TINYINT UNSIGNED AUTO_INCREMENT,
    region_name VARCHAR(20) NOT NULL,

    CONSTRAINT pk_regions
        PRIMARY KEY (region_id),
    
    CONSTRAINT uq_regions_names
        UNIQUE (region_name)
);


-- Tabla categories
-- Va a almacenar las diferentes categorías de los productos
CREATE TABLE categories(
    category_id     TINYINT UNSIGNED AUTO_INCREMENT,
    category_name   VARCHAR(30) NOT NULL,

    CONSTRAINT pk_categories
        PRIMARY KEY (category_id),

    CONSTRAINT uq_categories_names
        UNIQUE (category_name)
);


-- Revisemos que todas las tablas hayan sido creadas hasta este momento. 
DESCRIBE segments;
DESCRIBE ship_modes;
DESCRIBE regions;
DESCRIBE categories;


-- Pasemos a las tablas que tienen claves foráneas.

-- Tabla sub_categories
-- Va a almacenar todas las subcategorías que puede tener un producto
-- y lo va a relacionar con la categoría principal. 
CREATE TABLE sub_categories(
    sub_category_id     TINYINT UNSIGNED AUTO_INCREMENT,
    category_id         TINYINT UNSIGNED NOT NULL,
    sub_category_name   VARCHAR(30) NOT NULL,

    CONSTRAINT pk_sub_categories
        PRIMARY KEY (sub_category_id),
    -- Además, una subcategoría no puede repetirse dentro de la misma categoría
    CONSTRAINT uq_sub_categories
        UNIQUE (
            category_id,
            sub_category_name
        ),
    
    CONSTRAINT fk_sub_categories_category
        FOREIGN kEY (category_id)
        REFERENCES categories (category_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Verificamos las columnas de la taba sub_categories
DESCRIBE sub_categories;


-- Tabla locations
-- Esta va a almacenar las ubicaciones relacionadas a los pedidos. 
-- Las ubicaciones se van a separar de los clientes porque cada cleinte puede realizar
-- una compra desde diferentes locaciones, ciudades o códigos postales. 
CREATE TABLE locations(
    location_id     SMALLINT UNSIGNED AUTO_INCREMENT,
    region_id       TINYINT UNSIGNED NOT NULL,
    country         VARCHAR(100) NOT NULL,
    city            VARCHAR(100) NOT NULL,
    state           VARCHAR(100) NOT NULL,
    postal_code     VARCHAR(20) NOT NULL,

    CONSTRAINT pk_locations
        PRIMARY KEY (location_id),
    -- Cada región se debe registrar solo una vez
    CONSTRAINT uq_locations
        UNIQUE (
            country,
            city,
            state,
            postal_code,
            region_id
        ),
    
    CONSTRAINT fk_locations_region
        Foreign Key (region_id) 
        REFERENCES regions (region_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Revisamos las columnas de locations
DESCRIBE locations;


-- Tabla customers
-- Tendrá la información principal de cada cliente sin contar la ubicación. 
CREATE TABLE customers(
    customer_id     VARCHAR(20) NOT NULL,
    segment_id      TINYINT UNSIGNED NOT NULL,
    customer_name   VARCHAR(100) NOT NULL,

    CONSTRAINT pk_customers
        PRIMARY KEY (customer_id),
    
    INDEX idx_customers_segment_id (segment_id),

    CONSTRAINT fk_customers_segment
        Foreign Key (segment_id) 
        REFERENCES segments (segment_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

DESCRIBE customers;


-- Tabla products
-- Almacena todos los productos disponibles en la base de datos. 
-- En este caso, se utilizará product_key como clave primaria porque
-- detectamos que product_id está asociado a más de un producto.
CREATE TABLE products(
    product_key     INT UNSIGNED AUTO_INCREMENT,
    source_product_id    VARCHAR(20) NOT NULL,
    sub_category_id      TINYINT UNSIGNED NOT NULL,
    product_name         VARCHAR(255) NOT NULL,

    CONSTRAINT pk_products
        PRIMARY KEY (product_key),
    -- Podemos decir quer la combinación entre el nombre del producto
    -- y su id identifican totalmente al producto 
    CONSTRAINT uq_products
        UNIQUE (
            source_product_id,
            product_name
        ),
    
    CONSTRAINT fk_products_sub_category
        Foreign Key (sub_category_id) 
        REFERENCES sub_categories (sub_category_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

DESCRIBE products;


-- Tabla orders
-- Almacenará la información general de los pedidos.
-- También se utilizará orders_key como clave principal.
CREATE TABLE orders(
    order_key          INT UNSIGNED AUTO_INCREMENT,
    source_order_id    VARCHAR(20) NOT NULL,
    customer_id        VARCHAR(20) NOT NULL,
    location_id        SMALLINT UNSIGNED NOT NULL,
    ship_mode_id       TINYINT UNSIGNED,
    order_date         DATE NOT NULL,
    ship_date          DATE NOT NULL,

    CONSTRAINT pk_orders
        PRIMARY KEY (order_key),
    -- Esta combinación permite distinguir los pedidos cuyo
    -- identificador original fue reutilizado para más de
    -- un pedido.
    CONSTRAINT uq_orders_source_customer_location
        UNIQUE (
            source_order_id,
            customer_id,
            location_id
        ),

    CONSTRAINT chk_orders_dates
        CHECK (ship_date >= order_date),

    INDEX idx_orders_customer_id (customer_id),
    INDEX idx_orders_location_id (location_id),
    INDEX idx_orders_ship_mode_id (ship_mode_id),
    INDEX idx_orders_order_date (order_date),

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_orders_location
        FOREIGN KEY (location_id)
        REFERENCES locations (location_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_orders_ship_mode
        FOREIGN KEY (ship_mode_id)
        REFERENCES ship_modes (ship_mode_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

DESCRIBE orders;


-- Tabla order_details
-- Esta tabla debe almacenar cada línea del producto incluyendo:
-- pedido, venta, cantidad, descuento y beneficio.
CREATE TABLE order_details(
    order_detail_key    INT UNSIGNED AUTO_INCREMENT,
    source_row_id       INT UNSIGNED NOT NULL,
    order_key           INT UNSIGNED NOT NULL,
    product_key         INT UNSIGNED NOT NULL,
    sales               DECIMAL(15, 6),
    quantity            INT UNSIGNED,
    discount            DECIMAL(4, 2) NOT NULL,
    profit              DECIMAL(15, 6),

    CONSTRAINT pk_order_details
        PRIMARY KEY (order_detail_key),
    -- Cada Row ID del archivo original debe aparecer
    -- una sola vez en el modelo relacional.
    CONSTRAINT uq_order_details_source_row
        UNIQUE (source_row_id),

    CONSTRAINT chk_order_details_sales
        CHECK (
            sales IS NULL
            OR sales > 0
        ),

    CONSTRAINT chk_order_details_quantity
        CHECK (
            quantity IS NULL
            OR quantity > 0
        ),

    CONSTRAINT chk_order_details_discount
        CHECK (
            discount BETWEEN 0 AND 1
        ),

    INDEX idx_order_details_order_key (order_key),
    INDEX idx_order_details_product_key (product_key),

    CONSTRAINT fk_order_details_order
        FOREIGN KEY (order_key)
        REFERENCES orders (order_key)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_order_details_product
        FOREIGN KEY (product_key)
        REFERENCES products (product_key)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

DESCRIBE order_details;