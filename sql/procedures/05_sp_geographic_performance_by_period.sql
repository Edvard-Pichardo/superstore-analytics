/*
Archivo      : 05_sp_geographic_performance_by_period.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Procedimiento almacenado para consultar el
               rendimiento geográfico por ciudad dentro de
               un periodo, con filtros opcionales por país
               y región.
*/

USE superstore_analytics;

DROP PROCEDURE IF EXISTS sp_geographic_performance_by_period;

DELIMITER $$

CREATE PROCEDURE sp_geographic_performance_by_period
(
    IN p_country VARCHAR(100),
    IN p_region VARCHAR(20),
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    DECLARE v_min_date DATE;
    DECLARE v_max_date DATE;
    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;
    DECLARE v_country_exists INT DEFAULT 0;
    DECLARE v_region_exists INT DEFAULT 0;

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

    -- Si se proporciona un país, verificamos
    -- que exista dentro del modelo.

    IF p_country IS NOT NULL THEN

        SELECT
            COUNT(DISTINCT country)
        INTO
            v_country_exists
        FROM vw_order_summary
        WHERE country = p_country;

        IF v_country_exists = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'El país indicado no existe.';
        END IF;

    END IF;

    -- Si se proporciona una región, verificamos
    -- que exista dentro del modelo.

    IF p_region IS NOT NULL THEN

        SELECT
            COUNT(DISTINCT region)
        INTO
            v_region_exists
        FROM vw_order_summary
        WHERE region = p_region;

        IF v_region_exists = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'La región indicada no existe.';
        END IF;

    END IF;

    -- Agregamos el rendimiento comercial y logístico
    -- de cada ciudad dentro del periodo solicitado.

    WITH rendimiento_geografico AS
    (
        SELECT
            vos.region,
            vos.country,
            vos.state,
            vos.city,
            COUNT(*) AS total_orders,
            COUNT(DISTINCT vos.customer_id)
                AS distinct_customers,
            SUM(vos.total_order_lines)
                AS total_order_lines,
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
            -- Margen calculado únicamente con pedidos
            -- cuyas ventas y beneficios están completos.
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
            MIN(vos.shipping_days)
                AS minimum_shipping_days,
            MAX(vos.shipping_days)
                AS maximum_shipping_days,
            STDDEV_POP(vos.shipping_days)
                AS shipping_days_stddev,
            SUM(
                CASE
                    WHEN vos.shipping_days <= 2 THEN 1
                    ELSE 0
                END
            ) AS two_day_or_less_orders,
            SUM(
                CASE
                    WHEN vos.shipping_days >= 8 THEN 1
                    ELSE 0
                END
            ) AS eight_plus_day_orders,
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
          AND (
                p_country IS NULL
                OR vos.country = p_country
          )
          AND (
                p_region IS NULL
                OR vos.region = p_region
          )
        GROUP BY
            vos.region,
            vos.country,
            vos.state,
            vos.city
    ),

    ranking_geografico AS
    (
        SELECT
            rg.*,
            -- Ranking por ventas dentro del resultado filtrado.
            DENSE_RANK() OVER
            (
                ORDER BY rg.total_sales DESC
            ) AS sales_rank,
            -- Ranking por beneficio dentro del resultado filtrado.
            DENSE_RANK() OVER
            (
                ORDER BY rg.total_profit DESC
            ) AS profit_rank,
            -- Ranking por margen comparable.
            DENSE_RANK() OVER
            (
                ORDER BY
                    rg.comparable_profit_margin_percentage DESC
            ) AS margin_rank,
            -- Ranking de ventas dentro de cada región.
            DENSE_RANK() OVER
            (
                PARTITION BY rg.region
                ORDER BY rg.total_sales DESC
            ) AS regional_sales_rank,
            -- Participación sobre las ventas del
            -- conjunto geográfico solicitado.
            100.0
            *
            rg.total_sales
            /
            NULLIF(
                SUM(rg.total_sales) OVER (),
                0
            ) AS sales_share_percentage
        FROM rendimiento_geografico AS rg
    )

    SELECT
        region,
        country,
        state,
        city,
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
        ROUND(
            sales_share_percentage,
            4
        ) AS sales_share_percentage,
        total_quantity,
        ROUND(
            total_profit,
            2
        ) AS total_profit,
        ROUND(
            average_complete_order_value,
            2
        ) AS average_complete_order_value,
        ROUND(
            comparable_profit_margin_percentage,
            2
        ) AS comparable_profit_margin_percentage,
        sales_rank,
        profit_rank,
        margin_rank,
        regional_sales_rank,
        -- Diferencia entre posición por ventas
        -- y posición por beneficio.
        CAST(profit_rank AS SIGNED)
        -
        CAST(sales_rank AS SIGNED)
            AS sales_profit_rank_gap,
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
    FROM ranking_geografico
    ORDER BY
        sales_rank,
        country,
        state,
        city;
END$$

DELIMITER ;


-- Pruebas

-- Toda la geografía y todo el periodo.
CALL sp_geographic_performance_by_period(
    NULL,
    NULL,
    NULL,
    NULL
);

-- Región West durante todo el periodo.
CALL sp_geographic_performance_by_period(
    NULL,
    'West',
    NULL,
    NULL
);

-- Región East durante 2025.
CALL sp_geographic_performance_by_period(
    NULL,
    'East',
    '2025-01-01',
    '2025-12-31'
);

-- Validación intencional de una región inexistente.
CALL sp_geographic_performance_by_period(
    NULL,
    'Region Inventada',
    NULL,
    NULL
);

-- Validación intencional del rango temporal.
CALL sp_geographic_performance_by_period(
    NULL,
    NULL,
    '2026-12-31',
    '2026-01-01'
);