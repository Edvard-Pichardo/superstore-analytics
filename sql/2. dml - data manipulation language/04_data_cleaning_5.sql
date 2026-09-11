/*
Archivo: 04_data_cleaning_5
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Limpieza y estandarización de los datos almacenados
             en la tabla stg_sales.
             Recuperación de algunos valores faltantes de profit.
             Chequeó de consistencia de fechas de envío y consistencia de los datos relacionados
             al customer_id.
*/

USE superstore_analytics;

-- Eliminamos la yabla temporal en caso de que exista de alguna interacción anterior.
DROP TEMPORARY TABLE IF EXISTS tmp_margen_producto;

-- Debemos ver qué valores de profit podemos recuperar. 
-- Para ello, calculamos el margen observado para cada combinación de producto y descuento.
-- Solo vamos a conservar combinaciones con al menos dos registros completos 
-- y un margen único, evitando imputaciones ambiguas.
CREATE TEMPORARY TABLE tmp_margen_producto AS
SELECT
    product_id,
    CAST(discount AS DECIMAL(10, 4)) AS discount,

    MIN(
        ROUND(
            CAST(profit AS DECIMAL(30, 15))
            / CAST(sales AS DECIMAL(30, 15)),
            10
        )
    ) AS margen_profit

FROM stg_sales
WHERE product_id IS NOT NULL
  AND discount IS NOT NULL
  AND sales IS NOT NULL
  AND profit IS NOT NULL
  AND CAST(sales AS DECIMAL(30, 15)) <> 0

GROUP BY
    product_id,
    CAST(discount AS DECIMAL(10, 4))

HAVING COUNT(*) >= 2
   AND COUNT(
        DISTINCT ROUND(
            CAST(profit AS DECIMAL(30, 15))
            / CAST(sales AS DECIMAL(30, 15)),
            10
        )
   ) = 1;


-- Calculamos cuántos valores faltantes de Profit pueden recuperarse mediante 
-- algun margen conocido.
SELECT
    SUM(s.profit IS NULL) AS profit_null_actuales,

    SUM(
        s.profit IS NULL
        AND s.sales IS NOT NULL
        AND m.product_id IS NOT NULL
    ) AS profit_recuperables,

    SUM(
        s.profit IS NULL
        AND (
            s.sales IS NULL
            OR m.product_id IS NULL
        )
    ) AS profit_no_recuperables

FROM stg_sales AS s
LEFT JOIN tmp_margen_producto AS m
    ON s.product_id = m.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = m.discount;

-- Tenemos que:
-- profit_null_actuales     1019
-- profit_recuperables      521
-- profit_no_recuperables   498


-- Mostramos ejemplos de los valores que podrían recuperarse.
SELECT
    s.row_id,
    s.product_id,
    s.discount,
    s.sales,
    s.quantity,
    s.profit AS profit_original,
    m.margen_profit,

    ROUND(
        CAST(s.sales AS DECIMAL(30, 15))
        * m.margen_profit,
        6
    ) AS profit_calculado

FROM stg_sales AS s
INNER JOIN tmp_margen_producto AS m
    ON s.product_id = m.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = m.discount

WHERE s.profit IS NULL
  AND s.sales IS NOT NULL

LIMIT 20;


-- Actualizamos la tabla stg_sales.
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

-- Calculamos profit multiplicando sales por el margen observado para el mismo producto y descuento.
UPDATE stg_sales AS s
INNER JOIN tmp_margen_producto AS m
    ON s.product_id = m.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = m.discount
SET s.profit = CAST(
    ROUND(
        CAST(s.sales AS DECIMAL(30, 15))
        * m.margen_profit,
        6
    ) AS CHAR
)
WHERE s.profit IS NULL
  AND s.sales IS NOT NULL;

COMMIT;
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;


-- Verificamos cuántos valores faltantes de Profit permanecen.
SELECT
    SUM(profit IS NULL) AS profit_null_restantes
FROM stg_sales;

-- profit null restantes - 498

-- Validamos que todos los valores no nulos tengan formato numérico.
SELECT
    SUM(
        profit IS NOT NULL
        AND profit NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
    ) AS profit_formato_invalido
FROM stg_sales;
-- No hay error de formato en este caso. 

DROP TEMPORARY TABLE IF EXISTS tmp_margen_producto;


-- Ahora, aunque lo debí hacer antes, debemos revisar que el formato de fecha de
-- ship_date tengan el mismo formato: YYYY-MM-DD
SELECT
    COUNT(*) AS ship_dates_formato_invalido
