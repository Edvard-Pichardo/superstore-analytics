/*
Archivo      : 05_trg_order_details_after_update.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Registra automáticamente en audit_log
               los cambios realizados sobre las líneas de
               pedido, conservando el estado anterior y
               posterior a cada modificación.
*/

USE superstore_analytics;

DROP TRIGGER IF EXISTS trg_order_details_after_update;

DELIMITER $$

CREATE TRIGGER trg_order_details_after_update
AFTER UPDATE ON order_details
FOR EACH ROW
BEGIN
    -- Registramos únicamente actualizaciones
    -- que hayan modificado algún dato.

    IF NOT
    (
        OLD.order_detail_key <=> NEW.order_detail_key
        AND OLD.source_row_id <=> NEW.source_row_id
        AND OLD.order_key <=> NEW.order_key
        AND OLD.product_key <=> NEW.product_key
        AND OLD.sales <=> NEW.sales
        AND OLD.quantity <=> NEW.quantity
        AND OLD.discount <=> NEW.discount
        AND OLD.profit <=> NEW.profit
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
            'order_details',
            CAST(NEW.order_detail_key AS CHAR),
            'UPDATE',
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

    END IF;
END$$

DELIMITER ;