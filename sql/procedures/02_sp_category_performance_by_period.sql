/*
Archivo      : 02_sp_category_performance_by_period.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Procedimiento almacenado para consultar el
               rendimiento de categorías y subcategorías
               dentro de un periodo definido por el usuario.
*/

USE superstore_analytics;

DROP PROCEDURE IF EXISTS sp_category_performance_by_period;

DELIMITER $$

CREATE PROCEDURE sp_category_performance_by_period
(
    IN p_category_name VARCHAR(30),
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    DECLARE v_min_date DATE;
    DECLARE v_max_date DATE;
    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;
    DECLARE v_category_exists INT DEFAULT 0;

    -- Obtenemos los límites temporales disponibles.

    SELECT
        MIN(order_date),
        MAX(order_date)
    INTO
        v_min_date,
        v_max_date
    FROM vw_sales_detail;

    -- Si las fechas son NULL utilizamos
    -- automáticamente los límites del dataset.

    SET v_start_date = COALESCE(
        p_start_date,
        v_min_date
    );

    SET v_end_date = COALESCE(
        p_end_date,
        v_max_date
    );

    -- Validamos el orden de las fechas.

    IF v_start_date > v_end_date THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'La fecha inicial no puede ser posterior a la fecha final.';
    END IF;

    -- Si se proporciona una categoría, comprobamos
    -- que exista dentro del modelo.

    IF p_category_name IS NOT NULL THEN

        SELECT
            COUNT(*)
        INTO
            v_category_exists
        FROM categories
        WHERE category_name = p_category_name;

        IF v_category_exists = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'La categoría indicada no existe.';
        END IF;

    END IF;

    -- Devolvemos el rendimiento de las subcategorías
    -- correspondientes al periodo solicitado.

    SELECT
        vsd.category,
        vsd.sub_category,
        v_start_date
            AS requested_start_date,
        v_end_date
            AS requested_end_date,
        MIN(vsd.order_date)
            AS first_observed_order_date,
        MAX(vsd.order_date)
            AS last_observed_order_date,
        COUNT(DISTINCT vsd.order_key)
            AS total_orders,
        COUNT(DISTINCT vsd.customer_id)
            AS distinct_customers,
        COUNT(DISTINCT vsd.product_key)
            AS distinct_products,
        COUNT(*)
            AS total_order_lines,
        ROUND(
            SUM(vsd.sales),
            2
        ) AS total_sales,
        SUM(vsd.quantity)
            AS total_quantity,
        ROUND(
            SUM(vsd.profit),
            2
        ) AS total_profit,
        ROUND(
            AVG(vsd.discount),
            4
        ) AS average_discount,
        -- El margen comparable utiliza únicamente líneas
        -- donde ventas y beneficio están disponibles.
        ROUND(
            SUM(
                CASE
                    WHEN vsd.sales IS NOT NULL
                     AND vsd.profit IS NOT NULL
                        THEN vsd.profit
                END
            )
            /
            NULLIF(
                SUM(
                    CASE
                        WHEN vsd.sales IS NOT NULL
                         AND vsd.profit IS NOT NULL
                            THEN vsd.sales
                    END
                ),
                0
            ) * 100,
            2
        ) AS comparable_profit_margin_percentage,
        -- Contamos líneas cuyo beneficio conocido
        -- presenta una pérdida.
        SUM(
            CASE
                WHEN vsd.profit < 0 THEN 1
                ELSE 0
            END
        ) AS loss_making_lines,
        ROUND(
            100.0
            *
            SUM(
                CASE
                    WHEN vsd.profit < 0 THEN 1
                    ELSE 0
                END
            )
            /
            NULLIF(
                SUM(
                    CASE
                        WHEN vsd.profit IS NOT NULL
                            THEN 1
                        ELSE 0
                    END
                ),
                0
            ),
            2
        ) AS known_loss_line_percentage,
        -- Contabilizamos los valores desconocidos
        -- para conservar la trazabilidad de los datos.
        SUM(
            CASE
                WHEN vsd.sales IS NULL THEN 1
                ELSE 0
            END
        ) AS unknown_sales_lines,
        SUM(
            CASE
                WHEN vsd.quantity IS NULL THEN 1
                ELSE 0
            END
        ) AS unknown_quantity_lines,
        SUM(
            CASE
                WHEN vsd.profit IS NULL THEN 1
                ELSE 0
            END
        ) AS unknown_profit_lines,
        -- Cobertura de ventas.
        ROUND(
            100.0
            *
            SUM(
                CASE
                    WHEN vsd.sales IS NOT NULL THEN 1
                    ELSE 0
                END
            )
            /
            NULLIF(COUNT(*), 0),
            2
        ) AS sales_coverage_percentage,
        -- Cobertura de cantidades.
        ROUND(
            100.0
            *
            SUM(
                CASE
                    WHEN vsd.quantity IS NOT NULL THEN 1
                    ELSE 0
                END
            )
            /
            NULLIF(COUNT(*), 0),
            2
        ) AS quantity_coverage_percentage,
        -- Cobertura de beneficio.
        ROUND(
            100.0
            *
            SUM(
                CASE
                    WHEN vsd.profit IS NOT NULL THEN 1
                    ELSE 0
                END
            )
            /
            NULLIF(COUNT(*), 0),
            2
        ) AS profit_coverage_percentage
    FROM vw_sales_detail AS vsd
    WHERE vsd.order_date BETWEEN
        v_start_date
        AND
        v_end_date
      AND (
            p_category_name IS NULL
            OR vsd.category = p_category_name
      )
    GROUP BY
        vsd.category,
        vsd.sub_category
    ORDER BY
        vsd.category,
        total_sales DESC,
        vsd.sub_category;
END$$

DELIMITER ;


-- Pruebas

-- Todas las categorías y todo el periodo.
CALL sp_category_performance_by_period(
    NULL,
    NULL,
    NULL
);

-- Technology durante 2025.
CALL sp_category_performance_by_period(
    'Technology',
    '2025-01-01',
    '2025-12-31'
);

-- Furniture durante el primer semestre de 2026.
CALL sp_category_performance_by_period(
    'Furniture',
    '2026-01-01',
    '2026-06-30'
);

-- Categoría inexistente para validar el control de errores.
CALL sp_category_performance_by_period(
    'Categoria Inventada',
    NULL,
    NULL
);