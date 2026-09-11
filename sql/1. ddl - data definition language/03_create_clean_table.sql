/*
Archivo: 03_create_clean_table
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Creación de la tabla clean_sales con tipos de datos,
             restricciones y reglas de integridad.
*/

-- Sleccionamos la base de datos.
USE superstore_analytics;

-- Por seguridad, eliminamos la tabla si existe desde antes. 
DROP TABLE IF EXISTS clean_sales;

-- Creamos la tabla para almacenar los datos limpios.
-- Cada dato debe ir con su respectivo tipo de dato definitivo.
-- Nota: Cada columna debe ser analizada por separado para asignarle su tipo correcto. 
CREATE TABLE clean_sales(
    row_id          INT UNSIGNED NOT NULL,
    order_id        VARCHAR(20) NOT NULL,
    order_date      DATE NOT NULL,
    ship_date       DATE NOT NULL,
    ship_mode       VARCHAR(20),
    customer_id     VARCHAR(20) NOT NULL,
    customer_name   VARCHAR(100) NOT NULL,
    segment         VARCHAR(20) NOT NULL,
    country         VARCHAR(100) NOT NULL,
    city            VARCHAR(100) NOT NULL,
    state           VARCHAR(100) NOT NULL,
    postal_code     VARCHAR(20) NOT NULL,
    region          VARCHAR(20) NOT NULL,
    product_id      VARCHAR(20) NOT NULL,
    category        VARCHAR(30) NOT NULL,
    subcategory     VARCHAR(30) NOT NULL,
    product_name    VARCHAR(255) NOT NULL,
    sales           DECIMAL(15, 6),
    quantity        INT UNSIGNED,
    discount        DECIMAL(4, 2) NOT NULL,
    profit          DECIMAL(15, 6),
    -- Clave primaria. 
    CONSTRAINT pk_clean_sales
        PRIMARY KEY (row_id),
    -- Restricción sobre la fecha de orden vs la fecha de envío    
    CONSTRAINT chk_clean_sales_date
        CHECK (ship_date > order_date),
    -- Restricción sobre los segmentos permitidos. 
    CONSTRAINT chk_clean_sales_segment
        CHECK   (
            segment IN (
                'Consumer',
                'Corporate'
                'Home Office'
            )
        ),
    -- Restricción sobre las categorías pemitidas.
    CONSTRAINT chk_clean_sales_category
        CHECK (
            category IN (
                'Furniture',
                'Office Supplies',
                'Technology'
            )
        ),
    -- Restricción sobre los modos de envío permitidos.     
    CONSTRAINT chk_clean_sales_ship_mode
        CHECK (
            ship_mode IS NULL
            OR ship_mode IN (
                'Satandar Class',
                'Second Class',
                'First Class',
                'Same Day'
            )
        ),
    -- Restricción sobre las ventas. No pueden ser cero o menores a cero.
    CONSTRAINT chk_clean_sales_sales
        CHECK (
            sales IS NULL
            OR sales > 0
        ),
    -- Restricción sobre la cantidad vendida. No puede ser cero ni negativo. 
    CONSTRAINT chk_clean_sales_quantity
        CHECK (
            quantity IS NULL
            OR quantity > 0
        ),
    -- Restricción sobre los descuentos. Debe estar entre 0 y 1 para ser un descuento efectivo.    
    CONSTRAINT chk_clean_sales_discount
        CHECK (
            discount BETWEEN 0 AND 1
        )
);

-- Vamos a revisar que la tabla haya quedado bien. 
DESCRIBE clean_sales;

-- También debemos revisar las restricciones que creamos.
SELECT
    constraint_name,
    constraint_type
FROM information_schema.TABLE_CONSTRAINTS
WHERE table_schema = 'superstore_analytics'
    AND table_name = 'clean_sales'
ORDER BY constraint_type, constraint_name;

-- La tabla no tiene ningún registro por el momento.
-- Podemos verificarlo. 
SELECT count(*) AS 'Registros Totales'
FROM clean_sales;