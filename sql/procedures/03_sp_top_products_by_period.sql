/*
Archivo      : 03_sp_top_products_by_period.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Procedimiento almacenado para consultar los
               productos con mayores ventas dentro de un
               periodo definido por el usuario.
*/

USE superstore_analytics;

DROP PROCEDURE IF EXISTS sp_top_products_by_period;

DELIMITER $$

CREATE PROCEDURE sp_top_products_by_period
(
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_top_n INT
)
BEGIN
    DECLARE v_min_date DATE;
    DECLARE v_max_date DATE;
    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;
    DECLARE v_top_n INT;

    -- Obtenemos los límites temporales disponibles.

    SELECT
        MIN(order_date),
        MAX(order_date)
    INTO
        v_min_date,
        v_max_date
    FROM vw_sales_detail;

    -- Si alguna fecha es NULL utilizamos
    -- automáticamente los límites del dataset.

    SET v_start_date = COALESCE(
        p_start_date,
        v_min_date
    );

    SET v_end_date = COALESCE(
        p_end_date,
        v_max_date
    );

    -- Si no se especifica el número de productos,
    -- utilizamos 20 como valor predeterminado.

    SET v_top_n = COALESCE(
        p_top_n,
        20
    );

    -- Validamos el orden de las fechas.

    IF v_start_date > v_end_date THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'La fecha inicial no puede ser posterior a la fecha final.';
    END IF;

    -- El número solicitado debe ser positivo.

    IF v_top_n <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'El número de productos debe ser mayor que cero.';
    END IF;

    -- Limitamos consultas excesivamente grandes.

    IF v_top_n > 1000 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'El número máximo de productos permitido es 1000.';
    END IF;

    -- Agregamos las métricas de cada producto
    -- dentro del periodo solicitado.

    WITH rendimiento_productos AS
    (
        SELECT
            vsd.product_key,
            vsd.product_id,
            vsd.product_name,
            vsd.category,
            vsd.sub_category,
            COUNT(DISTINCT vsd.order_key)
                AS total_orders,
            COUNT(DISTINCT vsd.customer_id)
                AS distinct_customers,
            COUNT(*) AS total_order_lines,
            SUM(vsd.sales)
                AS total_sales,
            SUM(vsd.quantity)
                AS total_quantity,
            SUM(vsd.profit)
                AS total_profit,
            AVG(vsd.discount)
                AS average_discount,
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
            ) * 100
                AS comparable_profit_margin_percentage,
            SUM(
                CASE
                    WHEN vsd.profit < 0 THEN 1
                    ELSE 0
                END
            ) AS loss_making_lines,
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
            ) AS unknown_profit_lines
        FROM vw_sales_detail AS vsd
        WHERE vsd.order_date BETWEEN
            v_start_date
            AND
            v_end_date
        GROUP BY
            vsd.product_key,
            vsd.product_id,
            vsd.product_name,
            vsd.category,
            vsd.sub_category
    ),

    ranking_productos AS
    (
        SELECT
            rp.*,
            ROW_NUMBER() OVER
            (
                ORDER BY
                    rp.total_sales DESC,
                    rp.total_profit DESC,
                    rp.product_key
            ) AS sales_position,
            DENSE_RANK() OVER
            (
                ORDER BY rp.total_profit DESC
            ) AS profit_rank,
            DENSE_RANK() OVER
            (
                ORDER BY
                    rp.comparable_profit_margin_percentage DESC
            ) AS margin_rank
        FROM rendimiento_productos AS rp
    )

    SELECT
        sales_position,
        product_key,
        product_id,
        product_name,
        category,
        sub_category,
        v_start_date
            AS requested_start_date,
        v_end_date
            AS requested_end_date,
        total_orders,
        distinct_customers,
        total_order_lines,
        ROUND(
            total_sales,
            2
        ) AS total_sales,
        total_quantity,
        ROUND(
            total_profit,
            2
        ) AS total_profit,
        ROUND(
            average_discount,
            4
        ) AS average_discount,
        ROUND(
            comparable_profit_margin_percentage,
            2
        ) AS comparable_profit_margin_percentage,
        profit_rank,
        margin_rank,
        -- Comparamos la posición por ventas
        -- contra la posición obtenida por beneficio.
        CAST(profit_rank AS SIGNED)
        -
        CAST(sales_position AS SIGNED)
            AS sales_profit_rank_gap,
        loss_making_lines,
        ROUND(
            100.0
            *
            loss_making_lines
            /
            NULLIF(
                total_order_lines
                -
                unknown_profit_lines,
                0
            ),
            2
        ) AS known_loss_line_percentage,
        unknown_sales_lines,
        unknown_quantity_lines,
        unknown_profit_lines,
        -- Cobertura de ventas.
        ROUND(
            100.0
            *
            (
                total_order_lines
                -
                unknown_sales_lines
            )
            /
            NULLIF(total_order_lines, 0),
            2
        ) AS sales_coverage_percentage,
        -- Cobertura de cantidades.
        ROUND(
            100.0
            *
            (
                total_order_lines
                -
                unknown_quantity_lines
            )
            /
            NULLIF(total_order_lines, 0),
            2
        ) AS quantity_coverage_percentage,
        -- Cobertura de beneficio.
        ROUND(
            100.0
            *
            (
                total_order_lines
                -
                unknown_profit_lines
            )
            /
            NULLIF(total_order_lines, 0),
            2
        ) AS profit_coverage_percentage
    FROM ranking_productos
    WHERE sales_position <= v_top_n
    ORDER BY sales_position;
END$$

DELIMITER ;


-- Pruebas

-- Top 20 de todo el periodo.
CALL sp_top_products_by_period(
    NULL,
    NULL,
    NULL
);

-- Top 10 de 2025.
CALL sp_top_products_by_period(
    '2025-01-01',
    '2025-12-31',
    10
);

-- Top 50 del primer semestre de 2026.
CALL sp_top_products_by_period(
    '2026-01-01',
    '2026-06-30',
    50
);

-- Validación intencional de un límite incorrecto.
CALL sp_top_products_by_period(
    NULL,
    NULL,
    0
);

-- Validación intencional de fechas incorrectas.
CALL sp_top_products_by_period(
    '2026-12-31',
    '2026-01-01',
    20
);