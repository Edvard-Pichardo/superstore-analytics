/*
Archivo      : 07_validate_audit_system.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Descripción  : Valida de forma integral la configuración,
               funcionamiento e integridad del sistema de
               auditoría basado en triggers.
*/

USE superstore_analytics;


-- Verificamos que existan exactamente los seis triggers esperados.
SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE trigger_schema = DATABASE()
  AND trigger_name IN
  (
      'trg_orders_after_insert',
      'trg_orders_after_update',
      'trg_orders_after_delete',
      'trg_order_details_after_insert',
      'trg_order_details_after_update',
      'trg_order_details_after_delete'
  )
ORDER BY
    event_object_table,
    CASE event_manipulation
        WHEN 'INSERT' THEN 1
        WHEN 'UPDATE' THEN 2
        WHEN 'DELETE' THEN 3
        ELSE 4
    END;

-- Comprobamos la cantidad total de triggers esperados.
SELECT
    COUNT(*) AS expected_triggers_found,
    CASE
        WHEN COUNT(*) = 6 THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM information_schema.triggers
WHERE trigger_schema = DATABASE()
  AND trigger_name IN
  (
      'trg_orders_after_insert',
      'trg_orders_after_update',
      'trg_orders_after_delete',
      'trg_order_details_after_insert',
      'trg_order_details_after_update',
      'trg_order_details_after_delete'
  );




-- Validamos la estructura e integridad de audit_log.
SELECT
    column_name,
    column_type,
    is_nullable,
    column_key,
    extra
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'audit_log'
ORDER BY ordinal_position;

-- Verificamos que existan exactamente
-- las ocho columnas definidas para auditoría.
SELECT
    COUNT(*) AS audit_columns_found,
    CASE
        WHEN COUNT(*) = 9 THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'audit_log'
  AND column_name IN
  (
      'audit_id',
      'table_name',
      'record_key',
      'action_type',
      'changed_at',
      'changed_by',
      'connection_id',
      'old_data',
      'new_data'
  );

-- Verificamos los índices definidos
-- para las consultas de auditoría.
SELECT
    index_name,
    non_unique,
    GROUP_CONCAT(
        column_name
        ORDER BY seq_in_index
        SEPARATOR ', '
    ) AS indexed_columns
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 'audit_log'
GROUP BY
    index_name,
    non_unique
ORDER BY
    CASE
        WHEN index_name = 'PRIMARY' THEN 1
        ELSE 2
    END,
    index_name;

-- Verificamos que exista la restricción
-- de coherencia entre acción y payload JSON.
SELECT
    tc.constraint_name,
    tc.constraint_type,
    cc.check_clause
FROM information_schema.table_constraints AS tc
JOIN information_schema.check_constraints AS cc
    ON cc.constraint_schema = tc.constraint_schema
   AND cc.constraint_name = tc.constraint_name
WHERE tc.table_schema = DATABASE()
  AND tc.table_name = 'audit_log'
  AND tc.constraint_type = 'CHECK';

-- Comprobamos que no existan registros
-- cuya estructura contradiga el tipo de acción.
SELECT
    COUNT(*) AS inconsistent_audit_records,
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE
    (
        action_type = 'INSERT'
        AND (
            old_data IS NOT NULL
            OR new_data IS NULL
        )
    )
    OR
    (
        action_type = 'UPDATE'
        AND (
            old_data IS NULL
            OR new_data IS NULL
        )
    )
    OR
    (
        action_type = 'DELETE'
        AND (
            old_data IS NULL
            OR new_data IS NOT NULL
        )
    );





-- Validamos el ciclo completo de auditoría sobre orders.
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

-- Insertamos un pedido temporal.
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
    'AUDIT-VAL-001',
    @test_customer_id,
    @test_location_id,
    NULL,
    '2026-08-10',
    '2026-08-13'
);

-- Recuperamos explícitamente la clave
-- del pedido temporal.
SET @test_order_key =
(
    SELECT order_key
    FROM orders
    WHERE source_order_id = 'AUDIT-VAL-001'
      AND customer_id = @test_customer_id
      AND location_id = @test_location_id
);

-- Modificamos la fecha de envío.
UPDATE orders
SET ship_date = '2026-08-14'
WHERE order_key = @test_order_key;

-- Eliminamos el pedido temporal.
DELETE FROM orders
WHERE order_key = @test_order_key;

