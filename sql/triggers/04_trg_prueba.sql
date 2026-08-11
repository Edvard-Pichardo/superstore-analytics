-- Obtenemos un pedido y un producto existentes
-- para respetar las claves foráneas.
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

-- Generamos temporalmente un source_row_id
-- que no exista en order_details.
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

-- Insertamos una línea temporal válida.
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
    100.00,
    1,
    0.10,
    15.00
);

SET @test_order_detail_key = LAST_INSERT_ID();

-- Confirmamos que la línea fue insertada.
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

-- Verificamos el registro generado
-- automáticamente por el trigger.
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
  AND action_type = 'INSERT'
ORDER BY audit_id DESC
LIMIT 1;

-- Revertimos la línea de prueba
-- y su correspondiente auditoría.
ROLLBACK;


SELECT
    COUNT(*) AS remaining_test_details
FROM order_details
WHERE order_detail_key = @test_order_detail_key;

SELECT
    COUNT(*) AS remaining_test_audit_records
FROM audit_log
WHERE table_name = 'order_details'
  AND record_key = CAST(
        @test_order_detail_key AS CHAR
      );