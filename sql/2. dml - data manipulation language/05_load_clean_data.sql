/*
Archivo: 05_load_clean_data
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Conversión y carga de los datos limpios desde
               stg_sales hacia clean_sales.
*/

USE superstore_analytics;

-- Guardamos la configuración actual y desactivamos temporalmente el modo de actualizaciones seguras. 
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET @SQL_SAFE_UPDATES = 0;
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
    subcategory,
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


-- Para ver que la carga de datos se haya dado por completo
-- Podemos comparar la cantidad de registros entre las tablas staging y clean.
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

-- Tenemos que registros_staging tiene 10194 y registros_clean también. Su diferencia es de cero. 

-- Visualizamos algunos registros ya convertidos.
SELECT *
FROM clean_sales
LIMIT 10;

-- Podemos compararlos con los datos de stg_sales
SELECT *
FROM stg_sales
LIMIT 10;

-- Veamos que lo único que cambia es el tipo de los datos, ya que stg_sales solo recibió datos de tipo VARCHAR().
-- Mientras que clean_sales tiene los datos con su tipo correcto. 

-- Realicemos algunas comprobaciones más. 
-- Podemos comparar la cantidad de valores nulos antes y después de realizar la carga de datos. 
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
    
-- Vemos que los registros son prácticamente iguales.

-- Otra forma de comparar los valores más sensibles de la tabla (quantity, sales, discount y profit) 
-- Es comparando los totales numéricos de cada tabla. 
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

-- Esto significa que no hay ningún error al momento del copiado/carga de datos en clean_sales. 

-- Podemos verlo más rápidamente si calculamos la diferencia entre los totales de ambas tablas.
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
-- La diferencia de los totales es cero por lo que ambas tablas tienen los mismos datos. 


-- Aunque la tabla clean_sales tiene chequeos de seguridad para evitar que se suban datos incorrectos en sus diferentes columnas,
-- podemos revisar que no existan valores que violen las reglas principales del negocio.
SELECT
    SUM(row_id IS NULL) AS row_id_null,
    SUM(order_id IS NULL) AS order_id_null,
    SUM(order_date IS NULL) AS order_date_null,
    SUM(ship_date IS NULL) AS ship_date_null,
    SUM(customer_id IS NULL) AS customer_id_null,
    SUM(product_id IS NULL) AS product_id_null,

    SUM(ship_date < order_date)
        AS envios_anteriores_al_pedido,

    SUM(
        segment NOT IN (
            'Consumer',
            'Corporate',
            'Home Office'
        )
    ) AS segmentos_invalidos,

    SUM(
        category NOT IN (
            'Furniture',
            'Office Supplies',
            'Technology'
        )
    ) AS categorias_invalidas,

    SUM(
        ship_mode IS NOT NULL
        AND ship_mode NOT IN (
            'Standard Class',
            'Second Class',
            'First Class',
            'Same Day'
        )
    ) AS ship_modes_invalidos,

    SUM(
        sales IS NOT NULL
        AND sales <= 0
    ) AS sales_invalidas,

    SUM(
        quantity IS NOT NULL
        AND quantity <= 0
    ) AS cantidades_invalidas,

    SUM(
        discount < 0
        OR discount > 1
    ) AS descuentos_invalidos

FROM clean_sales;

-- Como podemos observar, no hay ningún dato que esté fuera de lugar.

-- Debemos verificar que no haya ningún row_id duplicado, es decir,
-- que la clave primaria conserve la misma cantidad de registros que identificadores únicos.
SELECT
    COUNT(*) AS total_registros,
    COUNT(DISTINCT row_id) AS row_id_unicos,
    COUNT(*) - COUNT(DISTINCT row_id) AS row_id_duplicados
FROM clean_sales;
-- Esto es importante porque significa que row_id identifica cada venta de forma individual. 

-- Por último, revisamos los valores mínimos y máximos después de la conversión de tipos.
SELECT
    MIN(sales) AS sales_minimas,
    MAX(sales) AS sales_maximas,

    MIN(quantity) AS quantity_minima,
    MAX(quantity) AS quantity_maxima,

    MIN(discount) AS discount_minimo,
    MAX(discount) AS discount_maximo,

    MIN(profit) AS profit_minimo,
    MAX(profit) AS profit_maximo

FROM clean_sales;

-- Todo esto parece inútil porque se están revisando cosas de un copiado de datos,
-- pero es importante que la información dentro de la tabla clean_sales sea la misma que la de stg_sales
-- porque hemos estado trabajando la limpieza de datos en ella. 
-- Una duplicación de datos, un mal copiado o cualquier error que pudiera haber ocurrido durnate la carga
-- se debe encontrar y solucionar antes de utilizar estos datos. 