-- Verificamos que se hayan generado
-- exactamente tres eventos de auditoría.
SELECT
    COUNT(*) AS audit_events_found,
    CASE
        WHEN COUNT(*) = 3 THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE table_name = 'orders'
  AND record_key = CAST(
        @test_order_key AS CHAR
      )
  AND action_type IN
  (
      'INSERT',
      'UPDATE',
      'DELETE'
  );

-- Comprobamos que exista exactamente
-- un evento de cada tipo.
SELECT
    action_type,
    COUNT(*) AS event_count,
    CASE
        WHEN COUNT(*) = 1 THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE table_name = 'orders'
  AND record_key = CAST(
        @test_order_key AS CHAR
      )
GROUP BY action_type
ORDER BY
    CASE action_type
        WHEN 'INSERT' THEN 1
        WHEN 'UPDATE' THEN 2
        WHEN 'DELETE' THEN 3
        ELSE 4
    END;

-- Inspeccionamos la secuencia completa
-- registrada por los triggers.
SELECT
    audit_id,
    action_type,
    changed_at,
    old_data,
    new_data
FROM audit_log
WHERE table_name = 'orders'
  AND record_key = CAST(
        @test_order_key AS CHAR
      )
ORDER BY audit_id;

-- Validamos específicamente el cambio
-- realizado sobre ship_date.
SELECT
    JSON_UNQUOTE(
        JSON_EXTRACT(
            old_data,
            '$.ship_date'
        )
    ) AS old_ship_date,
    JSON_UNQUOTE(
        JSON_EXTRACT(
            new_data,
            '$.ship_date'
        )
    ) AS new_ship_date,
    CASE
        WHEN JSON_UNQUOTE(
                JSON_EXTRACT(
                    old_data,
                    '$.ship_date'
                )
             ) = '2026-08-13'
         AND JSON_UNQUOTE(
                JSON_EXTRACT(
                    new_data,
                    '$.ship_date'
                )
             ) = '2026-08-14'
            THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE table_name = 'orders'
  AND record_key = CAST(
        @test_order_key AS CHAR
      )
  AND action_type = 'UPDATE';

-- Validamos la coherencia de los payloads
-- para los tres eventos de la prueba.
SELECT
    SUM(
        CASE
            WHEN action_type = 'INSERT'
             AND old_data IS NULL
             AND new_data IS NOT NULL
                THEN 1
            ELSE 0
        END
    ) AS valid_insert_events,
    SUM(
        CASE
            WHEN action_type = 'UPDATE'
             AND old_data IS NOT NULL
             AND new_data IS NOT NULL
                THEN 1
            ELSE 0
        END
    ) AS valid_update_events,
    SUM(
        CASE
            WHEN action_type = 'DELETE'
             AND old_data IS NOT NULL
             AND new_data IS NULL
                THEN 1
            ELSE 0
        END
    ) AS valid_delete_events,
    CASE
        WHEN SUM(
                CASE
                    WHEN action_type = 'INSERT'
                     AND old_data IS NULL
                     AND new_data IS NOT NULL
                        THEN 1
                    ELSE 0
                END
             ) = 1
         AND SUM(
                CASE
                    WHEN action_type = 'UPDATE'
                     AND old_data IS NOT NULL
                     AND new_data IS NOT NULL
                        THEN 1
                    ELSE 0
                END
             ) = 1
         AND SUM(
                CASE
                    WHEN action_type = 'DELETE'
                     AND old_data IS NOT NULL
                     AND new_data IS NULL
                        THEN 1
                    ELSE 0
                END
             ) = 1
            THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE table_name = 'orders'
  AND record_key = CAST(
        @test_order_key AS CHAR
      );

-- Revertimos toda la prueba.
ROLLBACK;

-- Confirmamos que ni el pedido temporal
-- ni sus eventos de auditoría persistieron.
SELECT
    (
        SELECT COUNT(*)
        FROM orders
        WHERE source_order_id = 'AUDIT-VAL-001'
    ) AS remaining_test_orders,
    (
        SELECT COUNT(*)
        FROM audit_log
        WHERE table_name = 'orders'
          AND record_key = CAST(
                @test_order_key AS CHAR
              )
    ) AS remaining_test_audit_records;





-- Validamos el ciclo completo de auditoría sobre order_details.
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

-- Insertamos una línea de pedido temporal.
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

