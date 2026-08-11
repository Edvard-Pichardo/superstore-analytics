-- Obtenemos claves existentes para respetar
-- las relaciones del modelo.
SET @test_customer_id =
(
    SELECT customer_id
    FROM customers
    ORDER BY customer_id
    LIMIT 1
);

SET @test_location_id =
(
    SELECT location_id
    FROM locations
    ORDER BY location_id
    LIMIT 1
);

START TRANSACTION;

-- Insertamos temporalmente un pedido de prueba.
INSERT INTO orders
(
    source_order_id,
    customer_id,
    location_id,
    ship_mode_id,
    order_date,
    ship_date
)
VALUES
(
    'AUDIT-TEST-001',
    @test_customer_id,
    @test_location_id,
    NULL,
    '2026-08-10',
    '2026-08-13'
);

SET @test_order_key = LAST_INSERT_ID();

-- Verificamos que el trigger haya creado
-- el registro de auditoría correspondiente.
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
ORDER BY audit_id DESC;

-- Comprobamos
SELECT
    COUNT(*) AS remaining_test_audit_records
FROM audit_log
WHERE table_name = 'orders'
  AND record_key = CAST(
        @test_order_key AS CHAR
      );

-- Eliminamos tanto el pedido de prueba
-- como su auditoría mediante ROLLBACK.
ROLLBACK;

SELECT
    COUNT(*) AS remaining_test_audit_records
FROM audit_log
WHERE table_name = 'orders'
  AND record_key = CAST(
        @test_order_key AS CHAR
      );