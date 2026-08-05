/*
Archivo      : 05_load_clean_data.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Conversión y carga de los datos limpios desde
               stg_sales hacia clean_sales.
*/

-- Seleccionamos la base de datos.
USE superstore_analytics;

-- Guardamos la configuración actual y desactivamos temporalmente
-- el modo de actualizaciones seguras.
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

-- Eliminamos los registros existentes para que el script pueda
-- ejecutarse nuevamente sin duplicar información.
DELETE FROM clean_sales;

-- Insertamos los datos limpios y convertimos explícitamente
-- cada columna al tipo definido en clean_sales.
INSERT INTO clean_sales
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
)
SELECT
    CAST(row_id AS UNSIGNED),
    order_id,
    STR_TO_DATE(order_date, '%Y-%m-%d'),
    STR_TO_DATE(ship_date, '%Y-%m-%d'),
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

    CASE
        WHEN sales IS NULL
            THEN NULL
        ELSE CAST(sales AS DECIMAL(15, 6))
    END,

    CASE
        WHEN quantity IS NULL
            THEN NULL
        ELSE CAST(
            CAST(quantity AS DECIMAL(20, 6))
            AS UNSIGNED
        )
    END,

    CAST(discount AS DECIMAL(4, 2)),

    CASE
        WHEN profit IS NULL
            THEN NULL
        ELSE CAST(profit AS DECIMAL(15, 6))
    END

FROM stg_sales;

COMMIT;
-- Restauramos la configuración original.
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;


-- Comparamos la cantidad de registros entre staging y clean.
SELECT
    (SELECT COUNT(*) FROM stg_sales)
        AS registros_staging,

    (SELECT COUNT(*) FROM clean_sales)
        AS registros_clean,

    (
        (SELECT COUNT(*) FROM stg_sales)
        -
        (SELECT COUNT(*) FROM clean_sales)
    ) AS diferencia;


-- Visualizamos algunos registros ya convertidos.
SELECT *
FROM clean_sales
ORDER BY row_id
LIMIT 10;



-- Validamos la carga tipada
-- Comparamos la cantidad total de registros entre ambas tablas.
SELECT
    (SELECT COUNT(*) FROM stg_sales)
        AS registros_staging,

    (SELECT COUNT(*) FROM clean_sales)
        AS registros_clean,

    (
        (SELECT COUNT(*) FROM stg_sales)
        -
        (SELECT COUNT(*) FROM clean_sales)
    ) AS diferencia_registros;


-- Comparamos los valores faltantes antes y después
-- de realizar la conversión de tipos.
SELECT
    (SELECT SUM(ship_mode IS NULL) FROM stg_sales)
        AS ship_mode_null_staging,

    (SELECT SUM(ship_mode IS NULL) FROM clean_sales)
        AS ship_mode_null_clean,

    (SELECT SUM(sales IS NULL) FROM stg_sales)
        AS sales_null_staging,

    (SELECT SUM(sales IS NULL) FROM clean_sales)
        AS sales_null_clean,

    (SELECT SUM(quantity IS NULL) FROM stg_sales)
        AS quantity_null_staging,

    (SELECT SUM(quantity IS NULL) FROM clean_sales)
        AS quantity_null_clean,

    (SELECT SUM(profit IS NULL) FROM stg_sales)
        AS profit_null_staging,

    (SELECT SUM(profit IS NULL) FROM clean_sales)
        AS profit_null_clean;


-- Comparamos los totales numéricos usando la misma precisión
-- definida en la tabla clean_sales.
SELECT
    (
        SELECT SUM(CAST(sales AS DECIMAL(15, 6)))
        FROM stg_sales
    ) AS sales_staging,

    (
        SELECT SUM(sales)
        FROM clean_sales
    ) AS sales_clean,

    (
        SELECT SUM(
            CAST(
                CAST(quantity AS DECIMAL(20, 6))
                AS UNSIGNED
            )
        )
        FROM stg_sales
    ) AS quantity_staging,

    (
        SELECT SUM(quantity)
        FROM clean_sales
    ) AS quantity_clean,

    (
        SELECT SUM(CAST(discount AS DECIMAL(4, 2)))
        FROM stg_sales
    ) AS discount_staging,

    (
        SELECT SUM(discount)
        FROM clean_sales
    ) AS discount_clean,

    (
        SELECT SUM(CAST(profit AS DECIMAL(15, 6)))
        FROM stg_sales
    ) AS profit_staging,

    (
        SELECT SUM(profit)
        FROM clean_sales
    ) AS profit_clean;



-- Calculamos la diferencia entre los totales de ambas tablas.
-- Todos los resultados deben ser cero.
SELECT
    (
        SELECT SUM(CAST(sales AS DECIMAL(15, 6)))
        FROM stg_sales
    )
    -
    (
        SELECT SUM(sales)
        FROM clean_sales
    ) AS diferencia_sales,

    (
        SELECT SUM(
            CAST(
                CAST(quantity AS DECIMAL(20, 6))
                AS UNSIGNED
            )
        )
        FROM stg_sales
    )
    -
    (
        SELECT SUM(quantity)
        FROM clean_sales
    ) AS diferencia_quantity,

    (
        SELECT SUM(CAST(discount AS DECIMAL(4, 2)))
        FROM stg_sales
    )
    -
    (
        SELECT SUM(discount)
        FROM clean_sales
    ) AS diferencia_discount,

    (
        SELECT SUM(CAST(profit AS DECIMAL(15, 6)))
        FROM stg_sales
    )
    -
    (
        SELECT SUM(profit)
        FROM clean_sales
    ) AS diferencia_profit;