-- Recuperamos explícitamente la clave
-- de la línea temporal.
SET @test_order_detail_key =
(
    SELECT order_detail_key
    FROM order_details
    WHERE source_row_id = @test_source_row_id
);

-- Modificamos las ventas y el beneficio
-- para generar un UPDATE real.
UPDATE order_details
SET
    sales = 175.00,
    profit = 30.00
WHERE order_detail_key = @test_order_detail_key;

-- Eliminamos la línea temporal.
DELETE FROM order_details
WHERE order_detail_key = @test_order_detail_key;

-- Verificamos que se hayan generado
-- exactamente tres eventos de auditoría.
SELECT
    COUNT(*) AS audit_events_found,
    CASE
        WHEN COUNT(*) = 3 THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE table_name = 'order_details'
  AND record_key = CAST(
        @test_order_detail_key AS CHAR
      )
  AND action_type IN
  (
      'INSERT',
      'UPDATE',
      'DELETE'
  );

-- Comprobamos que exista exactamente
-- un evento de cada tipo.
SELECT
    action_type,
    COUNT(*) AS event_count,
    CASE
        WHEN COUNT(*) = 1 THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE table_name = 'order_details'
  AND record_key = CAST(
        @test_order_detail_key AS CHAR
      )
GROUP BY action_type
ORDER BY
    CASE action_type
        WHEN 'INSERT' THEN 1
        WHEN 'UPDATE' THEN 2
        WHEN 'DELETE' THEN 3
        ELSE 4
    END;

-- Inspeccionamos la secuencia completa
-- registrada por los triggers.
SELECT
    audit_id,
    action_type,
    changed_at,
    old_data,
    new_data
FROM audit_log
WHERE table_name = 'order_details'
  AND record_key = CAST(
        @test_order_detail_key AS CHAR
      )
ORDER BY audit_id;

-- Validamos los cambios registrados
-- sobre ventas y beneficio.
SELECT
    CAST(
        JSON_UNQUOTE(
            JSON_EXTRACT(
                old_data,
                '$.sales'
            )
        ) AS DECIMAL(15, 6)
    ) AS old_sales,
    CAST(
        JSON_UNQUOTE(
            JSON_EXTRACT(
                new_data,
                '$.sales'
            )
        ) AS DECIMAL(15, 6)
    ) AS new_sales,
    CAST(
        JSON_UNQUOTE(
            JSON_EXTRACT(
                old_data,
                '$.profit'
            )
        ) AS DECIMAL(15, 6)
    ) AS old_profit,
    CAST(
        JSON_UNQUOTE(
            JSON_EXTRACT(
                new_data,
                '$.profit'
            )
        ) AS DECIMAL(15, 6)
    ) AS new_profit,
    CASE
        WHEN CAST(
                JSON_UNQUOTE(
                    JSON_EXTRACT(
                        old_data,
                        '$.sales'
                    )
                ) AS DECIMAL(15, 6)
             ) = 150.00
         AND CAST(
                JSON_UNQUOTE(
                    JSON_EXTRACT(
                        new_data,
                        '$.sales'
                    )
                ) AS DECIMAL(15, 6)
             ) = 175.00
         AND CAST(
                JSON_UNQUOTE(
                    JSON_EXTRACT(
                        old_data,
                        '$.profit'
                    )
                ) AS DECIMAL(15, 6)
             ) = 25.00
         AND CAST(
                JSON_UNQUOTE(
                    JSON_EXTRACT(
                        new_data,
                        '$.profit'
                    )
                ) AS DECIMAL(15, 6)
             ) = 30.00
            THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE table_name = 'order_details'
  AND record_key = CAST(
        @test_order_detail_key AS CHAR
      )
  AND action_type = 'UPDATE';

