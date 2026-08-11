-- Seleccionamos un pedido existente para la prueba.
SET @test_order_key =
(
    SELECT order_key
    FROM orders
    ORDER BY order_key
    LIMIT 1
);

START TRANSACTION;

-- Consultamos el estado original.
SELECT
    order_key,
    source_order_id,
    order_date,
    ship_date
FROM orders
WHERE order_key = @test_order_key;

-- Modificamos temporalmente la fecha de envío.
UPDATE orders
SET ship_date = DATE_ADD(
    ship_date,
    INTERVAL 1 DAY
)
WHERE order_key = @test_order_key;

-- Comprobamos el estado modificado.
SELECT
    order_key,
    source_order_id,
    order_date,
    ship_date
FROM orders
WHERE order_key = @test_order_key;

-- Verificamos el registro generado por el trigger.
SELECT
    audit_id,
    table_name,
    record_key,
    action_type,
    changed_at,
    changed_by,
    connection_id,
    old_data,
    new_data
FROM audit_log
WHERE table_name = 'orders'
  AND record_key = CAST(
        @test_order_key AS CHAR
      )
  AND action_type = 'UPDATE'
ORDER BY audit_id DESC
LIMIT 1;

-- Revertimos la modificación y su auditoría.
ROLLBACK;


SELECT
    COUNT(*) AS remaining_update_audit_records
FROM audit_log
WHERE table_name = 'orders'
  AND record_key = CAST(
        @test_order_key AS CHAR
      )
  AND action_type = 'UPDATE';

-- Comprobamos que el envío regresó a su fecha original
SELECT
    order_key,
    order_date,
    ship_date
FROM orders
WHERE order_key = @test_order_key;




-- Segunda prueba (update que no modifica nada)
-- El trigger debería ignorarlo

START TRANSACTION;

SET @audit_count_before =
(
    SELECT COUNT(*)
    FROM audit_log
);

UPDATE orders
SET ship_date = ship_date
WHERE order_key = @test_order_key;

SET @audit_count_after =
(
    SELECT COUNT(*)
    FROM audit_log
);

SELECT
    @audit_count_before AS audit_count_before,
    @audit_count_after AS audit_count_after,
    @audit_count_after - @audit_count_before
        AS new_audit_records;

ROLLBACK;