/*
Archivo: 04_data_cleaning_4
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Limpieza y estandarización de los datos almacenados
             en la tabla stg_sales.
            Valores faltantes en sales, quantity y profit.
            Recuperación de algunos valores de sales y quantity. 
*/

USE superstore_analytics;

-- Ahora, anteriormente vimos que había valores nulos en las columnas sales, quantity y profit.
-- Hagamos un análisis más profundo. Queremos saber cuántos registros del total están completos. 
-- Así como la combinación de sales, quantity y profit para ver si podemos calcular algunos de los datos faltantes.
SELECT
    COUNT(*) AS total_registros,

    SUM(
        sales IS NOT NULL
        AND quantity IS NOT NULL
        AND profit IS NOT NULL
    ) AS registros_completos,

    SUM(
        sales IS NULL
        AND quantity IS NOT NULL
        AND profit IS NOT NULL
    ) AS solo_sales_null,

    SUM(
        sales IS NOT NULL
        AND quantity IS NULL
        AND profit IS NOT NULL
    ) AS solo_quantity_null,

    SUM(
        sales IS NOT NULL
        AND quantity IS NOT NULL
        AND profit IS NULL
    ) AS solo_profit_null,

    SUM(
        sales IS NULL
        AND quantity IS NULL
        AND profit IS NOT NULL
    ) AS sales_quantity_null,

    SUM(
        sales IS NULL
        AND quantity IS NOT NULL
        AND profit IS NULL
    ) AS sales_profit_null,

    SUM(
        sales IS NOT NULL
        AND quantity IS NULL
        AND profit IS NULL
    ) AS quantity_profit_null,

    SUM(
        sales IS NULL
        AND quantity IS NULL
        AND profit IS NULL
    ) AS sales_quantity_profit_null

FROM stg_sales;

-- Tenemos que:
-- Total registros          10194
-- Registros completos      7420
-- Sales                    1292
-- Quantity                 388
-- Profit                   819
-- Sales y quantity         75
-- Sales y profit           154
-- Quantity y profit        38
-- Sales, quantity y profit 8


-- Mostramos los registros donde faltan las tres métricas principales.
SELECT
    row_id,
    order_id,
    product_id,
    product_name,
    discount,
    sales,
    quantity,
    profit
FROM stg_sales
WHERE sales IS NULL
  AND quantity IS NULL
  AND profit IS NULL
ORDER BY row_id;
-- En estos registros no se puede recuperar ninguna de las tres métricas porque falta información.
-- En una empresa real, esto debería reportarse.


-- Ahora, vamos a identificar las métricas que se pueden recuperar o caluclar a partir de las otras dos.
-- En este caso, si sabemos la cantidad de productos vendida y el precio unitario del producto,
-- podemos recuperar las ventas calculadas.
-- Igualmente, podemos recuperar la cantidad de unidades vendidas si conocemos las ventas y el precio unitario
-- del producto.
-- Eliminamos la tabla temporal si existe por una ejecución anterior.
DROP TEMPORARY TABLE IF EXISTS tmp_precio_unitario_producto;

-- Debemos calcular el precio de venta unitario observado para cada combinación de producto y descuento.
-- Solo conservamos las combinaciones que tienen un único precio unitario en todo el dataset, 
-- así evitamos ambiguedades.
CREATE TEMPORARY TABLE tmp_precio_unitario_producto AS
SELECT
    product_id,
    CAST(discount AS DECIMAL(10, 4)) AS discount,
    MIN(
        ROUND(
            CAST(sales AS DECIMAL(20, 6))
            / CAST(quantity AS DECIMAL(20, 6)),
            6
        )
    ) AS precio_unitario
FROM stg_sales
WHERE sales IS NOT NULL
  AND quantity IS NOT NULL
  AND discount IS NOT NULL
  AND CAST(quantity AS DECIMAL(20, 6)) > 0
GROUP BY
    product_id,
    CAST(discount AS DECIMAL(10, 4))
HAVING COUNT(
    DISTINCT ROUND(
        CAST(sales AS DECIMAL(20, 6))
        / CAST(quantity AS DECIMAL(20, 6)),
        6
    )
) = 1;

-- Calculamos cuántos valores faltantes pueden recuperarse mediante un precio unitario conocido y no ambiguo.
SELECT
    SUM(
        s.sales IS NULL
        AND s.quantity IS NOT NULL
        AND p.product_id IS NOT NULL
    ) AS sales_recuperables,

    SUM(
        s.quantity IS NULL
        AND s.sales IS NOT NULL
        AND p.product_id IS NOT NULL
        AND p.precio_unitario > 0
        AND ABS(
            CAST(s.sales AS DECIMAL(20, 6))
            / p.precio_unitario
            - ROUND(
                CAST(s.sales AS DECIMAL(20, 6))
                / p.precio_unitario
            )
        ) < 0.000001
    ) AS quantity_recuperables