-- Validamos la coherencia de los payloads
-- para los tres eventos de la prueba.
SELECT
    SUM(
        CASE
            WHEN action_type = 'INSERT'
             AND old_data IS NULL
             AND new_data IS NOT NULL
                THEN 1
            ELSE 0
        END
    ) AS valid_insert_events,
    SUM(
        CASE
            WHEN action_type = 'UPDATE'
             AND old_data IS NOT NULL
             AND new_data IS NOT NULL
                THEN 1
            ELSE 0
        END
    ) AS valid_update_events,
    SUM(
        CASE
            WHEN action_type = 'DELETE'
             AND old_data IS NOT NULL
             AND new_data IS NULL
                THEN 1
            ELSE 0
        END
    ) AS valid_delete_events,
    CASE
        WHEN SUM(
                CASE
                    WHEN action_type = 'INSERT'
                     AND old_data IS NULL
                     AND new_data IS NOT NULL
                        THEN 1
                    ELSE 0
                END
             ) = 1
         AND SUM(
                CASE
                    WHEN action_type = 'UPDATE'
                     AND old_data IS NOT NULL
                     AND new_data IS NOT NULL
                        THEN 1
                    ELSE 0
                END
             ) = 1
         AND SUM(
                CASE
                    WHEN action_type = 'DELETE'
                     AND old_data IS NOT NULL
                     AND new_data IS NULL
                        THEN 1
                    ELSE 0
                END
             ) = 1
            THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE table_name = 'order_details'
  AND record_key = CAST(
        @test_order_detail_key AS CHAR
      );

-- Revertimos toda la prueba.
ROLLBACK;

-- Confirmamos que ni la línea temporal
-- ni sus eventos de auditoría persistieron.
SELECT
    (
        SELECT COUNT(*)
        FROM order_details
        WHERE source_row_id = @test_source_row_id
    ) AS remaining_test_details,
    (
        SELECT COUNT(*)
        FROM audit_log
        WHERE table_name = 'order_details'
          AND record_key = CAST(
                @test_order_detail_key AS CHAR
              )
    ) AS remaining_test_audit_records;





-- Validamos que los UPDATE sin cambios reales no generen auditoría.
SET @test_order_key =
(
    SELECT order_key
    FROM orders
    ORDER BY order_key
    LIMIT 1
);

SET @test_order_detail_key =
(
    SELECT order_detail_key
    FROM order_details
    ORDER BY order_detail_key
    LIMIT 1
);

START TRANSACTION;

-- Contamos las auditorías UPDATE existentes
-- para el pedido seleccionado.
SET @orders_audit_before =
(
    SELECT COUNT(*)
    FROM audit_log
    WHERE table_name = 'orders'
      AND record_key = CAST(
            @test_order_key AS CHAR
          )
      AND action_type = 'UPDATE'
);

-- Ejecutamos un UPDATE que no modifica
-- realmente ningún valor del pedido.
UPDATE orders
SET ship_date = ship_date
WHERE order_key = @test_order_key;

-- Contamos nuevamente las auditorías.
SET @orders_audit_after =
(
    SELECT COUNT(*)
    FROM audit_log
    WHERE table_name = 'orders'
      AND record_key = CAST(
            @test_order_key AS CHAR
          )
      AND action_type = 'UPDATE'
);

-- Validamos el comportamiento del trigger de orders.
SELECT
    @orders_audit_before
        AS audit_records_before,
    @orders_audit_after
        AS audit_records_after,
    @orders_audit_after
    -
    @orders_audit_before
        AS new_audit_records,
    CASE
        WHEN
            @orders_audit_after
            -
            @orders_audit_before = 0
            THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status;

-- Contamos las auditorías UPDATE existentes
-- para la línea de pedido seleccionada.
SET @details_audit_before =
(
    SELECT COUNT(*)
    FROM audit_log
    WHERE table_name = 'order_details'
      AND record_key = CAST(
            @test_order_detail_key AS CHAR
          )
      AND action_type = 'UPDATE'
);

-- Ejecutamos un UPDATE que no modifica
-- realmente ningún valor de la línea.
UPDATE order_details
SET sales = sales
WHERE order_detail_key = @test_order_detail_key;

-- Contamos nuevamente las auditorías.
SET @details_audit_after =
(
    SELECT COUNT(*)
    FROM audit_log
    WHERE table_name = 'order_details'
      AND record_key = CAST(
            @test_order_detail_key AS CHAR
          )
      AND action_type = 'UPDATE'
);

-- Validamos el comportamiento
-- del trigger de order_details.
SELECT
    @details_audit_before
        AS audit_records_before,
    @details_audit_after
        AS audit_records_after,
    @details_audit_after
    -
    @details_audit_before
        AS new_audit_records,
    CASE
        WHEN
            @details_audit_after
            -
            @details_audit_before = 0
            THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status;

ROLLBACK;





-- Realizamos la validación global del sistema de auditoría.
SELECT
    COUNT(*) AS invalid_table_records,
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE table_name NOT IN
(
    'orders',
    'order_details'
);

