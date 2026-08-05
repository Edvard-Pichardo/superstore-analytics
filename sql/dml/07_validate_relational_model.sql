/*
Archivo      : 07_validate_relational_model.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Validación de integridad y conciliación entre
               clean_sales y el modelo relacional.
*/

USE superstore_analytics;



-- Conciliación de cantidades

-- Comparamos las entidades únicas presentes en clean_sales
-- con las filas almacenadas en cada tabla relacional.

-- Los valores esperados se calculan directamente desde
-- clean_sales para evitar depender de cifras escritas manualmente.
WITH controles AS
(
    -- Segmentos
    SELECT
        'Segmentos' AS control,
        (
            SELECT COUNT(DISTINCT segment)
            FROM clean_sales
            WHERE segment IS NOT NULL
        ) AS valor_esperado,
        (
            SELECT COUNT(*)
            FROM segments
        ) AS valor_obtenido

    UNION ALL
    -- Modos de envío conocidos
    SELECT
        'Modos de envío',
        (
            SELECT COUNT(DISTINCT ship_mode)
            FROM clean_sales
            WHERE ship_mode IS NOT NULL
        ),
        (
            SELECT COUNT(*)
            FROM ship_modes
        )

    UNION ALL
    -- Regiones
    SELECT
        'Regiones',
        (
            SELECT COUNT(DISTINCT region)
            FROM clean_sales
            WHERE region IS NOT NULL
        ),
        (
            SELECT COUNT(*)
            FROM regions
        )

    UNION ALL
    -- Categorías
    SELECT
        'Categorías',
        (
            SELECT COUNT(DISTINCT category)
            FROM clean_sales
            WHERE category IS NOT NULL
        ),
        (
            SELECT COUNT(*)
            FROM categories
        )

    UNION ALL
    -- Combinaciones únicas de categoría y subcategoría
    SELECT
        'Subcategorías',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT
                    category,
                    sub_category
                FROM clean_sales
                GROUP BY
                    category,
                    sub_category
            ) AS subcategorias_unicas
        ),
        (
            SELECT COUNT(*)
            FROM sub_categories
        )

    UNION ALL
    -- Ubicaciones únicas
    SELECT
        'Ubicaciones',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT
                    country,
                    state,
                    city,
                    postal_code,
                    region
                FROM clean_sales
                GROUP BY
                    country,
                    state,
                    city,
                    postal_code,
                    region
            ) AS ubicaciones_unicas
        ),
        (
            SELECT COUNT(*)
            FROM locations
        )

    UNION ALL
    -- Clientes únicos
    SELECT
        'Clientes',
        (
            SELECT COUNT(DISTINCT customer_id)
            FROM clean_sales
        ),
        (
            SELECT COUNT(*)
            FROM customers
        )

    UNION ALL
    -- Productos únicos según código y nombre
    SELECT
        'Productos',
        (
            SELECT COUNT(DISTINCT product_id, product_name)
            FROM clean_sales
        ),
        (
            SELECT COUNT(*)
            FROM products
        )

    UNION ALL
    -- Pedidos lógicos normalizados
    SELECT
        'Pedidos',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT
                    order_id,
                    customer_id,
                    country,
                    state,
                    city,
                    postal_code,
                    region
                FROM clean_sales
                GROUP BY
                    order_id,
                    customer_id,
                    country,
                    state,
                    city,
                    postal_code,
                    region
            ) AS pedidos_unicos
        ),
        (
            SELECT COUNT(*)
            FROM orders
        )

    UNION ALL
    -- Líneas de venta
    SELECT
        'Detalles de pedidos',
        (
            SELECT COUNT(*)
            FROM clean_sales
        ),
        (
            SELECT COUNT(*)
            FROM order_details
        )
)

SELECT
    control,
    valor_esperado,
    valor_obtenido,
    valor_obtenido - valor_esperado AS diferencia,

    CASE
        WHEN valor_esperado = valor_obtenido
            THEN 'OK'
        ELSE 'REVISAR'
    END AS estado

FROM controles

