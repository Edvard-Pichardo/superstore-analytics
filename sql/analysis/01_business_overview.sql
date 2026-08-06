/*
Archivo      : 01_business_overview.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Resumen general de KPI
               Consulta ejecutiva de los principales
               indicadores generales del negocio.
*/

USE superstore_analytics;

-- Presentamos los principales indicadores comerciales,
-- operativos y de calidad de datos del negocio.
SELECT
    -- Periodo analizado.
    first_order_date,
    last_order_date,
    analysis_period_days,
    -- Dimensiones generales.
    total_orders,
    total_customers,
    total_products,
    total_categories,
    total_subcategories,
    total_locations,
    total_regions,
    total_order_lines,
    -- Resultados comerciales.
    ROUND(total_sales, 2)
        AS total_sales,

    total_quantity,

    ROUND(total_profit, 2)
        AS total_profit,

    ROUND(average_complete_order_value, 2)
        AS average_complete_order_value,

    ROUND(average_complete_order_profit, 2)
        AS average_complete_order_profit,

    ROUND(comparable_profit_margin_percentage, 2)
        AS comparable_profit_margin_percentage,

    ROUND(average_orders_per_customer, 2)
        AS average_orders_per_customer,
    -- Desempeño logístico.
    ROUND(average_shipping_days, 2)
        AS average_shipping_days,

    minimum_shipping_days,
    maximum_shipping_days,
    -- Cobertura de información.
    ROUND(sales_coverage_percentage, 2)
        AS sales_coverage_percentage,

    ROUND(quantity_coverage_percentage, 2)
        AS quantity_coverage_percentage,

    ROUND(profit_coverage_percentage, 2)
        AS profit_coverage_percentage,
    -- Pedidos incompletos.
    orders_with_unknown_sales,
    orders_with_unknown_quantity,
    orders_with_unknown_profit,
    orders_with_unknown_ship_mode,
    -- Pedidos completos con pérdidas.
    complete_loss_making_orders,
    -- Porcentaje de pedidos completos que generaron pérdidas.
    ROUND(
        100.0 * complete_loss_making_orders
        /
        NULLIF(
            total_orders - orders_with_unknown_profit,
            0
        ),
        2
    ) AS complete_loss_making_order_percentage,
    -- Porcentaje de pedidos con modo de envío desconocido.
    ROUND(
        100.0 * orders_with_unknown_ship_mode
        /
        NULLIF(total_orders, 0),
        2
    ) AS unknown_ship_mode_percentage

FROM vw_business_overview;
