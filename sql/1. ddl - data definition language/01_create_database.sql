/*
Archivo: 01_create_database
Proyecto: superstore-analytics
Autor: Cristian Eduardo Pichardo Rico
Descripción: Este archivo crea la base de datos principal
*/

-- Antes de ejecutar cualquier consulta
-- Eliminamos la base de datos si es que llegara a existir previamente
DROP DATABASE IF EXISTS superstore_analytics;

-- Creamos la base de datos
-- Usamos UTF-8 para que permita caracteres especiales
CREATE DATABASE superstore_analytics
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

-- Seleccionamos la base de datos para trabajar sobre ella
USE superstore_analytics;