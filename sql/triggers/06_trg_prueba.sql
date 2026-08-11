-- Obtenemos un pedido y un producto válidos.
SET @test_order_key =
(
    SELECT order_key
    FROM orders
    ORDER BY order_key
    LIMIT 1
);

SET @test_product_key =
(
    SELECT product_key
    FROM products
    ORDER BY product_key
    LIMIT 1
);

-- Generamos un source_row_id temporal.
SET @test_source_row_id =
(
    SELECT
        COALESCE(
            MAX(source_row_id),
            0
        ) + 1
    FROM order_details
);

START TRANSACTION;

-- Creamos una línea temporal.
INSERT INTO order_details
(
    source_row_id,
    order_key,
    product_key,
    sales,
    quantity,
    discount,
    profit
)
VALUES
(
    @test_source_row_id,
    @test_order_key,
    @test_product_key,
    150.00,
    2,
    0.10,
    25.00
);

SET @test_order_detail_key = LAST_INSERT_ID();

-- Confirmamos que la línea existe.
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

-- Eliminamos la línea temporal.
DELETE FROM order_details
WHERE order_detail_key = @test_order_detail_key;

-- Confirmamos que ya no existe.
SELECT
    COUNT(*) AS remaining_test_details
FROM order_details
WHERE order_detail_key = @test_order_detail_key;

-- Consultamos la auditoría generada
-- específicamente por el DELETE.
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
  AND action_type = 'DELETE'
ORDER BY audit_id DESC
LIMIT 1;

-- Consultamos todo el ciclo temporal
-- asociado con esta línea.
SELECT
    audit_id,
    action_type,
    old_data,
    new_data
FROM audit_log
WHERE table_name = 'order_details'
  AND record_key = CAST(
        @test_order_detail_key AS CHAR
      )
ORDER BY audit_id;

ROLLBACK;

SELECT
    COUNT(*) AS remaining_test_details
FROM order_details
WHERE source_row_id = @test_source_row_id;

SELECT
    COUNT(*) AS remaining_test_audit_records
FROM audit_log
WHERE table_name = 'order_details'
  AND record_key = CAST(
        @test_order_detail_key AS CHAR
      );