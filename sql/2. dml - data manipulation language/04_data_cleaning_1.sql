/*
Archivo: 04_data_cleaning_1
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Limpieza y estandarización de los datos almacenados
             en la tabla stg_sales.
             Elimiar duplicados y espacios vacíos en las cadenas de texto. 
*/

USE superstore_analytics;

-- Primero, vamos a eliminar los registros duplicados.
-- Recordemos que habíamos detectado 509 filas duplicadas.
-- Para ello, desactivamos el modo de actualizaciones seguras 
-- ya que eliminaremos y recargaremos todos los registros de staging.
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

-- Eliminamos la tabla temporal si es que existe de una ejecución anterior.
DROP TEMPORARY TABLE IF EXISTS tmp_stg_sales;

-- Creamos una tabla temporal con la misma estructura de stg_sales.
CREATE TEMPORARY TABLE tmp_stg_sales
LIKE stg_sales;

-- Insertamos las filas descartando las duplicadas.
INSERT INTO tmp_stg_sales
SELECT DISTINCT *
FROM stg_sales;
-- Se subieron 10194 datos (10703-509=10194) lo cual es correcto.

-- Vaciamos la tabla de staging.
DELETE FROM stg_sales;

-- Regresamos únicamente los registros únicos.
INSERT INTO stg_sales
SELECT *
FROM tmp_stg_sales;

DROP TEMPORARY TABLE tmp_stg_sales;
COMMIT;

-- Restauramos la configuración original.
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;

-- Verificamos el total de registros después de la eliminación (10703 - 509 = 10194 registros).
SELECT COUNT(*) AS total_registros_sin_duplicados
FROM stg_sales;

-- También podemos analizarlo realizando lo mismoque se hizo en la validación de datos:
SELECT count(*) AS "Duplicados totales"
FROM (
    SELECT *,
    COUNT(*) AS repeticiones
    FROM stg_sales
    GROUP BY
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
    HAVING COUNT(*) > 1
) AS duplicados
-- Ahora sí, no hay datos duplicados en stg_sales.


-- Ahora, vamos a limpiar todos los espacios y las cadenas vacías.
-- Nuevamente, desativando el modo de actualziaciones seguras. 
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

-- Recordemos que TRIM elimina espacios al inicio y al final.
-- NULLIF convierte las cadenas vacías en valores NULL.
UPDATE stg_sales
SET
    row_id          = NULLIF(TRIM(row_id), ''),
    order_id        = NULLIF(TRIM(order_id), ''),
    order_date      = NULLIF(TRIM(order_date), ''),
    ship_date       = NULLIF(TRIM(ship_date), ''),
    ship_mode       = NULLIF(TRIM(ship_mode), ''),
    customer_id     = NULLIF(TRIM(customer_id), ''),
    customer_name   = NULLIF(TRIM(customer_name), ''),
    segment         = NULLIF(TRIM(segment), ''),
    country         = NULLIF(TRIM(country), ''),
    city            = NULLIF(TRIM(city), ''),
    state           = NULLIF(TRIM(state), ''),
    postal_code     = NULLIF(TRIM(postal_code), ''),
    region          = NULLIF(TRIM(region), ''),
    product_id      = NULLIF(TRIM(product_id), ''),
    category        = NULLIF(TRIM(category), ''),
    sub_category    = NULLIF(TRIM(sub_category), ''),
    product_name    = NULLIF(TRIM(product_name), ''),
    sales           = NULLIF(TRIM(sales), ''),
    quantity        = NULLIF(TRIM(quantity), ''),
    discount        = NULLIF(TRIM(discount), ''),
    profit          = NULLIF(TRIM(profit), '');

COMMIT;
-- Restauramos la configuración original.
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;

-- Verificamos que ya no existan cadenas vacías.
SELECT
    SUM(TRIM(COALESCE(ship_mode, '')) = '') AS ship_mode_vacios,
    SUM(TRIM(COALESCE(sales, '')) = '')     AS sales_vacios,
    SUM(TRIM(COALESCE(quantity, '')) = '')  AS quantity_vacios,
    SUM(TRIM(COALESCE(profit, '')) = '')    AS profit_vacios
FROM stg_sales;

-- Tenemos que:
-- ship_mode_vacios     - 1019
-- sales_vacio          - 1529
-- quantity_vacios      - 509
-- profit_vacios        - 1019


-- Ok. Después de comprobar algunas cosas, encontré que los valores seguirán apareciendo 
-- contabilizados como cadenas vacías porque COALESCE(NULL, '') 
-- convierte temporalmente los NULL en cadenas vacías para la comprobación.
-- Teniendo los datos anteriores, checamos si todos son null, 
-- deberían aparecer los mismos valores que en la consulta anterior.
SELECT
    SUM(ship_mode IS NULL) AS ship_mode_null,
    SUM(sales IS NULL)     AS sales_null,
    SUM(quantity IS NULL)  AS quantity_null,
    SUM(profit IS NULL)    AS profit_null
FROM stg_sales;

-- Tenemos que:
-- ship_mode_null     - 1019
-- sales_null         - 1529
-- quantity_null      - 509
-- profit_null        - 1019


-- Comprobemnos que la columna category esté sin espacios en blanco como los tenía antes.
SELECT category,
       COUNT(*) AS total
FROM stg_sales
GROUP BY category
ORDER BY total ASC;
-- Se corrigió perfecto.