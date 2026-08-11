/*
Archivo      : 01_trg_orders_after_insert.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Registra automáticamente en audit_log
               cada nuevo pedido insertado en la tabla
               orders.
*/

USE superstore_analytics;

DROP TRIGGER IF EXISTS trg_orders_after_insert;

DELIMITER $$

CREATE TRIGGER trg_orders_after_insert
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    -- Registramos el estado completo del nuevo pedido.

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
        'INSERT',
        USER(),
        CONNECTION_ID(),
        NULL,
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
END$$

DELIMITER ;