FROM stg_sales
WHERE ship_date IS NULL
   OR ship_date NOT REGEXP
        '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';

-- En este caso no hay ningún formato inválido. 
-- De haberlo tenido, podría tratarse igual a como se hizo con order_date.

-- Verificamos que las fechas de envío puedan convertirse correctamente al tipo DATE.
SELECT
    COUNT(*) AS ship_dates_no_validas
FROM stg_sales
WHERE ship_date IS NOT NULL
  AND STR_TO_DATE(ship_date, '%Y-%m-%d') IS NULL;

-- Todo en orden. 

-- Un error que podría venir es que la fecha de envío sea anterior a la fehca del pedido.
-- Revisamos que eso no suceda.
SELECT
    COUNT(*) AS envios_anteriores_al_pedido
FROM stg_sales
WHERE order_date IS NOT NULL
  AND ship_date IS NOT NULL
  AND STR_TO_DATE(ship_date, '%Y-%m-%d')
      < STR_TO_DATE(order_date, '%Y-%m-%d');

-- Todo está perfecto. Si hubiera alguna clase de inconsistencia podríamos mostrar 
-- cuáles son los registros problematicos, auqnue no es el caso. 
SELECT
    row_id,
    order_id,
    order_date,
    ship_date,
    ship_mode
FROM stg_sales
WHERE order_date IS NOT NULL
  AND ship_date IS NOT NULL
  AND STR_TO_DATE(ship_date, '%Y-%m-%d')
      < STR_TO_DATE(order_date, '%Y-%m-%d')
ORDER BY
    order_date,
    ship_date;


-- Ahora, calculemos el intervalo mínimo, máximo y promedio
-- entre la fecha del pedido y la fecha de envío.
SELECT
    MIN(
        DATEDIFF(
            STR_TO_DATE(ship_date, '%Y-%m-%d'),
            STR_TO_DATE(order_date, '%Y-%m-%d')
        )
    ) AS dias_envio_minimos,

    MAX(
        DATEDIFF(
            STR_TO_DATE(ship_date, '%Y-%m-%d'),
            STR_TO_DATE(order_date, '%Y-%m-%d')
        )
    ) AS dias_envio_maximos,

    ROUND(
        AVG(
            DATEDIFF(
                STR_TO_DATE(ship_date, '%Y-%m-%d'),
                STR_TO_DATE(order_date, '%Y-%m-%d')
            )
        ),
        2
    ) AS dias_envio_promedio

FROM stg_sales
WHERE order_date IS NOT NULL
  AND ship_date IS NOT NULL;

-- Tenemos que:
-- Días de envío mínimos: 0 días
-- Días de envío máximo: 11 días
-- Días de envío promedio: 3.96 días


-- Comprobamos si un mismo customer_id está asociado con más de un nombre de cliente.
SELECT
    COUNT(*) AS clientes_con_nombres_inconsistentes
FROM
(
    SELECT
        customer_id
    FROM stg_sales
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
    HAVING COUNT(DISTINCT customer_name) > 1
) AS clientes_inconsistentes;

-- No, todos los clientes tienen nombres consistentes con el customer_id.

-- Comprobamos si un mismo customer_id está asociado con más de un segmento.
SELECT
    COUNT(*) AS clientes_con_segmentos_inconsistentes
FROM
(
    SELECT
        customer_id
    FROM stg_sales
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
    HAVING COUNT(DISTINCT segment) > 1
) AS clientes_inconsistentes;

-- No, el customer_id también es consistente con los segmentos. 

-- En dado caso de que hubiera uno, podríamos mostrar los datos problemáticos, auqnue no es el caso.

-- Para los clientes asociados con más de un nombre.
SELECT
    customer_id,
    GROUP_CONCAT(
        DISTINCT customer_name
        ORDER BY customer_name
        SEPARATOR ' | '
    ) AS nombres_encontrados,
    COUNT(DISTINCT customer_name) AS total_nombres
FROM stg_sales
WHERE customer_id IS NOT NULL
GROUP BY customer_id
HAVING COUNT(DISTINCT customer_name) > 1
ORDER BY customer_id;

-- Para los clientes asociados con más de un segmento.
SELECT
    customer_id,
    GROUP_CONCAT(
        DISTINCT segment
        ORDER BY segment
        SEPARATOR ' | '
    ) AS segmentos_encontrados,
    COUNT(DISTINCT segment) AS total_segmentos
FROM stg_sales
WHERE customer_id IS NOT NULL
GROUP BY customer_id
HAVING COUNT(DISTINCT segment) > 1
ORDER BY customer_id;