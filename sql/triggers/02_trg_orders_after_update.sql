/*
Archivo      : 02_trg_orders_after_update.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Registra automáticamente en audit_log
               los cambios realizados sobre los pedidos,
               conservando el estado anterior y posterior.
*/

USE superstore_analytics;

DROP TRIGGER IF EXISTS trg_orders_after_update;

DELIMITER $$

CREATE TRIGGER trg_orders_after_update
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    -- Registramos únicamente actualizaciones
    -- que hayan modificado algún dato.

    IF NOT
    (
        OLD.order_key <=> NEW.order_key
        AND OLD.source_order_id <=> NEW.source_order_id
        AND OLD.customer_id <=> NEW.customer_id
        AND OLD.location_id <=> NEW.location_id
        AND OLD.ship_mode_id <=> NEW.ship_mode_id
        AND OLD.order_date <=> NEW.order_date
        AND OLD.ship_date <=> NEW.ship_date
    ) THEN

        INSERT INTO audit_log
        (
            table_name,
            record_key,
            action_type,
            changed_by,
            connection_id,
            old_data,
            new_data
        )
        VALUES
        (
            'orders',
            CAST(NEW.order_key AS CHAR),
            'UPDATE',
            USER(),
            CONNECTION_ID(),
            JSON_OBJECT(
                'order_key',
                OLD.order_key,
                'source_order_id',
                OLD.source_order_id,
                'customer_id',
                OLD.customer_id,
                'location_id',
                OLD.location_id,
                'ship_mode_id',
                OLD.ship_mode_id,
                'order_date',
                OLD.order_date,
                'ship_date',
                OLD.ship_date
            ),
            JSON_OBJECT(
                'order_key',
                NEW.order_key,
                'source_order_id',
                NEW.source_order_id,
                'customer_id',
                NEW.customer_id,
                'location_id',
                NEW.location_id,
                'ship_mode_id',
                NEW.ship_mode_id,
                'order_date',
                NEW.order_date,
                'ship_date',
                NEW.ship_date
            )
        );

    END IF;
END$$

DELIMITER ;


