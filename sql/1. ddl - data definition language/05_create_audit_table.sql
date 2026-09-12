/*
Archivo: 05_create_audit_table
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Creación de la tabla que registra los cambios en las tablas principales
             del modelo relacional. 
*/

-- Nota: Este documento puede ejecutarse inmediatamente después del archivo 04 de la carpeta ddl,
-- auqnue se utilizará hasta mucho después cuando se creen los triggers asociados a esta tabla.

USE superstore_analytics;

-- Eliminamos la tabla si existe.
DROP TABLE IF EXISTS audit_log;

-- Creamos la tabla de auditoria
CREATE TABLE audit_log(
    audit_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    table_name      VARCHAR(64) NOT NULL,
    record_key      VARCHAR(255) NOT NULL,

    action_type ENUM(
        'INSERT',
        'UPDATE',
        'DELETE'
    ) NOT NULL,

    changed_at DATETIME(6) NOT NULL
        DEFAULT CURRENT_TIMESTAMP(6),
    
    changed_by VARCHAR(288)NOT NULL,
    connection_id BIGINT UNSIGNED NOT NULL,
    old_data JSON,
    new_data JSON,

    PRIMARY KEY (audit_id),

    INDEX idx_audit_table_record
    (
        table_name,
        record_key
    ),

    INDEX idx_audit_table_date
    (
        table_name,
        changed_at
    ),

    INDEX idx_audit_action_date
    (
        action_type,
        changed_at
    ),

    CONSTRAINT chk_audit_payload
        CHECK
        (
            (
                action_type = 'INSERT'
                AND old_data IS NULL
                AND new_data IS NOT NULL
            )
            OR
            (
                action_type = 'UPDATE'
                AND old_data IS NOT NULL
                AND new_data IS NOT NULL
            )
            OR
            (
                action_type = 'DELETE'
                AND old_data IS NOT NULL
                AND new_data IS NULL
            )
        )
);

-- Válidamos la tabla que acabamos de crear.
DESCRIBE audit_log;