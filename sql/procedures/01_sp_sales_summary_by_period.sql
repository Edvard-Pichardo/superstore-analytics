/*
Archivo      : 01_sp_sales_summary_by_period.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Procedimiento almacenado para consultar los
               principales indicadores comerciales dentro
               de un periodo definido por el usuario.
*/

USE superstore_analytics;

DROP PROCEDURE IF EXISTS sp_sales_summary_by_period;

DELIMITER $$

CREATE PROCEDURE sp_sales_summary_by_period
(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    DECLARE v_min_date DATE;
    DECLARE v_max_date DATE;
    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;

    -- Obtenemos los límites temporales disponibles
    -- dentro del modelo analítico.

    SELECT
        MIN(order_date),
        MAX(order_date)
    INTO
        v_min_date,
        v_max_date
    FROM vw_order_summary;

    -- Si alguna fecha no se proporciona, utilizamos
    -- automáticamente el límite correspondiente del dataset.

    SET v_start_date = COALESCE(
        p_start_date,
        v_min_date
    );

    SET v_end_date = COALESCE(
        p_end_date,
        v_max_date
    );

    -- Validamos que la fecha inicial no sea
    -- posterior a la fecha final.

    IF v_start_date > v_end_date THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'La fecha inicial no puede ser posterior a la fecha final.';
    END IF;

    -- Devolvemos los principales indicadores
    -- comerciales del periodo solicitado.

    SELECT
        v_start_date
            AS requested_start_date,
        v_end_date
            AS requested_end_date,
        MIN(order_date)
            AS first_observed_order_date,
        MAX(order_date)
            AS last_observed_order_date,
        COUNT(*) AS total_orders,
        COUNT(DISTINCT customer_id)
            AS distinct_customers,
        SUM(total_order_lines)
            AS total_order_lines,
        SUM(distinct_products)
            AS total_product_references,
        ROUND(
            SUM(total_sales),
            2
        ) AS total_sales,
        SUM(total_quantity)
            AS total_quantity,
        ROUND(
            SUM(total_profit),
            2
        ) AS total_profit,
        ROUND(
            AVG(
                CASE
                    WHEN unknown_sales_lines = 0
                        THEN total_sales
                END
            ),
            2
        ) AS average_complete_order_value,
        ROUND(
            SUM(
                CASE
                    WHEN unknown_sales_lines = 0
                     AND unknown_profit_lines = 0
                        THEN total_profit
                END
            )
            /
            NULLIF(
                SUM(
                    CASE
                        WHEN unknown_sales_lines = 0
                         AND unknown_profit_lines = 0
                            THEN total_sales
                    END
                ),
                0
            ) * 100,
            2
        ) AS comparable_profit_margin_percentage,
        ROUND(
            AVG(shipping_days),
            2
        ) AS average_shipping_days,
        MIN(shipping_days)
            AS minimum_shipping_days,
        MAX(shipping_days)
            AS maximum_shipping_days,
        SUM(unknown_sales_lines)
            AS unknown_sales_lines,
        SUM(unknown_quantity_lines)
            AS unknown_quantity_lines,
        SUM(unknown_profit_lines)
            AS unknown_profit_lines,
        SUM(
            CASE
                WHEN unknown_sales_lines > 0 THEN 1
                ELSE 0
            END
        ) AS orders_with_unknown_sales,
        SUM(
            CASE
                WHEN unknown_profit_lines > 0 THEN 1
                ELSE 0
            END
        ) AS orders_with_unknown_profit,
        SUM(
            CASE
                WHEN ship_mode IS NULL THEN 1
                ELSE 0
            END
        ) AS orders_with_unknown_ship_mode,
        SUM(
            CASE
                WHEN unknown_profit_lines = 0
                 AND total_profit < 0
                    THEN 1
                ELSE 0
            END
        ) AS complete_loss_making_orders
    FROM vw_order_summary
    WHERE order_date BETWEEN
        v_start_date
        AND
        v_end_date;
END$$

DELIMITER ;


-- Pruebas

-- Periodo completo.
CALL sp_sales_summary_by_period(
    NULL,
    NULL
);

-- Año completo.
CALL sp_sales_summary_by_period(
    '2025-01-01',
    '2025-12-31'
);

-- Periodo parcial.
CALL sp_sales_summary_by_period(
    '2026-01-01',
    '2026-06-30'
);

-- Validación intencional de fechas incorrectas.
CALL sp_sales_summary_by_period(
    '2026-12-31',
    '2026-01-01'
);