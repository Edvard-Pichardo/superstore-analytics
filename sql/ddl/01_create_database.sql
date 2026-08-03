/*
Archivo      : 01_create_database.sql
Proyecto     : SuperStore Analytics
Autor        : Eduardo Pichardo
Motor        : MySQL 8
Descripción  : Creación de la base de datos principal.
*/

-- Eliminamos la base de datos si existe para poder reconstruir
-- el proyecto desde cero durante el desarrollo.
DROP DATABASE IF EXISTS superstore_analytics;

-- Creamos la base de datos utilizando UTF-8 para soportar
-- caracteres especiales y mantener compatibilidad internacional.
CREATE DATABASE superstore_analytics
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

-- Seleccionamos la base de datos para ejecutar los siguientes scripts.
USE superstore_analytics;