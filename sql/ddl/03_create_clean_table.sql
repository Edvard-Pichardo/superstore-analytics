/*
Archivo      : 03_create_clean_table.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Creación de la tabla clean_sales con tipos de datos,
               restricciones y reglas de integridad.
*/

-- Seleccionamos la base de datos.
USE superstore_analytics;

-- Eliminamos la tabla si existe para permitir reconstruir
-- esta capa durante el desarrollo.
DROP TABLE IF EXISTS clean_sales;

-- Creamos la tabla destinada a almacenar los datos limpios
-- con sus tipos de datos definitivos.
CREATE TABLE clean_sales
(
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
    sub_category    VARCHAR(30) NOT NULL,
    product_name    VARCHAR(255) NOT NULL,

    sales           DECIMAL(15, 6),
    quantity        INT UNSIGNED,
    discount        DECIMAL(4, 2) NOT NULL,
    profit          DECIMAL(15, 6),

    CONSTRAINT pk_clean_sales
        PRIMARY KEY (row_id),

    CONSTRAINT chk_clean_sales_dates
        CHECK (ship_date >= order_date),

    CONSTRAINT chk_clean_sales_segment
        CHECK (
            segment IN (
                'Consumer',
                'Corporate',
                'Home Office'
            )
        ),

    CONSTRAINT chk_clean_sales_category
        CHECK (
            category IN (
                'Furniture',
                'Office Supplies',
                'Technology'
            )
        ),

    CONSTRAINT chk_clean_sales_ship_mode
        CHECK (
            ship_mode IS NULL
            OR ship_mode IN (
                'Standard Class',
                'Second Class',
                'First Class',
                'Same Day'
            )
        ),

    CONSTRAINT chk_clean_sales_sales
        CHECK (
            sales IS NULL
            OR sales > 0
        ),

    CONSTRAINT chk_clean_sales_quantity
        CHECK (
            quantity IS NULL
            OR quantity > 0
        ),

    CONSTRAINT chk_clean_sales_discount
        CHECK (
            discount BETWEEN 0 AND 1
        )
);

DESCRIBE clean_sales;

-- Verificamos las restricciones creadas
SELECT
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'superstore_analytics'
  AND table_name = 'clean_sales'
ORDER BY constraint_type, constraint_name;

-- Tabla vacía
SELECT COUNT(*) AS total_registros
FROM clean_sales;