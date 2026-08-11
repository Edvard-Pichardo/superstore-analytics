/*
Archivo      : 04_sp_top_customers_by_period.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Procedimiento almacenado para consultar los
               clientes con mayores ventas dentro de un
               periodo definido por el usuario.
*/

USE superstore_analytics;

DROP PROCEDURE IF EXISTS sp_top_customers_by_period;

DELIMITER $$

CREATE PROCEDURE sp_top_customers_by_period
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
    FROM vw_order_summary;

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

    -- Si no se especifica el número de clientes,
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
            'El número de clientes debe ser mayor que cero.';
    END IF;

    -- Evitamos solicitudes excesivamente grandes.

    IF v_top_n > 1000 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'El número máximo de clientes permitido es 1000.';
    END IF;

    -- Agregamos el comportamiento de cada cliente
    -- dentro del periodo solicitado.

    WITH rendimiento_clientes AS
    (
        SELECT
            vos.customer_id,
            vos.customer_name,
            vos.segment,
            COUNT(*) AS total_orders,
            MIN(vos.order_date)
                AS first_order_date,
            MAX(vos.order_date)
                AS last_order_date,
            DATEDIFF(
                MAX(vos.order_date),
                MIN(vos.order_date)
            ) AS purchase_span_days,
            COUNT(
                DISTINCT DATE_FORMAT(
                    vos.order_date,
                    '%Y-%m'
                )
            ) AS active_months,
            COUNT(
                DISTINCT YEAR(vos.order_date)
            ) AS active_years,
            SUM(vos.total_order_lines)
                AS total_order_lines,
            SUM(vos.distinct_products)
                AS total_product_references,
            SUM(vos.total_sales)
                AS total_sales,
            SUM(vos.total_quantity)
                AS total_quantity,
            SUM(vos.total_profit)
                AS total_profit,
            AVG(
                CASE
                    WHEN vos.unknown_sales_lines = 0
                        THEN vos.total_sales
                END
            ) AS average_complete_order_value,
            -- El margen comparable utiliza únicamente
            -- pedidos con ventas y beneficios completos.
            SUM(
                CASE
                    WHEN vos.unknown_sales_lines = 0
                     AND vos.unknown_profit_lines = 0
                        THEN vos.total_profit
                END
            )
            /
            NULLIF(
                SUM(
                    CASE
                        WHEN vos.unknown_sales_lines = 0
                         AND vos.unknown_profit_lines = 0
                            THEN vos.total_sales
                    END
                ),
                0
            ) * 100
                AS comparable_profit_margin_percentage,
            AVG(vos.shipping_days)
                AS average_shipping_days,
            -- Pedidos completos cuyo beneficio fue negativo.
            SUM(
                CASE
                    WHEN vos.unknown_profit_lines = 0
                     AND vos.total_profit < 0
                        THEN 1
                    ELSE 0
                END
            ) AS complete_loss_making_orders,
            SUM(
                CASE
                    WHEN vos.unknown_sales_lines > 0
                        THEN 1
                    ELSE 0
                END
            ) AS orders_with_unknown_sales,
            SUM(
                CASE
                    WHEN vos.unknown_profit_lines > 0
                        THEN 1
                    ELSE 0
                END
            ) AS orders_with_unknown_profit,
            SUM(vos.unknown_sales_lines)
                AS unknown_sales_lines,
            SUM(vos.unknown_quantity_lines)
                AS unknown_quantity_lines,
            SUM(vos.unknown_profit_lines)
                AS unknown_profit_lines
        FROM vw_order_summary AS vos
        WHERE vos.order_date BETWEEN
            v_start_date
            AND
            v_end_date
        GROUP BY
            vos.customer_id,
            vos.customer_name,
            vos.segment
    ),

    ranking_clientes AS
    (
        SELECT
            rc.*,
            ROW_NUMBER() OVER
            (
                ORDER BY
                    rc.total_sales DESC,
                    rc.total_profit DESC,
                    rc.customer_id
            ) AS sales_position,
            DENSE_RANK() OVER
            (
                ORDER BY rc.total_profit DESC
            ) AS profit_rank,
            DENSE_RANK() OVER
            (
                ORDER BY rc.total_orders DESC
            ) AS order_frequency_rank,
            DENSE_RANK() OVER
            (
                ORDER BY
                    rc.average_complete_order_value DESC
            ) AS average_order_value_rank,
            DENSE_RANK() OVER
            (
                ORDER BY
                    rc.comparable_profit_margin_percentage DESC
            ) AS margin_rank,
            100.0
            *
            rc.total_sales
            /
            NULLIF(
                SUM(rc.total_sales) OVER (),
                0
            ) AS sales_share_percentage
        FROM rendimiento_clientes AS rc
    )

    SELECT
        sales_position,
        customer_id,
        customer_name,
        segment,
        v_start_date
            AS requested_start_date,
        v_end_date
            AS requested_end_date,
        first_order_date,
        last_order_date,
        purchase_span_days,
        active_months,
        active_years,
        total_orders,
        order_frequency_rank,
        total_order_lines,
        total_product_references,
        ROUND(
            total_sales,
            2
        ) AS total_sales,
        ROUND(
            sales_share_percentage,
            4
        ) AS sales_share_percentage,
        total_quantity,
        ROUND(
            total_profit,
            2
        ) AS total_profit,
        profit_rank,
        ROUND(
            average_complete_order_value,
            2
        ) AS average_complete_order_value,
        average_order_value_rank,
        ROUND(
            comparable_profit_margin_percentage,
            2
        ) AS comparable_profit_margin_percentage,
        margin_rank,
        -- Comparamos la posición por ventas
        -- contra la posición obtenida por beneficio.
        CAST(profit_rank AS SIGNED)
        -
        CAST(sales_position AS SIGNED)
            AS sales_profit_rank_gap,
        ROUND(
            average_shipping_days,
            2
        ) AS average_shipping_days,
        complete_loss_making_orders,
        ROUND(
            100.0
            *
            complete_loss_making_orders
            /
            NULLIF(
                total_orders
                -
                orders_with_unknown_profit,
                0
            ),
            2
        ) AS complete_loss_making_order_percentage,
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
    FROM ranking_clientes
    WHERE sales_position <= v_top_n
    ORDER BY sales_position;
END$$

DELIMITER ;



-- Pruebas

-- Top 20 de todo el periodo.
CALL sp_top_customers_by_period(
    NULL,
    NULL,
    NULL
);

-- Top 10 de 2025.
CALL sp_top_customers_by_period(
    '2025-01-01',
    '2025-12-31',
    10
);

-- Top 50 del primer semestre de 2026.
CALL sp_top_customers_by_period(
    '2026-01-01',
    '2026-06-30',
    50
);

-- Validación intencional del número de clientes.
CALL sp_top_customers_by_period(
    NULL,
    NULL,
    0
);

-- Validación intencional del rango temporal.
CALL sp_top_customers_by_period(
    '2026-12-31',
    '2026-01-01',
    20
);