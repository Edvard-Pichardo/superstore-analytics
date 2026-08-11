/*
Archivo      : 03_trg_orders_after_delete.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Registra automáticamente en audit_log
               los pedidos eliminados, conservando su
               estado inmediatamente anterior al borrado.
*/

USE superstore_analytics;

DROP TRIGGER IF EXISTS trg_orders_after_delete;

DELIMITER $$

CREATE TRIGGER trg_orders_after_delete
AFTER DELETE ON orders
FOR EACH ROW
BEGIN
    -- Conservamos el estado completo del pedido eliminado.

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
        CAST(OLD.order_key AS CHAR),
        'DELETE',
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
        NULL
    );
END$$

DELIMITER ;