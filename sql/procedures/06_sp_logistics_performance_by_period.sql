/*
Archivo      : 06_sp_logistics_performance_by_period.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Procedimiento almacenado para consultar el
               desempeño logístico por modo de envío dentro
               de un periodo definido por el usuario.
*/

USE superstore_analytics;

DROP PROCEDURE IF EXISTS sp_logistics_performance_by_period;

DELIMITER $$

CREATE PROCEDURE sp_logistics_performance_by_period
(
    IN p_ship_mode VARCHAR(100),
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    DECLARE v_min_date DATE;
    DECLARE v_max_date DATE;
    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;
    DECLARE v_ship_mode_exists INT DEFAULT 0;

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

    -- Validamos el orden de las fechas.

    IF v_start_date > v_end_date THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'La fecha inicial no puede ser posterior a la fecha final.';
    END IF;

    -- Si se proporciona un modo de envío, verificamos
    -- que exista dentro del modelo.
    --
    -- Los valores NULL del modelo se representan
    -- mediante la categoría lógica 'Unknown'.

    IF p_ship_mode IS NOT NULL THEN

        SELECT
            COUNT(*)
        INTO
            v_ship_mode_exists
        FROM
        (
            SELECT DISTINCT
                COALESCE(
                    ship_mode,
                    'Unknown'
                ) AS normalized_ship_mode
            FROM vw_order_summary
        ) AS modos_envio
        WHERE normalized_ship_mode = p_ship_mode;

        IF v_ship_mode_exists = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'El modo de envío indicado no existe.';
        END IF;

    END IF;

    -- Seleccionamos los pedidos correspondientes
    -- al periodo y modo de envío solicitados.

    WITH base_envios AS
    (
        SELECT
            vos.order_key,
            vos.order_date,
            vos.customer_id,
            COALESCE(
                vos.ship_mode,
                'Unknown'
            ) AS ship_mode,
            CASE
                WHEN vos.ship_mode IS NULL THEN 1
                ELSE 0
            END AS is_unknown_ship_mode,
            vos.shipping_days,
            vos.total_order_lines,
            vos.total_sales,
            vos.total_quantity,
            vos.total_profit,
            vos.unknown_sales_lines,
            vos.unknown_quantity_lines,
            vos.unknown_profit_lines
        FROM vw_order_summary AS vos
        WHERE vos.order_date BETWEEN
            v_start_date
            AND
            v_end_date
          AND (
                p_ship_mode IS NULL
                OR COALESCE(
                    vos.ship_mode,
                    'Unknown'
                ) = p_ship_mode
          )
    ),

    rendimiento_logistico AS
    (
        SELECT
            be.ship_mode,
            be.is_unknown_ship_mode,
            MIN(be.order_date)
                AS first_observed_order_date,
            MAX(be.order_date)
                AS last_observed_order_date,
            COUNT(*) AS total_orders,
            COUNT(DISTINCT be.customer_id)
                AS distinct_customers,
            SUM(be.total_order_lines)
                AS total_order_lines,
            AVG(be.shipping_days)
                AS average_shipping_days,
            MIN(be.shipping_days)
                AS minimum_shipping_days,
            MAX(be.shipping_days)
                AS maximum_shipping_days,
            STDDEV_POP(be.shipping_days)
                AS shipping_days_stddev,
            -- Pedidos enviados el mismo día.

            SUM(
                CASE
                    WHEN be.shipping_days = 0 THEN 1
                    ELSE 0
                END
            ) AS same_day_orders,
            -- Pedidos enviados en un máximo de dos días.

            SUM(
                CASE
                    WHEN be.shipping_days <= 2 THEN 1
                    ELSE 0
                END
            ) AS two_day_or_less_orders,
            -- Pedidos con una duración observada
            -- de ocho días o más.

            SUM(
                CASE
                    WHEN be.shipping_days >= 8 THEN 1
                    ELSE 0
                END
            ) AS eight_plus_day_orders,
            SUM(be.total_sales)
                AS total_sales,
            SUM(be.total_quantity)
                AS total_quantity,
            SUM(be.total_profit)
                AS total_profit,
            AVG(
                CASE
                    WHEN be.unknown_sales_lines = 0
                        THEN be.total_sales
                END
            ) AS average_complete_order_value,
            -- Margen calculado únicamente con pedidos
            -- cuyas ventas y beneficios están completos.

            SUM(
                CASE
                    WHEN be.unknown_sales_lines = 0
                     AND be.unknown_profit_lines = 0
                        THEN be.total_profit
                END
            )
            /
            NULLIF(
                SUM(
                    CASE
                        WHEN be.unknown_sales_lines = 0
                         AND be.unknown_profit_lines = 0
                            THEN be.total_sales
                    END
                ),
                0
            ) * 100
                AS comparable_profit_margin_percentage,
            -- Pedidos completos cuyo beneficio fue negativo.

            SUM(
                CASE
                    WHEN be.unknown_profit_lines = 0
                     AND be.total_profit < 0
                        THEN 1
                    ELSE 0
                END
            ) AS complete_loss_making_orders,
            SUM(
                CASE
                    WHEN be.unknown_sales_lines > 0
                        THEN 1
                    ELSE 0
                END
            ) AS orders_with_unknown_sales,
            SUM(
                CASE
                    WHEN be.unknown_profit_lines > 0
                        THEN 1
                    ELSE 0
                END
            ) AS orders_with_unknown_profit,
            SUM(be.unknown_sales_lines)
                AS unknown_sales_lines,
            SUM(be.unknown_quantity_lines)
                AS unknown_quantity_lines,
            SUM(be.unknown_profit_lines)
                AS unknown_profit_lines
        FROM base_envios AS be
        GROUP BY
            be.ship_mode,
            be.is_unknown_ship_mode
    ),

    ranking_logistico AS
    (
        SELECT
            rl.*,
            -- Participación del modo de envío dentro
            -- del conjunto solicitado.

            100.0
            *
            rl.total_orders
            /
            NULLIF(
                SUM(rl.total_orders) OVER (),
                0
            ) AS order_share_percentage,
            -- Ranking desde el menor tiempo promedio
            -- hasta el mayor.

            DENSE_RANK() OVER
            (
                ORDER BY rl.average_shipping_days ASC
            ) AS shipping_speed_rank,
            -- Ranking según utilización.

            DENSE_RANK() OVER
            (
                ORDER BY rl.total_orders DESC
            ) AS usage_rank,
            -- Ranking según ventas.

            DENSE_RANK() OVER
            (
                ORDER BY rl.total_sales DESC
            ) AS sales_rank,
            -- Ranking según beneficio.

            DENSE_RANK() OVER
            (
                ORDER BY rl.total_profit DESC
            ) AS profit_rank
        FROM rendimiento_logistico AS rl
    )

    SELECT
        ship_mode,
        is_unknown_ship_mode,
        v_start_date
            AS requested_start_date,
        v_end_date
            AS requested_end_date,
        first_observed_order_date,
        last_observed_order_date,
        total_orders,
        ROUND(
            order_share_percentage,
            2
        ) AS order_share_percentage,
        distinct_customers,
        total_order_lines,
        usage_rank,
        ROUND(
            average_shipping_days,
            2
        ) AS average_shipping_days,
        minimum_shipping_days,
        maximum_shipping_days,
        ROUND(
            shipping_days_stddev,
            2
        ) AS shipping_days_stddev,
        shipping_speed_rank,
        same_day_orders,
        ROUND(
            100.0
            *
            same_day_orders
            /
            NULLIF(total_orders, 0),
            2
        ) AS same_day_percentage,
        two_day_or_less_orders,
        ROUND(
            100.0
            *
            two_day_or_less_orders
            /
            NULLIF(total_orders, 0),
            2
        ) AS two_day_or_less_percentage,
        eight_plus_day_orders,
        ROUND(
            100.0
            *
            eight_plus_day_orders
            /
            NULLIF(total_orders, 0),
            2
        ) AS eight_plus_day_percentage,
        ROUND(
            total_sales,
            2
        ) AS total_sales,
        sales_rank,
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
        ROUND(
            comparable_profit_margin_percentage,
            2
        ) AS comparable_profit_margin_percentage,
        -- Comparamos la posición por ventas
        -- contra la posición por beneficio.

        CAST(profit_rank AS SIGNED)
        -
        CAST(sales_rank AS SIGNED)
            AS sales_profit_rank_gap,
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
        orders_with_unknown_sales,
        orders_with_unknown_profit,
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
    FROM ranking_logistico
    ORDER BY
        is_unknown_ship_mode,
        usage_rank,
        ship_mode;
END$$

DELIMITER ;



-- Pruebas

-- Todos los modos y todo el periodo.
CALL sp_logistics_performance_by_period(
    NULL,
    NULL,
    NULL
);

-- Standard Class durante 2025.
CALL sp_logistics_performance_by_period(
    'Standard Class',
    '2025-01-01',
    '2025-12-31'
);

-- Same Day durante el primer semestre de 2026.
CALL sp_logistics_performance_by_period(
    'Same Day',
    '2026-01-01',
    '2026-06-30'
);

-- Pedidos cuyo modo de envío es desconocido.
CALL sp_logistics_performance_by_period(
    'Unknown',
    NULL,
    NULL
);

-- Validación intencional de una modalidad inexistente.
CALL sp_logistics_performance_by_period(
    'Entrega Teletransportada',
    NULL,
    NULL
);

-- Validación intencional del rango temporal.
CALL sp_logistics_performance_by_period(
    NULL,
    '2026-12-31',
    '2026-01-01'
);