ORDER BY
    CASE control
        WHEN 'Segmentos' THEN 1
        WHEN 'Modos de envío' THEN 2
        WHEN 'Regiones' THEN 3
        WHEN 'Categorías' THEN 4
        WHEN 'Subcategorías' THEN 5
        WHEN 'Ubicaciones' THEN 6
        WHEN 'Clientes' THEN 7
        WHEN 'Productos' THEN 8
        WHEN 'Pedidos' THEN 9
        WHEN 'Detalles de pedidos' THEN 10
    END;




-- Validación de integridad referencial

-- Comprobamos que todas las claves foráneas tengan
-- correspondencia en sus respectivas tablas principales.
WITH controles AS
(
    -- Subcategorías sin categoría válida.
    SELECT
        'Subcategorías sin categoría' AS control,
        COUNT(*) AS registros_invalidos
    FROM sub_categories AS sc
    LEFT JOIN categories AS c
        ON c.category_id = sc.category_id
    WHERE c.category_id IS NULL

    UNION ALL
    -- Ubicaciones sin región válida.
    SELECT
        'Ubicaciones sin región',
        COUNT(*)
    FROM locations AS l
    LEFT JOIN regions AS r
        ON r.region_id = l.region_id
    WHERE r.region_id IS NULL

    UNION ALL
    -- Clientes sin segmento válido.
    SELECT
        'Clientes sin segmento',
        COUNT(*)
    FROM customers AS c
    LEFT JOIN segments AS s
        ON s.segment_id = c.segment_id
    WHERE s.segment_id IS NULL

    UNION ALL
    -- Productos sin subcategoría válida.
    SELECT
        'Productos sin subcategoría',
        COUNT(*)
    FROM products AS p
    LEFT JOIN sub_categories AS sc
        ON sc.sub_category_id = p.sub_category_id
    WHERE sc.sub_category_id IS NULL

    UNION ALL
    -- Pedidos sin cliente válido.
    SELECT
        'Pedidos sin cliente',
        COUNT(*)
    FROM orders AS o
    LEFT JOIN customers AS c
        ON c.customer_id = o.customer_id
    WHERE c.customer_id IS NULL

    UNION ALL
    -- Pedidos sin ubicación válida.
    SELECT
        'Pedidos sin ubicación',
        COUNT(*)
    FROM orders AS o
    LEFT JOIN locations AS l
        ON l.location_id = o.location_id
    WHERE l.location_id IS NULL

    UNION ALL
    -- Pedidos con un modo de envío no reconocido.
    -- Los valores NULL son válidos porque representan
    -- modos de envío desconocidos.
    SELECT
        'Pedidos con modo de envío inválido',
        COUNT(*)
    FROM orders AS o
    LEFT JOIN ship_modes AS sm
        ON sm.ship_mode_id = o.ship_mode_id
    WHERE o.ship_mode_id IS NOT NULL
      AND sm.ship_mode_id IS NULL

    UNION ALL
    -- Detalles sin pedido válido.
    SELECT
        'Detalles sin pedido',
        COUNT(*)
    FROM order_details AS od
    LEFT JOIN orders AS o
        ON o.order_key = od.order_key
    WHERE o.order_key IS NULL

    UNION ALL
    -- Detalles sin producto válido.
    SELECT
        'Detalles sin producto',
        COUNT(*)
    FROM order_details AS od
    LEFT JOIN products AS p
        ON p.product_key = od.product_key
    WHERE p.product_key IS NULL
)

SELECT
    control,
    registros_invalidos,

    CASE
        WHEN registros_invalidos = 0
            THEN 'OK'
        ELSE 'REVISAR'
    END AS estado

FROM controles

ORDER BY control;




-- Validación de claves únicas y duplicados

-- Buscamos grupos duplicados en las columnas que identifican
-- de manera única a cada entidad del modelo relacional.