-- Verificamos que no existan tipos de acción
-- diferentes de los definidos por el sistema.
SELECT
    COUNT(*) AS invalid_action_records,
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE action_type NOT IN
(
    'INSERT',
    'UPDATE',
    'DELETE'
);

-- Verificamos nuevamente la coherencia global
-- entre el tipo de acción y los payloads JSON.
SELECT
    COUNT(*) AS invalid_payload_records,
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE
    (
        action_type = 'INSERT'
        AND (
            old_data IS NOT NULL
            OR new_data IS NULL
        )
    )
    OR
    (
        action_type = 'UPDATE'
        AND (
            old_data IS NULL
            OR new_data IS NULL
        )
    )
    OR
    (
        action_type = 'DELETE'
        AND (
            old_data IS NULL
            OR new_data IS NOT NULL
        )
    );

-- Verificamos que todas las claves auditadas
-- tengan un valor identificable.
SELECT
    COUNT(*) AS invalid_record_keys,
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE record_key IS NULL
   OR TRIM(record_key) = '';

-- Verificamos que todos los eventos tengan
-- información sobre la conexión responsable.
SELECT
    COUNT(*) AS invalid_audit_metadata,
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'REVISAR'
    END AS validation_status
FROM audit_log
WHERE changed_at IS NULL
   OR changed_by IS NULL
   OR TRIM(changed_by) = ''
   OR connection_id IS NULL
   OR connection_id = 0;

-- Generamos un resumen final de las
-- validaciones críticas del sistema.
WITH validacion_final AS
(
    SELECT
        (
            SELECT COUNT(*)
            FROM information_schema.triggers
            WHERE trigger_schema = DATABASE()
              AND trigger_name IN
              (
                  'trg_orders_after_insert',
                  'trg_orders_after_update',
                  'trg_orders_after_delete',
                  'trg_order_details_after_insert',
                  'trg_order_details_after_update',
                  'trg_order_details_after_delete'
              )
        ) AS triggers_found,
        (
            SELECT COUNT(*)
            FROM information_schema.columns
            WHERE table_schema = DATABASE()
              AND table_name = 'audit_log'
              AND column_name IN
              (
                  'audit_id',
                  'table_name',
                  'record_key',
                  'action_type',
                  'changed_at',
                  'changed_by',
                  'connection_id',
                  'old_data',
                  'new_data'
              )
        ) AS audit_columns_found,
        (
            SELECT COUNT(*)
            FROM audit_log
            WHERE table_name NOT IN
            (
                'orders',
                'order_details'
            )
        ) AS invalid_table_records,
        (
            SELECT COUNT(*)
            FROM audit_log
            WHERE action_type NOT IN
            (
                'INSERT',
                'UPDATE',
                'DELETE'
            )
        ) AS invalid_action_records,
        (
            SELECT COUNT(*)
            FROM audit_log
            WHERE
                (
                    action_type = 'INSERT'
                    AND (
                        old_data IS NOT NULL
                        OR new_data IS NULL
                    )
                )
                OR
                (
                    action_type = 'UPDATE'
                    AND (
                        old_data IS NULL
                        OR new_data IS NULL
                    )
                )
                OR
                (
                    action_type = 'DELETE'
                    AND (
                        old_data IS NULL
                        OR new_data IS NOT NULL
                    )
                )
        ) AS invalid_payload_records,
        (
            SELECT COUNT(*)
            FROM audit_log
            WHERE record_key IS NULL
               OR TRIM(record_key) = ''
        ) AS invalid_record_keys,
        (
            SELECT COUNT(*)
            FROM audit_log
            WHERE changed_at IS NULL
               OR changed_by IS NULL
               OR TRIM(changed_by) = ''
               OR connection_id IS NULL
               OR connection_id = 0
        ) AS invalid_audit_metadata
)

SELECT
    triggers_found,
    audit_columns_found,
    invalid_table_records,
    invalid_action_records,
    invalid_payload_records,
    invalid_record_keys,
    invalid_audit_metadata,
    CASE
        WHEN triggers_found = 6
         AND audit_columns_found = 9
         AND invalid_table_records = 0
         AND invalid_action_records = 0
         AND invalid_payload_records = 0
         AND invalid_record_keys = 0
         AND invalid_audit_metadata = 0
            THEN 'OK'
        ELSE 'REVISAR'
    END AS audit_system_status
FROM validacion_final;