FROM stg_sales AS s
LEFT JOIN tmp_precio_unitario_producto AS p
    ON s.product_id = p.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = p.discount;

-- Tenemos que:
-- sales_recuperables       1061
-- quantity_recuperables    321


-- Podemos mostrar algunos ejemplos de sales que podrían recuperarse.
SELECT
    s.row_id,
    s.product_id,
    s.discount,
    s.quantity,
    p.precio_unitario,
    s.sales AS sales_original,
    ROUND(
        CAST(s.quantity AS DECIMAL(20, 6))
        * p.precio_unitario,
        6
    ) AS sales_calculado
FROM stg_sales AS s
INNER JOIN tmp_precio_unitario_producto AS p
    ON s.product_id = p.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = p.discount
WHERE s.sales IS NULL
  AND s.quantity IS NOT NULL
LIMIT 20;


-- También podemos mostrar ejemplos de quantity que podrían recuperarse.
SELECT
    s.row_id,
    s.product_id,
    s.discount,
    s.sales,
    p.precio_unitario,
    s.quantity AS quantity_original,
    ROUND(
        CAST(s.sales AS DECIMAL(20, 6))
        / p.precio_unitario
    ) AS quantity_calculada
FROM stg_sales AS s
INNER JOIN tmp_precio_unitario_producto AS p
    ON s.product_id = p.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = p.discount
WHERE s.quantity IS NULL
  AND s.sales IS NOT NULL
  AND p.precio_unitario > 0
  AND ABS(
        CAST(s.sales AS DECIMAL(20, 6))
        / p.precio_unitario
        - ROUND(
            CAST(s.sales AS DECIMAL(20, 6))
            / p.precio_unitario
        )
      ) < 0.000001
LIMIT 20;


-- teniendo esto, podemos actualizar stg_sales
SET @sql_safe_updates_previo = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;
START TRANSACTION;

-- Primero calculamos sales multiplicando la cantidad vendida por el
-- precio unitario del mismo producto y descuento.
UPDATE stg_sales AS s
INNER JOIN tmp_precio_unitario_producto AS p
    ON s.product_id = p.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = p.discount
SET s.sales = CAST(
    ROUND(
        CAST(s.quantity AS DECIMAL(20, 6))
        * p.precio_unitario,
        6
    ) AS CHAR
)
WHERE s.sales IS NULL
  AND s.quantity IS NOT NULL;


-- Después, calculamos quantity dividiendo sales entre el precio unitario del producto.
-- Como medida extra de seguridad, solo actualizamos cuando el resultado es positivo 
-- y corresponde prácticamente a un número entero.
UPDATE stg_sales AS s
INNER JOIN tmp_precio_unitario_producto AS p
    ON s.product_id = p.product_id
   AND CAST(s.discount AS DECIMAL(10, 4)) = p.discount
SET s.quantity = CAST(
    ROUND(
        CAST(s.sales AS DECIMAL(20, 6))
        / p.precio_unitario
    ) AS CHAR
)
WHERE s.quantity IS NULL
  AND s.sales IS NOT NULL
  AND p.precio_unitario > 0
  AND ROUND(
        CAST(s.sales AS DECIMAL(20, 6))
        / p.precio_unitario
      ) > 0
  AND ABS(
        CAST(s.sales AS DECIMAL(20, 6))
        / p.precio_unitario
        - ROUND(
            CAST(s.sales AS DECIMAL(20, 6))
            / p.precio_unitario
        )
      ) < 0.000001;

COMMIT;
SET SQL_SAFE_UPDATES = @sql_safe_updates_previo;


-- Comprobamos cuántos valores faltantes permanecen.
SELECT
    SUM(sales IS NULL) AS sales_null_restantes,
    SUM(quantity IS NULL) AS quantity_null_restantes
FROM stg_sales;

-- Tenemos que:
-- Sales    468
-- Quantity 188
-- Ambas menores a lo que se tenía antes. 


-- Comprobamos que las cantidades recuperadas sigan siendo positivas y enteras.
SELECT
    SUM(
        quantity IS NOT NULL
        AND CAST(quantity AS DECIMAL(20, 6)) <= 0
    ) AS cantidades_no_positivas,

    SUM(
        quantity IS NOT NULL
        AND CAST(quantity AS DECIMAL(20, 6))
            <> FLOOR(CAST(quantity AS DECIMAL(20, 6)))
    ) AS cantidades_no_enteras
FROM stg_sales;
-- Quedaron perfectas. No hay ningún inconveniente con ninguno de los datos. 

-- Eliminamos la tabla temporal
DROP TEMPORARY TABLE IF EXISTS tmp_precio_unitario_producto;