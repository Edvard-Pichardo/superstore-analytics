/*
Archivo: 04_data_cleaning_3
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Limpieza y estandarización de los datos almacenados
             en la tabla stg_sales.
             Datos faltantes en ship_mode y validación de las columas:
             sales, quantity, discount y profit.  
*/

USE superstore_analytics;

-- En ship_mode hay varias datos faltantes.
-- Como varias filas pertenecen al mismo pedido, podemos recuperar el modo de 
-- envío desde otra línea con el mismo order_id. 
-- Esto solo se puede hacer cuando el pedido tiene un único modo de envío conocido, 
-- así evitamos asignaciones ambiguas. 
SELECT
    COALESCE(ship_mode, '[NULL]') AS ship_mode,
    COUNT(*) AS total
FROM stg_sales
GROUP BY ship_mode
ORDER BY total DESC;

-- Tenemos que:
-- Standar Class    5506
-- Second Class     1786
-- First Class      1400
-- Null             1019
-- Same Day         483
-- Total:           10194

-- Debemos identificar los pedidos que tengan un modo de envío conocido.
DROP TEMPORARY TABLE IF EXISTS tmp_ship_mode_por_pedido;

CREATE TEMPORARY TABLE tmp_ship_mode_por_pedido AS
SELECT
    order_id,
    MAX(ship_mode) AS ship_mode_inferido
FROM stg_sales
WHERE ship_mode IS NOT NULL
GROUP BY order_id
HAVING COUNT(DISTINCT ship_mode) = 1;

-- Calculamos cuántos valores faltantes pueden recuperarse
-- y cuántos permanecerán sin información.
SELECT
    SUM(s.ship_mode IS NULL) AS ship_mode_null_iniciales,

    SUM(
        s.ship_mode IS NULL
        AND t.order_id IS NOT NULL
    ) AS ship_mode_recuperables,

    SUM(
        s.ship_mode IS NULL
        AND t.order_id IS NULL
    ) AS ship_mode_no_recuperables

FROM stg_sales AS s
LEFT JOIN tmp_ship_mode_por_pedido AS t
    ON s.order_id = t.order_id;

-- Tenemos que:
-- 280 valores no se podrán recuperar
-- 739 pueden recuperarse


-- Actualizamos los datos de stg_sales
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

UPDATE stg_sales AS destino
INNER JOIN tmp_ship_mode_por_pedido AS origen
    ON destino.order_id = origen.order_id
SET destino.ship_mode = origen.ship_mode_inferido
WHERE destino.ship_mode IS NULL;

COMMIT;
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;
DROP TEMPORARY TABLE tmp_ship_mode_por_pedido;


-- Verificamos los valores finales de Ship Mode.
SELECT
    COALESCE(ship_mode, '[NULL]') AS ship_mode,
    COUNT(*) AS total
FROM stg_sales
GROUP BY ship_mode
ORDER BY total DESC;

-- Tenemos que:
-- Standar Class    5955
-- Second Class     1922
-- First Class      1509
-- Null             280
-- Same Day         528
-- Total:           10194

-- Contamos los valores que no pudieron recuperarse.
SELECT
    COUNT(*) AS ship_mode_null_restantes
FROM stg_sales
WHERE ship_mode IS NULL;

-- Son 280 modos de envío que no se pudieron recuperar
-- Los NULL restantes corresponden a pedidos donde ninguna fila contiene un modo de envío conocido.


-- Ahora, vamos a validar que las columnas sales, quantity, discount y profit tengan formatos válidos.
-- Específicamente, debemos revisar los valores NULL y los registros que no pueden
-- interpretarse como números decimales.
SELECT
    SUM(sales IS NULL) AS sales_null,
    SUM(
        sales IS NOT NULL
        AND sales NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
    ) AS sales_formato_invalido,

    SUM(quantity IS NULL) AS quantity_null,
    SUM(
        quantity IS NOT NULL
        AND quantity NOT REGEXP '^[0-9]+([.]0+)?$'
    ) AS quantity_formato_invalido,

    SUM(discount IS NULL) AS discount_null,
    SUM(
        discount IS NOT NULL
        AND discount NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
    ) AS discount_formato_invalido,

    SUM(profit IS NULL) AS profit_null,
    SUM(
        profit IS NOT NULL
        AND profit NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
    ) AS profit_formato_invalido
FROM stg_sales;

-- Tenemos que:
-- Sales_null       1529
-- quantity_null    509
-- profit_null      1019
-- Los demás valores se quedaron en cero. 

-- Como se rata de una base de datos de un negocio, tenemos que:
-- sales debe ser mayor que cero.
-- quantity debe ser mayor que cero y representar unidades enteras.
-- discount debe encontrarse entre 0 y 1.
-- profit puede ser positivo, negativo o cero.
-- Revisemos cada uno de estos puntos. 
SELECT
    SUM(
        CAST(sales AS DECIMAL(30, 15)) <= 0
    ) AS sales_no_positivas,

    SUM(
        CAST(quantity AS DECIMAL(30, 15)) <= 0
    ) AS quantity_no_positivas,

    SUM(
        CAST(quantity AS DECIMAL(30, 15))
        <> FLOOR(CAST(quantity AS DECIMAL(30, 15)))
    ) AS quantity_no_enteras,

    SUM(
        CAST(discount AS DECIMAL(30, 15)) < 0
        OR CAST(discount AS DECIMAL(30, 15)) > 1
    ) AS discount_fuera_de_rango

FROM stg_sales;

-- El único dato que sale diferente de cero es discount con 101 registros. 


-- Mostramos los valores de descuento fuera del intervalo permitido.
SELECT
    discount,
    COUNT(*) AS total
FROM stg_sales
WHERE CAST(discount AS DECIMAL(30, 15)) < 0
   OR CAST(discount AS DECIMAL(30, 15)) > 1
GROUP BY discount
ORDER BY total DESC;

-- El único valor diferente de discount es 5.5 con 101 registros.
-- Es decir, se le está haciendo un descuento del 550%.
-- Esto puede ser un error de captura o de escala, así que supondré que, en lugar de 5.5 se quería 0.55
SELECT
    discount AS discount_original,
    CASE
        WHEN CAST(discount AS DECIMAL(10, 4)) = 5.5
            THEN '0.55'
        ELSE discount
    END AS discount_corregido,
    COUNT(*) AS total_registros
FROM stg_sales
GROUP BY
    discount,
    CASE
        WHEN CAST(discount AS DECIMAL(10, 4)) = 5.5
            THEN '0.55'
        ELSE discount
    END
ORDER BY CAST(discount AS DECIMAL(10, 4));

-- Esto soluciona este error. 
-- nos queda actualizar stg_sales con estos valores. 
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

UPDATE stg_sales
SET discount = '0.55'
WHERE CAST(discount AS DECIMAL(10, 4)) = 5.5;

COMMIT;
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;


-- Verificamos que no existan descuentos fuera del intervalo (0, 1).
SELECT
    COUNT(*) AS descuentos_fuera_de_rango
FROM stg_sales
WHERE discount IS NOT NULL
  AND (
        CAST(discount AS DECIMAL(10, 4)) < 0
        OR CAST(discount AS DECIMAL(10, 4)) > 1
      );
-- Quedó perfecto, ya no existen descuentos fuera del rango. 

-- Confirmamos la distribución final
SELECT
    discount,
    COUNT(*) AS total
FROM stg_sales
GROUP BY discount
ORDER BY CAST(discount AS DECIMAL(10, 4));

-- En la distribución aparece el descuento de 0.55 con 101 registros, tal como se esperaba. 