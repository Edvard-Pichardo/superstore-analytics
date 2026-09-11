/*
Archivo: 04_data_cleaning_7
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Limpieza y estandarización de los datos almacenados
             en la tabla stg_sales.
            Soluciones a problemas con los códigos postales duplicados en algunas ciudades
            y revisión final. 

*/

USE superstore_analytics;

-- Ahora, comprobemos si un mismo código postal aparece asociado
-- con diferentes ciudades, estados, países o regiones.
WITH consistencia_postal AS
(
    SELECT
        postal_code,
        COUNT(DISTINCT city)      AS total_cities,
        COUNT(DISTINCT state)     AS total_states,
        COUNT(DISTINCT country)   AS total_countries,
        COUNT(DISTINCT region)    AS total_regions
    FROM stg_sales
    WHERE postal_code IS NOT NULL
    GROUP BY postal_code
)

SELECT
    SUM(total_cities > 1)      AS codigos_con_ciudades_inconsistentes,
    SUM(total_states > 1)      AS codigos_con_estados_inconsistentes,
    SUM(total_countries > 1)   AS codigos_con_paises_inconsistentes,
    SUM(total_regions > 1)     AS codigos_con_regiones_inconsistentes
FROM consistencia_postal;

-- Sí, hay un código postal que aparece en más de una ciudad.

-- Mostramos los códigos postales asociados con más de una ciudad, estado, país o región.
SELECT
    postal_code,

    GROUP_CONCAT(
        DISTINCT city
        ORDER BY city
        SEPARATOR ' | '
    ) AS cities,

    GROUP_CONCAT(
        DISTINCT state
        ORDER BY state
        SEPARATOR ' | '
    ) AS states,

    GROUP_CONCAT(
        DISTINCT country
        ORDER BY country
        SEPARATOR ' | '
    ) AS countries,

    GROUP_CONCAT(
        DISTINCT region
        ORDER BY region
        SEPARATOR ' | '
    ) AS regions,

    COUNT(*) AS total_registros

FROM stg_sales
WHERE postal_code IS NOT NULL

GROUP BY postal_code

HAVING COUNT(DISTINCT city) > 1
    OR COUNT(DISTINCT state) > 1
    OR COUNT(DISTINCT country) > 1
    OR COUNT(DISTINCT region) > 1

ORDER BY postal_code;

-- Tenemos que:
-- postal_code: 92024
-- Cities: Encinitas y San Diego
-- State: California
-- Countrie: United State
-- Region: West
-- Registros totales: 39


-- Vamos a revisar cuántas veces aparece cada ciudad asociada con el código postal 92024.
SELECT
    postal_code,
    city,
    state,
    country,
    region,
    COUNT(*) AS total_registros,
    COUNT(DISTINCT order_id) AS total_pedidos,
    COUNT(DISTINCT customer_id) AS total_clientes,
    MIN(order_date) AS primera_aparicion,
    MAX(order_date) AS ultima_aparicion
FROM stg_sales
WHERE postal_code = '92024'
GROUP BY
    postal_code,
    city,
    state,
    country,
    region
ORDER BY total_registros DESC;

-- 34 para San Diego
-- 5 para Encinitas


-- Mostramos los clientes y pedidos asociados con cada ciudad
-- para determinar si se trata de un error aislado o sistemático.
SELECT
    city,
    postal_code,
    customer_id,
    customer_name,
    order_id,
    order_date,
    COUNT(*) AS total_lineas
FROM stg_sales
WHERE postal_code = '92024'
GROUP BY
    city,
    postal_code,
    customer_id,
    customer_name,
    order_id,
    order_date
ORDER BY
    city,
    customer_name,
    order_date,
    order_id;

-- Hay una tendencia hacia San Diego, California que hacia Encinitas. 
-- Buscando en la red, encontré que Encinitas es la ciudad ubicada en el condado de San Diego, California.
-- Por lo que, los registros de San Diego con el código postal 92024 hacen referencia a Encinitas.
-- En particular, es correcto colocar Encinitas y no San Diego.
-- Por lo que, los registros identificados como San Diego se normalizan
-- utilizando Encinitas como ciudad canónica.
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

UPDATE stg_sales
SET city = 'Encinitas'
WHERE postal_code = '92024'
  AND city <> 'Encinitas';

COMMIT;
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;

-- Verificamos la ubicación final asociada con el código postal 92024.
SELECT
    postal_code,
    city,
    state,
    country,
    region,
    COUNT(*) AS total_registros
FROM stg_sales
WHERE postal_code = '92024'
GROUP BY
    postal_code,
    city,
    state,
    country,
    region;


-- Verificamos que no haya algún otro problema relacionado a los códigos postales. 
WITH consistencia_postal AS
(
    SELECT
        postal_code,
        COUNT(DISTINCT city)    AS total_cities,
        COUNT(DISTINCT state)   AS total_states,
        COUNT(DISTINCT country) AS total_countries,
        COUNT(DISTINCT region)  AS total_regions
    FROM stg_sales
    WHERE postal_code IS NOT NULL
    GROUP BY postal_code
)

SELECT
    SUM(total_cities > 1)    AS codigos_con_ciudades_inconsistentes,
    SUM(total_states > 1)    AS codigos_con_estados_inconsistentes,
    SUM(total_countries > 1) AS codigos_con_paises_inconsistentes,
    SUM(total_regions > 1)   AS codigos_con_regiones_inconsistentes
FROM consistencia_postal;



-- Hagamos la verificación final. 
-- Verificamos el volumen, la unicidad de Row ID y las principales
-- reglas de calidad aplicadas durante la limpieza.
SELECT
    COUNT(*) AS total_registros,
    COUNT(DISTINCT row_id) AS row_id_unicos,

    SUM(row_id IS NULL) AS row_id_null,
    SUM(order_id IS NULL) AS order_id_null,
    SUM(customer_id IS NULL) AS customer_id_null,
    SUM(product_id IS NULL) AS product_id_null,

    SUM(
        order_date IS NULL
        OR order_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    ) AS order_dates_invalidas,

    SUM(
        ship_date IS NULL
        OR ship_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    ) AS ship_dates_invalidas,

    SUM(
        order_date IS NOT NULL
        AND ship_date IS NOT NULL
        AND STR_TO_DATE(ship_date, '%Y-%m-%d')
            < STR_TO_DATE(order_date, '%Y-%m-%d')
    ) AS envios_anteriores_al_pedido,

    SUM(
        segment IS NULL
        OR segment NOT IN (
            'Consumer',
            'Corporate',
            'Home Office'
        )
    ) AS segmentos_invalidos,

    SUM(
        category IS NULL
        OR category NOT IN (
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
        discount IS NOT NULL
        AND (
            CAST(discount AS DECIMAL(10, 4)) < 0
            OR CAST(discount AS DECIMAL(10, 4)) > 1
        )
    ) AS descuentos_fuera_de_rango,

    SUM(
        quantity IS NOT NULL
        AND (
            CAST(quantity AS DECIMAL(20, 6)) <= 0
            OR CAST(quantity AS DECIMAL(20, 6))
                <> FLOOR(CAST(quantity AS DECIMAL(20, 6)))
        )
    ) AS cantidades_invalidas

FROM stg_sales;


-- Verificamos que no permanezcan filas completamente duplicadas.
SELECT
    COUNT(*) AS grupos_duplicados
FROM
(
    SELECT
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
) AS duplicados;

-- Quedó perfecto. :D