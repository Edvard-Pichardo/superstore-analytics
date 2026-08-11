/*
Archivo      : 04_trg_order_details_after_insert.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Registra automáticamente en audit_log
               cada nueva línea insertada en la tabla
               order_details.
*/

USE superstore_analytics;

DROP TRIGGER IF EXISTS trg_order_details_after_insert;

DELIMITER $$

CREATE TRIGGER trg_order_details_after_insert
AFTER INSERT ON order_details
FOR EACH ROW
BEGIN
    -- Registramos el estado completo
    -- de la nueva línea de pedido.

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
        'order_details',
        CAST(NEW.order_detail_key AS CHAR),
        'INSERT',
        USER(),
        CONNECTION_ID(),
        NULL,
        JSON_OBJECT(
            'order_detail_key',
            NEW.order_detail_key,
            'source_row_id',
            NEW.source_row_id,
            'order_key',
            NEW.order_key,
            'product_key',
            NEW.product_key,
            'sales',
            NEW.sales,
            'quantity',
            NEW.quantity,
            'discount',
            NEW.discount,
            'profit',
            NEW.profit
        )
    );
END$$

DELIMITER ;