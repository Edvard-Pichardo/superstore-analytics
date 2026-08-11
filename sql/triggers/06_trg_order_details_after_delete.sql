/*
Archivo      : 06_trg_order_details_after_delete.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Registra automáticamente en audit_log
               las líneas de pedido eliminadas, conservando
               su estado inmediatamente anterior al borrado.
*/

USE superstore_analytics;

DROP TRIGGER IF EXISTS trg_order_details_after_delete;

DELIMITER $$

CREATE TRIGGER trg_order_details_after_delete
AFTER DELETE ON order_details
FOR EACH ROW
BEGIN
    -- Conservamos el estado completo
    -- de la línea eliminada.

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
        CAST(OLD.order_detail_key AS CHAR),
        'DELETE',
        USER(),
        CONNECTION_ID(),
        JSON_OBJECT(
            'order_detail_key',
            OLD.order_detail_key,
            'source_row_id',
            OLD.source_row_id,
            'order_key',
            OLD.order_key,
            'product_key',
            OLD.product_key,
            'sales',
            OLD.sales,
            'quantity',
            OLD.quantity,
            'discount',
            OLD.discount,
            'profit',
            OLD.profit
        ),
        NULL
    );
END$$

DELIMITER ;