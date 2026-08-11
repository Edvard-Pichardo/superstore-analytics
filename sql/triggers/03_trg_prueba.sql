-- Obtenemos claves válidas para crear
-- temporalmente un pedido de prueba.
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

-- Creamos un pedido temporal.
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
    'AUDIT-DELETE-TEST',
    @test_customer_id,
    @test_location_id,
    NULL,
    '2026-08-10',
    '2026-08-13'
);

SET @test_order_key = LAST_INSERT_ID();

-- Confirmamos que el pedido existe antes de eliminarlo.
SELECT
    order_key,
    source_order_id,
    customer_id,
    location_id,
    ship_mode_id,
    order_date,
    ship_date
FROM orders
WHERE order_key = @test_order_key;

-- Eliminamos el pedido temporal.
DELETE FROM orders
WHERE order_key = @test_order_key;

-- Confirmamos que ya no existe en orders.
SELECT
    COUNT(*) AS remaining_test_orders
FROM orders
WHERE order_key = @test_order_key;

-- Consultamos específicamente la auditoría
-- generada por el DELETE.
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
  AND action_type = 'DELETE'
ORDER BY audit_id DESC
LIMIT 1;

-- Revisamos los cambios
SELECT
    action_type,
    old_data,
    new_data
FROM audit_log
WHERE table_name = 'orders'
  AND record_key = CAST(
        @test_order_key AS CHAR
      )
ORDER BY audit_id;

-- Revertimos toda la prueba.
ROLLBACK;

SELECT
    COUNT(*) AS remaining_test_orders
FROM orders
WHERE source_order_id = 'AUDIT-DELETE-TEST';

SELECT
    COUNT(*) AS remaining_test_audit_records
FROM audit_log
WHERE table_name = 'orders'
  AND record_key = CAST(
        @test_order_key AS CHAR
      );