WITH controles AS
(
    -- Nombres de segmentos repetidos.
    SELECT
        'Nombres de segmento duplicados' AS control,
        COUNT(*) AS grupos_duplicados
    FROM
    (
        SELECT
            segment_name
        FROM segments
        GROUP BY segment_name
        HAVING COUNT(*) > 1
    ) AS duplicados

    UNION ALL
    -- Nombres de modos de envío repetidos.
    SELECT
        'Nombres de modo de envío duplicados',
        COUNT(*)
    FROM
    (
        SELECT
            ship_mode_name
        FROM ship_modes
        GROUP BY ship_mode_name
        HAVING COUNT(*) > 1
    ) AS duplicados

    UNION ALL
    -- Nombres de regiones repetidos.
    SELECT
        'Nombres de región duplicados',
        COUNT(*)
    FROM
    (
        SELECT
            region_name
        FROM regions
        GROUP BY region_name
        HAVING COUNT(*) > 1
    ) AS duplicados

    UNION ALL
    -- Nombres de categorías repetidos.
    SELECT
        'Nombres de categoría duplicados',
        COUNT(*)
    FROM
    (
        SELECT
            category_name
        FROM categories
        GROUP BY category_name
        HAVING COUNT(*) > 1
    ) AS duplicados

    UNION ALL
    -- Subcategorías repetidas dentro de una misma categoría.
    SELECT
        'Subcategorías duplicadas por categoría',
        COUNT(*)
    FROM
    (
        SELECT
            category_id,
            sub_category_name
        FROM sub_categories
        GROUP BY
            category_id,
            sub_category_name
        HAVING COUNT(*) > 1
    ) AS duplicados

    UNION ALL
    -- Ubicaciones geográficas repetidas.
    SELECT
        'Ubicaciones duplicadas',
        COUNT(*)
    FROM
    (
        SELECT
            region_id,
            country,
            state,
            city,
            postal_code
        FROM locations
        GROUP BY
            region_id,
            country,
            state,
            city,
            postal_code
        HAVING COUNT(*) > 1
    ) AS duplicados

    UNION ALL
    -- Identificadores de clientes repetidos.
    SELECT
        'Identificadores de cliente duplicados',
        COUNT(*)
    FROM
    (
        SELECT
            customer_id
        FROM customers
        GROUP BY customer_id
        HAVING COUNT(*) > 1
    ) AS duplicados

    UNION ALL
    -- Combinaciones repetidas de código y nombre de producto.
    SELECT
        'Productos duplicados por código y nombre',
        COUNT(*)
    FROM
    (
        SELECT
            source_product_id,
            product_name
        FROM products
        GROUP BY
            source_product_id,
            product_name
        HAVING COUNT(*) > 1
    ) AS duplicados

    UNION ALL
    -- Pedidos repetidos según su clave de negocio.
    SELECT
        'Pedidos lógicos duplicados',
        COUNT(*)
    FROM
    (
        SELECT
            source_order_id,
            customer_id,
            location_id
        FROM orders
        GROUP BY
            source_order_id,
            customer_id,
            location_id
        HAVING COUNT(*) > 1
    ) AS duplicados

    UNION ALL
    -- Identificadores originales de líneas repetidos.
    SELECT
        'Identificadores de fila duplicados',
        COUNT(*)
    FROM
    (
        SELECT
            source_row_id
        FROM order_details
        GROUP BY source_row_id
        HAVING COUNT(*) > 1
    ) AS duplicados
)

SELECT
    control,
    grupos_duplicados,

    CASE
        WHEN grupos_duplicados = 0
            THEN 'OK'
        ELSE 'REVISAR'
    END AS estado

FROM controles

ORDER BY control;




-- Validación de reglas de negocio

-- Comprobamos fechas, métricas comerciales e identificadores.
-- Los valores NULL de sales, quantity y profit son válidos
-- cuando no fue posible recuperarlos con evidencia suficiente.

