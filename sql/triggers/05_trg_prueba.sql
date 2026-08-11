-- Prueba: Actualización
-- Seleccionamos una línea existente con ventas conocidas.
SET @test_order_detail_key =
(
    SELECT order_detail_key
    FROM order_details
    WHERE sales IS NOT NULL
    ORDER BY order_detail_key
    LIMIT 1
);

START TRANSACTION;

-- Consultamos el estado original.
SELECT
    order_detail_key,
    source_row_id,
    order_key,
    product_key,
    sales,
    quantity,
    discount,
    profit
FROM order_details
WHERE order_detail_key = @test_order_detail_key;

-- Modificamos temporalmente las ventas.
UPDATE order_details
SET sales = sales + 1.00
WHERE order_detail_key = @test_order_detail_key;

-- Consultamos el estado modificado.
SELECT
    order_detail_key,
    source_row_id,
    order_key,
    product_key,
    sales,
    quantity,
    discount,
    profit
FROM order_details
WHERE order_detail_key = @test_order_detail_key;

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
WHERE table_name = 'order_details'
  AND record_key = CAST(
        @test_order_detail_key AS CHAR
      )
  AND action_type = 'UPDATE'
ORDER BY audit_id DESC
LIMIT 1;

-- Revertimos la modificación y su auditoría.
ROLLBACK;

SELECT
    COUNT(*) AS remaining_update_audit_records
FROM audit_log
WHERE table_name = 'order_details'
  AND record_key = CAST(
        @test_order_detail_key AS CHAR
      )
  AND action_type = 'UPDATE';


-- Prueba: Actualización sin cambio real

START TRANSACTION;

SET @audit_count_before =
(
    SELECT COUNT(*)
    FROM audit_log
);

UPDATE order_details
SET sales = sales
WHERE order_detail_key = @test_order_detail_key;

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

