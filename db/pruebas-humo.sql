-- =====================================================================
-- OmniDesk · Base de datos v2 · 99 · PRUEBAS DE HUMO
-- Ejecutar DESPUÉS de db/base-de-datos.sql y db/datos-demo.sql, preferiblemente bloque por bloque
-- en MySQL Workbench. Cada bloque indica el resultado esperado.
-- Estas pruebas insertan algunas filas extra (rol 'Auditor', una conversación).
-- =====================================================================
SET NAMES utf8mb4;
USE omnidesk_db;

-- ---------- 1. ROLES -------------------------------------------------
CALL sp_leer_roles(NULL, @e, @t);                 SELECT @e AS err, @t AS msg;   -- 0 · 3 filas (Admin 25 permisos)
CALL sp_insertar_rol('Auditor', 'Solo lectura', 1, @id_rol, @e, @t);
SELECT @id_rol AS id_rol, @e AS err, @t AS msg;                                  -- 0 · id nuevo
CALL sp_insertar_rol('auditor', NULL, 1, @x, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 1062 (único, sin distinguir mayúsculas)
CALL sp_actualizar_rol(9999, 'Fantasma', NULL, NULL, 1, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 404
CALL sp_actualizar_rol(1, 'Super Admin', NULL, NULL, 1, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 403 (rol del sistema)
CALL sp_eliminar_rol(1, 1, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 403

-- ---------- 2. PERMISOS ---------------------------------------------
CALL sp_asignar_permisos_rol(@id_rol, '1, 7 ,11', 1, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 0 · "(3 asignados)"
CALL sp_asignar_permisos_rol(1, '1', 1, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 403 (Administrador intocable)
CALL sp_leer_permisos_rol(@id_rol, @e, @t);                                      -- 25 filas, 3 con asignado = 1
CALL sp_leer_permisos_usuario(3, @e, @t);                                        -- permisos del Agente (8 códigos)

-- ---------- 3. USUARIOS y protección del último admin ----------------
CALL sp_eliminar_usuario(1, 1, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 409 (único admin activo)
CALL sp_cambiar_rol_usuario(1, 3, 1, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 409
CALL sp_insertar_usuario(3, 'Duplicado', 'ADMIN@omnidesk.local', 'hash', NULL, NULL, 1, @uid, @e, @t);
SELECT @uid AS id, @e AS err, @t AS msg;                                         -- 1062 (correo normalizado a minúsculas)
CALL sp_insertar_usuario(3, 'Correo malo', 'sin-arroba', 'hash', NULL, NULL, 1, @uid, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 422
CALL sp_actualizar_usuario(9999, 'X', 'x@x.com', NULL, NULL, NULL, 1, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 404

-- ---------- 4. ROL EN USO / ELIMINACIÓN VÁLIDA ------------------------
CALL sp_eliminar_rol(@id_rol, 1, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 0 (Auditor no tiene usuarios)
CALL sp_leer_auditoria('rol', NULL, NULL, 10, @e, @t);                           -- CREAR, ASIGNAR_PERMISOS, ELIMINAR

-- ---------- 5. CANALES / CLIENTES ------------------------------------
CALL sp_eliminar_canal(1, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 409 (tiene conversaciones)
CALL sp_eliminar_cliente(1, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 409 (conversación sin resolver)
CALL sp_insertar_cliente('Otro Cliente', 'MARIA.G@email.com', NULL, NULL, @cid, @e, @t);
SELECT @cid AS id, @e AS err, @t AS msg;                                         -- 1062 (correo UNIQUE ya funciona)
CALL sp_leer_clientes(1, NULL, NULL, @e, @t);                                    -- total_tickets=1, miembro_desde=2021, •••8901

-- ---------- 6. CONVERSACIONES: triggers y ciclo de vida --------------
CALL sp_leer_conversaciones(NULL, NULL, NULL, NULL, 0, 1, NULL, NULL, NULL, @e, @t);
-- solo no leídas: 1 (3 sin leer), 2, 3, 4 (2), 6, 7

CALL sp_insertar_conversacion(2, 2, NULL, 'Prueba de ciclo', 'Alta', @cv, @e, @t);
SELECT @cv AS id_conv, @e AS err, @t AS msg;                                     -- 0
CALL sp_insertar_mensaje(@cv, 'Cliente', 'Hola, necesito ayuda', NULL, @m, @e, @t);
CALL sp_insertar_mensaje(@cv, 'Agente', 'Con gusto, ¿en qué te ayudo?', 3, @m, @e, @t);
SELECT fecha_primera_respuesta IS NOT NULL AS tiene_primera_resp, fecha_ultimo_mensaje IS NOT NULL AS tiene_ultimo
FROM conversaciones WHERE id_conversacion = @cv;                                 -- 1 · 1

CALL sp_actualizar_conversacion(@cv, 3, 'Resuelto', NULL, NULL, @e, @t);
SELECT estado, fecha_cierre IS NOT NULL AS cerrada FROM conversaciones WHERE id_conversacion = @cv;  -- Resuelto · 1

CALL sp_insertar_mensaje(@cv, 'Cliente', 'Una cosa más...', NULL, @m, @e, @t);
SELECT estado, fecha_cierre IS NULL AS sin_cierre FROM conversaciones WHERE id_conversacion = @cv;   -- Abierto · 1 (reapertura)

CALL sp_insertar_mensaje(@cv, 'Agente', '   ', 3, @m, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 422 (vacío)

CALL sp_actualizar_sentimiento(@cv, 25, @e, @t);
SELECT sentimiento_general FROM conversaciones WHERE id_conversacion = @cv;      -- Molesto
CALL sp_actualizar_sentimiento(@cv, 150, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 422

CALL sp_marcar_conversacion_leida(1, @n, @e, @t);
SELECT @n AS marcados, @e AS err;                                                -- 3

CALL sp_eliminar_conversacion(9999, @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 404

-- ---------- 7. REPORTES ----------------------------------------------
CALL sp_reporte_resumen(NULL, NULL, @e, @t);
CALL sp_reporte_mensajes_por_canal(NULL, NULL, @e, @t);
CALL sp_reporte_sentimiento(NULL, NULL, @e, @t);                                 -- siempre 3 filas
CALL sp_reporte_rendimiento_agentes(NULL, NULL, @e, @t);
CALL sp_reporte_volumen_diario(NULL, NULL, @e, @t);
CALL sp_reporte_resumen('2026-12-01', '2026-01-01', @e, @t);
SELECT @e AS err, @t AS msg;                                                     -- 422 (rango invertido)