WITH controles AS
(
    -- La fecha de envío no puede ser anterior
    -- a la fecha del pedido.
    SELECT
        'Pedidos con fecha de envío anterior al pedido'
            AS control,
        COUNT(*) AS registros_invalidos
    FROM orders
    WHERE ship_date < order_date

    UNION ALL
    -- Las fechas obligatorias no pueden ser NULL.
    SELECT
        'Pedidos con fecha del pedido nula',
        COUNT(*)
    FROM orders
    WHERE order_date IS NULL

    UNION ALL

    SELECT
        'Pedidos con fecha de envío nula',
        COUNT(*)
    FROM orders
    WHERE ship_date IS NULL

    UNION ALL
    -- Las ventas conocidas deben ser mayores que cero.
    -- Los valores NULL permanecen permitidos.
    SELECT
        'Detalles con ventas no positivas',
        COUNT(*)
    FROM order_details
    WHERE sales IS NOT NULL
      AND sales <= 0

    UNION ALL
    -- Las cantidades conocidas deben ser mayores que cero.
    SELECT
        'Detalles con cantidades no positivas',
        COUNT(*)
    FROM order_details
    WHERE quantity IS NOT NULL
      AND quantity <= 0

    UNION ALL
    -- El descuento es obligatorio y debe encontrarse
    -- dentro del intervalo de 0 a 1.
    SELECT
        'Detalles con descuento nulo',
        COUNT(*)
    FROM order_details
    WHERE discount IS NULL

    UNION ALL

    SELECT
        'Detalles con descuento fuera de rango',
        COUNT(*)
    FROM order_details
    WHERE discount < 0
       OR discount > 1

    UNION ALL
    -- Los identificadores originales deben ser positivos.
    SELECT
        'Detalles con identificador de fila no positivo',
        COUNT(*)
    FROM order_details
    WHERE source_row_id <= 0
)

SELECT
    control,
    registros_invalidos,

    CASE
        WHEN registros_invalidos = 0
            THEN 'OK'
        ELSE 'REVISAR'
    END AS estado

FROM controles

ORDER BY control;


-- Diagnóstico informativo

-- Los resultados de esta consulta pueden ser mayores que cero
-- sin representar errores de integridad.
SELECT
    COUNT(*) AS total_detalles,

    SUM(
        CASE
            WHEN sales IS NULL THEN 1
            ELSE 0
        END
    ) AS ventas_desconocidas,

    SUM(
        CASE
            WHEN quantity IS NULL THEN 1
            ELSE 0
        END
    ) AS cantidades_desconocidas,

    SUM(
        CASE
            WHEN profit IS NULL THEN 1
            ELSE 0
        END
    ) AS beneficios_desconocidos,

    SUM(
        CASE
            WHEN profit < 0 THEN 1
            ELSE 0
        END
    ) AS operaciones_con_perdida,

    SUM(
        CASE
            WHEN profit = 0 THEN 1
            ELSE 0
        END
    ) AS operaciones_sin_beneficio

FROM order_details;


-- Los pedidos con ship_mode_id NULL se conservaron porque
-- no existía evidencia suficiente para completar el dato.
SELECT
    COUNT(*) AS total_pedidos,
    SUM(
        CASE
            WHEN ship_mode_id IS NULL THEN 1
            ELSE 0
        END
    ) AS modos_envio_desconocidos
FROM orders;




-- Conciliación de métricas y valores nulos

-- Comparamos las métricas de clean_sales con las almacenadas
-- en order_details.

-- Además de los totales, verificamos que los valores NULL
-- se hayan conservado y no se hayan convertido en cero.
WITH metricas_clean AS
(
    SELECT
        COUNT(*) AS total_filas,
        COUNT(sales) AS ventas_conocidas,
        COUNT(quantity) AS cantidades_conocidas,
        COUNT(profit) AS beneficios_conocidos,

        SUM(sales IS NULL) AS ventas_desconocidas,
        SUM(quantity IS NULL) AS cantidades_desconocidas,
        SUM(profit IS NULL) AS beneficios_desconocidos,

        SUM(sales) AS total_ventas,
        SUM(quantity) AS total_cantidad,
        SUM(discount) AS total_descuento,
        SUM(profit) AS total_beneficio
    FROM clean_sales
),

metricas_modelo AS
(
    SELECT
        COUNT(*) AS total_filas,
        COUNT(sales) AS ventas_conocidas,
        COUNT(quantity) AS cantidades_conocidas,
        COUNT(profit) AS beneficios_conocidos,

        SUM(sales IS NULL) AS ventas_desconocidas,
        SUM(quantity IS NULL) AS cantidades_desconocidas,
        SUM(profit IS NULL) AS beneficios_desconocidos,

        SUM(sales) AS total_ventas,
        SUM(quantity) AS total_cantidad,
        SUM(discount) AS total_descuento,
        SUM(profit) AS total_beneficio
    FROM order_details
),

controles AS
(
    SELECT
        'Total de filas' AS control,
        mc.total_filas AS valor_esperado,
        mm.total_filas AS valor_obtenido
    FROM metricas_clean AS mc
    CROSS JOIN metricas_modelo AS mm

    UNION ALL

    SELECT
        'Ventas conocidas',
        mc.ventas_conocidas,
        mm.ventas_conocidas
    FROM metricas_clean AS mc
    CROSS JOIN metricas_modelo AS mm

    UNION ALL

    SELECT
        'Ventas desconocidas',
        mc.ventas_desconocidas,
        mm.ventas_desconocidas
    FROM metricas_clean AS mc
    CROSS JOIN metricas_modelo AS mm

    UNION ALL

    SELECT
        'Cantidades conocidas',
        mc.cantidades_conocidas,
        mm.cantidades_conocidas
    FROM metricas_clean AS mc
    CROSS JOIN metricas_modelo AS mm

    UNION ALL

    SELECT
        'Cantidades desconocidas',
        mc.cantidades_desconocidas,
        mm.cantidades_desconocidas
    FROM metricas_clean AS mc
    CROSS JOIN metricas_modelo AS mm

    UNION ALL

    SELECT
        'Beneficios conocidos',
        mc.beneficios_conocidos,
        mm.beneficios_conocidos
    FROM metricas_clean AS mc
    CROSS JOIN metricas_modelo AS mm

    UNION ALL

    SELECT
        'Beneficios desconocidos',
        mc.beneficios_desconocidos,
        mm.beneficios_desconocidos
    FROM metricas_clean AS mc
    CROSS JOIN metricas_modelo AS mm

    UNION ALL

    SELECT
        'Total de ventas',
        mc.total_ventas,
        mm.total_ventas
    FROM metricas_clean AS mc
    CROSS JOIN metricas_modelo AS mm

    UNION ALL

    SELECT
        'Total de cantidades',
        mc.total_cantidad,
        mm.total_cantidad
    FROM metricas_clean AS mc
    CROSS JOIN metricas_modelo AS mm

    UNION ALL

    SELECT
        'Total de descuentos',
        mc.total_descuento,
        mm.total_descuento
    FROM metricas_clean AS mc
    CROSS JOIN metricas_modelo AS mm

    UNION ALL

    SELECT
        'Total de beneficios',
        mc.total_beneficio,
        mm.total_beneficio
    FROM metricas_clean AS mc
    CROSS JOIN metricas_modelo AS mm
)

SELECT
    control,
    valor_esperado,
    valor_obtenido,
    valor_obtenido - valor_esperado AS diferencia,

    CASE
        -- <=> compara también correctamente valores NULL.
        WHEN valor_esperado <=> valor_obtenido
            THEN 'OK'
        ELSE 'REVISAR'
    END AS estado

FROM controles

ORDER BY
    CASE control
        WHEN 'Total de filas' THEN 1
        WHEN 'Ventas conocidas' THEN 2
        WHEN 'Ventas desconocidas' THEN 3
        WHEN 'Cantidades conocidas' THEN 4
        WHEN 'Cantidades desconocidas' THEN 5
        WHEN 'Beneficios conocidos' THEN 6
        WHEN 'Beneficios desconocidos' THEN 7
        WHEN 'Total de ventas' THEN 8
        WHEN 'Total de cantidades' THEN 9
        WHEN 'Total de descuentos' THEN 10
        WHEN 'Total de beneficios' THEN 11
    END;