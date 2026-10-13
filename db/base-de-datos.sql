-- =====================================================================
-- OmniDesk · Base de datos v2 · 01 · ESQUEMA
-- Compatible con MariaDB 10.4+ (XAMPP) y MySQL 8.0+
--
-- ⚠ DESTRUCTIVO: borra y recrea TODAS las tablas de omnidesk_db (incluida la v1).
--   Si ya tienes datos que quieres conservar, haz antes un respaldo:
--   mysqldump -u root omnidesk_db > respaldo_v1.sql
-- =====================================================================
SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS omnidesk_db
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE omnidesk_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW  IF EXISTS v_bandeja_conversaciones;
DROP VIEW  IF EXISTS v_clientes_resumen;
DROP TABLE IF EXISTS auditoria;
DROP TABLE IF EXISTS mensajes;
DROP TABLE IF EXISTS conversaciones;
DROP TABLE IF EXISTS clientes;
DROP TABLE IF EXISTS canales;
DROP TABLE IF EXISTS rol_permisos;
DROP TABLE IF EXISTS permisos;
DROP TABLE IF EXISTS usuarios;
DROP TABLE IF EXISTS roles;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. ROLES  (CRUD completo + roles protegidos del sistema)
-- ---------------------------------------------------------------------
CREATE TABLE roles (
    id_rol              INT AUTO_INCREMENT PRIMARY KEY,
    nombre              VARCHAR(50)  NOT NULL,
    descripcion         VARCHAR(255) NULL,
    es_sistema          TINYINT(1)   NOT NULL DEFAULT 0,   -- 1 = no se puede borrar/renombrar/desactivar
    estado              ENUM('Activo','Inactivo') NOT NULL DEFAULT 'Activo',
    fecha_creacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_roles_nombre UNIQUE (nombre)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. PERMISOS y matriz ROL ⇄ PERMISO  (RBAC real, no solo etiquetas)
-- ---------------------------------------------------------------------
CREATE TABLE permisos (
    id_permiso  INT AUTO_INCREMENT PRIMARY KEY,
    codigo      VARCHAR(60)  NOT NULL,                      -- ej: 'conversaciones.ver_todas'
    modulo      VARCHAR(30)  NOT NULL,
    descripcion VARCHAR(150) NOT NULL,
    CONSTRAINT uq_permisos_codigo UNIQUE (codigo),
    INDEX idx_permisos_modulo (modulo)
) ENGINE=InnoDB;

CREATE TABLE rol_permisos (
    id_rol           INT NOT NULL,
    id_permiso       INT NOT NULL,
    fecha_asignacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_rol, id_permiso),
    INDEX idx_rol_permisos_permiso (id_permiso),
    CONSTRAINT fk_rp_rol     FOREIGN KEY (id_rol)     REFERENCES roles(id_rol)       ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rp_permiso FOREIGN KEY (id_permiso) REFERENCES permisos(id_permiso) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. USUARIOS (Gestión de Agentes + Mi Perfil)
-- ---------------------------------------------------------------------
CREATE TABLE usuarios (
    id_usuario          INT AUTO_INCREMENT PRIMARY KEY,
    id_rol              INT NOT NULL,
    nombre_completo     VARCHAR(100) NOT NULL,
    correo              VARCHAR(100) NOT NULL,
    password_hash       VARCHAR(255) NOT NULL,
    telefono            VARCHAR(20)  NULL,
    zona_horaria        VARCHAR(50)  NOT NULL DEFAULT 'UTC-3',
    estado              ENUM('Activo','Inactivo') NOT NULL DEFAULT 'Activo',   -- baja lógica
    presencia           ENUM('Disponible','Ausente','Desconectado') NOT NULL DEFAULT 'Desconectado',
    ultimo_acceso       DATETIME NULL,
    intentos_fallidos   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    bloqueado_hasta     DATETIME NULL,
    fecha_alta          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_usuarios_correo UNIQUE (correo),
    INDEX idx_usuarios_rol_estado (id_rol, estado),
    CONSTRAINT fk_usuarios_rol FOREIGN KEY (id_rol) REFERENCES roles(id_rol) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. CLIENTES (panel derecho del chat)
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
    id_cliente          INT AUTO_INCREMENT PRIMARY KEY,
    nombre              VARCHAR(100) NOT NULL,
    correo              VARCHAR(100) NULL,                  -- UNIQUE permite varios NULL
    telefono            VARCHAR(20)  NULL,
    nivel_lealtad       ENUM('Bronze','Silver','Gold','Platinum') NOT NULL DEFAULT 'Bronze',
    estado              ENUM('Activo','Inactivo') NOT NULL DEFAULT 'Activo',   -- baja lógica (conserva historial)
    fecha_registro      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_clientes_correo UNIQUE (correo),
    INDEX idx_clientes_nombre (nombre),
    INDEX idx_clientes_telefono (telefono)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. CANALES (Canales conectados)
-- ---------------------------------------------------------------------
CREATE TABLE canales (
    id_canal            INT AUTO_INCREMENT PRIMARY KEY,
    nombre              VARCHAR(50)  NOT NULL,
    descripcion         VARCHAR(150) NULL,
    icono               VARCHAR(40)  NULL,                  -- nombre de Material Symbols
    color_hex           CHAR(7)      NULL,                  -- ej: #25D366
    estado              ENUM('Activo','Inactivo') NOT NULL DEFAULT 'Inactivo',
    fecha_conexion      DATETIME NULL,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_canales_nombre UNIQUE (nombre)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. CONVERSACIONES / TICKETS
--    numero_ticket (TK-00001) se calcula en las vistas: MySQL no permite
--    columnas generadas sobre AUTO_INCREMENT.
-- ---------------------------------------------------------------------
CREATE TABLE conversaciones (
    id_conversacion         INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente              INT NOT NULL,
    id_canal                INT NOT NULL,
    id_agente               INT NULL,                       -- NULL = en cola sin asignar
    asunto                  VARCHAR(200) NULL,
    estado                  ENUM('Abierto','Pendiente','Resuelto') NOT NULL DEFAULT 'Abierto',
    prioridad               ENUM('Normal','Alta','Urgente')        NOT NULL DEFAULT 'Normal',
    sentimiento_general     ENUM('Satisfecho','Neutral','Molesto') NOT NULL DEFAULT 'Neutral',
    puntaje_sentimiento     TINYINT UNSIGNED NULL,          -- 0-100 (índice del gauge de la IA)
    fecha_creacion          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_ultimo_mensaje    DATETIME NULL,                  -- lo mantiene un trigger
    fecha_primera_respuesta DATETIME NULL,                  -- lo mantiene un trigger (métrica de reportes)
    fecha_cierre            DATETIME NULL,                  -- lo mantiene un trigger
    fecha_actualizacion     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_conv_puntaje CHECK (puntaje_sentimiento IS NULL OR puntaje_sentimiento <= 100),
    INDEX idx_conv_cliente        (id_cliente, fecha_creacion),
    INDEX idx_conv_agente_estado  (id_agente, estado),
    INDEX idx_conv_canal_fecha    (id_canal, fecha_creacion),
    INDEX idx_conv_estado_ultimo  (estado, fecha_ultimo_mensaje),
    INDEX idx_conv_creacion       (fecha_creacion),
    CONSTRAINT fk_conv_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_conv_canal   FOREIGN KEY (id_canal)   REFERENCES canales(id_canal)    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_conv_agente  FOREIGN KEY (id_agente)  REFERENCES usuarios(id_usuario) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. MENSAJES
-- ---------------------------------------------------------------------
CREATE TABLE mensajes (
    id_mensaje      INT AUTO_INCREMENT PRIMARY KEY,
    id_conversacion INT NOT NULL,
    remitente       ENUM('Cliente','Agente','Sistema') NOT NULL,
    id_usuario      INT NULL,                               -- agente autor (solo si remitente='Agente')
    contenido       TEXT NOT NULL,
    leido           TINYINT(1) NOT NULL DEFAULT 0,
    fecha_envio     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_lectura   DATETIME NULL,
    INDEX idx_msg_conv_fecha (id_conversacion, fecha_envio, id_mensaje),
    INDEX idx_msg_no_leidos  (id_conversacion, remitente, leido),
    CONSTRAINT fk_msg_conv    FOREIGN KEY (id_conversacion) REFERENCES conversaciones(id_conversacion) ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT fk_msg_usuario FOREIGN KEY (id_usuario)      REFERENCES usuarios(id_usuario)            ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. AUDITORÍA (cambios sensibles: roles, permisos, usuarios, contraseñas)
-- ---------------------------------------------------------------------
CREATE TABLE auditoria (
    id_auditoria BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_usuario   INT NULL,                                  -- quien ejecutó la acción
    accion       VARCHAR(50)  NOT NULL,
    entidad      VARCHAR(50)  NOT NULL,
    id_entidad   INT NULL,
    detalle      VARCHAR(500) NULL,
    ip           VARCHAR(45)  NULL,
    fecha        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_aud_entidad (entidad, id_entidad),
    INDEX idx_aud_usuario (id_usuario, fecha),
    INDEX idx_aud_fecha   (fecha),
    CONSTRAINT fk_aud_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- TRIGGERS: reglas que deben cumplirse sin importar quién escriba en la BD
-- =====================================================================
DELIMITER //

-- Al crear: deriva el sentimiento del puntaje y fija cierre si nace resuelta.
DROP TRIGGER IF EXISTS trg_conversaciones_bi//
CREATE TRIGGER trg_conversaciones_bi BEFORE INSERT ON conversaciones
FOR EACH ROW
BEGIN
    IF NEW.puntaje_sentimiento IS NOT NULL THEN
        SET NEW.sentimiento_general = CASE
            WHEN NEW.puntaje_sentimiento < 40 THEN 'Molesto'
            WHEN NEW.puntaje_sentimiento < 70 THEN 'Neutral'
            ELSE 'Satisfecho' END;
    END IF;
    IF NEW.estado = 'Resuelto' AND NEW.fecha_cierre IS NULL THEN
        SET NEW.fecha_cierre = NOW();
    END IF;
END//

-- Al actualizar: mantiene fecha_cierre y re-deriva el sentimiento si cambia el puntaje.
DROP TRIGGER IF EXISTS trg_conversaciones_bu//
CREATE TRIGGER trg_conversaciones_bu BEFORE UPDATE ON conversaciones
FOR EACH ROW
BEGIN
    IF NEW.estado = 'Resuelto' AND OLD.estado <> 'Resuelto' THEN
        SET NEW.fecha_cierre = NOW();
    ELSEIF NEW.estado <> 'Resuelto' AND OLD.estado = 'Resuelto' THEN
        SET NEW.fecha_cierre = NULL;
    END IF;

    IF NEW.puntaje_sentimiento IS NOT NULL
       AND NOT (NEW.puntaje_sentimiento <=> OLD.puntaje_sentimiento) THEN
        SET NEW.sentimiento_general = CASE
            WHEN NEW.puntaje_sentimiento < 40 THEN 'Molesto'
            WHEN NEW.puntaje_sentimiento < 70 THEN 'Neutral'
            ELSE 'Satisfecho' END;
    END IF;
END//

-- Al llegar un mensaje: actualiza último mensaje, primera respuesta y reabre si el cliente escribe en una resuelta.
-- (Si no quieres la reapertura automática, elimina la línea del campo 'estado'.)
DROP TRIGGER IF EXISTS trg_mensajes_ai//
CREATE TRIGGER trg_mensajes_ai AFTER INSERT ON mensajes
FOR EACH ROW
BEGIN
    UPDATE conversaciones
    SET fecha_primera_respuesta = IF(NEW.remitente = 'Agente' AND fecha_primera_respuesta IS NULL,
                                     NEW.fecha_envio, fecha_primera_respuesta),
        estado                  = IF(NEW.remitente = 'Cliente' AND estado = 'Resuelto', 'Abierto', estado),
        fecha_ultimo_mensaje    = NEW.fecha_envio
    WHERE id_conversacion = NEW.id_conversacion;
END//

DELIMITER ;

-- =====================================================================
-- VISTAS: lo que la UI muestra ya calculado
-- =====================================================================
CREATE OR REPLACE VIEW v_bandeja_conversaciones AS
SELECT  c.id_conversacion,
        CONCAT('TK-', LPAD(c.id_conversacion, 5, '0')) AS numero_ticket,
        c.id_cliente,  cl.nombre AS cliente, cl.nivel_lealtad,
        c.id_canal,    cn.nombre AS canal, cn.icono AS canal_icono, cn.color_hex AS canal_color,
        c.id_agente,   u.nombre_completo AS agente,
        c.asunto, c.estado, c.prioridad, c.sentimiento_general, c.puntaje_sentimiento,
        (SELECT COUNT(*) FROM mensajes m
          WHERE m.id_conversacion = c.id_conversacion AND m.remitente = 'Cliente' AND m.leido = 0) AS mensajes_no_leidos,
        (SELECT m2.contenido FROM mensajes m2
          WHERE m2.id_conversacion = c.id_conversacion
          ORDER BY m2.fecha_envio DESC, m2.id_mensaje DESC LIMIT 1) AS ultimo_mensaje,
        c.fecha_creacion, c.fecha_ultimo_mensaje, c.fecha_primera_respuesta, c.fecha_cierre
FROM conversaciones c
JOIN clientes cl ON cl.id_cliente = c.id_cliente
JOIN canales  cn ON cn.id_canal   = c.id_canal
LEFT JOIN usuarios u ON u.id_usuario = c.id_agente;

CREATE OR REPLACE VIEW v_clientes_resumen AS
SELECT  cl.id_cliente, cl.nombre, cl.correo, cl.telefono,
        CASE WHEN cl.telefono IS NULL OR cl.telefono = '' THEN NULL
             ELSE CONCAT('•••', RIGHT(cl.telefono, 4)) END AS telefono_enmascarado,
        cl.nivel_lealtad, cl.estado,
        (SELECT COUNT(*) FROM conversaciones c WHERE c.id_cliente = cl.id_cliente) AS total_tickets,
        (SELECT COUNT(*) FROM conversaciones c
          WHERE c.id_cliente = cl.id_cliente AND c.estado <> 'Resuelto') AS tickets_abiertos,
        YEAR(cl.fecha_registro) AS miembro_desde,
        cl.fecha_registro
FROM clientes cl;
-- =====================================================================
-- OmniDesk · Base de datos v2 · 02 · DATOS INICIALES (catálogos)
-- Roles, permisos, matriz RBAC y canales. No crea usuarios.
-- =====================================================================
SET NAMES utf8mb4;
USE omnidesk_db;

-- ---------------------------------------------------------------------
-- Roles (los 3 del sistema quedan protegidos: es_sistema = 1)
-- ---------------------------------------------------------------------
INSERT INTO roles (id_rol, nombre, descripcion, es_sistema, estado) VALUES
(1, 'Administrador', 'Acceso total: usuarios, roles, canales, reportes y auditoría.',                1, 'Activo'),
(2, 'Supervisor',    'Supervisa conversaciones y agentes, asigna casos y consulta reportes.',       1, 'Activo'),
(3, 'Agente',        'Atiende las conversaciones que tiene asignadas y consulta clientes.',         1, 'Activo');

-- ---------------------------------------------------------------------
-- Catálogo de permisos
-- ---------------------------------------------------------------------
INSERT INTO permisos (codigo, modulo, descripcion) VALUES
('conversaciones.ver_propias',  'conversaciones', 'Ver las conversaciones asignadas a sí mismo'),
('conversaciones.ver_todas',    'conversaciones', 'Ver todas las conversaciones y la cola sin asignar'),
('conversaciones.responder',    'conversaciones', 'Enviar mensajes en una conversación'),
('conversaciones.asignar',      'conversaciones', 'Asignar o reasignar conversaciones a agentes'),
('conversaciones.resolver',     'conversaciones', 'Cambiar estado y cerrar conversaciones'),
('conversaciones.eliminar',     'conversaciones', 'Eliminar conversaciones definitivamente'),
('clientes.ver',                'clientes',       'Consultar clientes'),
('clientes.crear',              'clientes',       'Registrar clientes'),
('clientes.editar',             'clientes',       'Editar datos de clientes'),
('clientes.eliminar',           'clientes',       'Dar de baja clientes'),
('canales.ver',                 'canales',        'Ver canales conectados'),
('canales.gestionar',           'canales',        'Crear, editar, activar y eliminar canales'),
('agentes.ver',                 'agentes',        'Ver la lista de agentes'),
('agentes.crear',               'agentes',        'Registrar agentes'),
('agentes.editar',              'agentes',        'Editar agentes y cambiar su rol'),
('agentes.desactivar',          'agentes',        'Desactivar agentes'),
('roles.ver',                   'roles',          'Ver roles y sus permisos'),
('roles.crear',                 'roles',          'Crear roles'),
('roles.editar',                'roles',          'Editar roles'),
('roles.eliminar',              'roles',          'Eliminar roles'),
('roles.asignar_permisos',      'roles',          'Modificar los permisos de un rol'),
('reportes.ver',                'reportes',       'Ver reportes de atención'),
('reportes.exportar',           'reportes',       'Exportar reportes'),
('auditoria.ver',               'auditoria',      'Consultar el registro de auditoría'),
('perfil.editar_propio',        'perfil',         'Editar el propio perfil y contraseña');

-- ---------------------------------------------------------------------
-- Matriz RBAC
-- ---------------------------------------------------------------------
-- Administrador: todos los permisos
INSERT INTO rol_permisos (id_rol, id_permiso)
SELECT 1, id_permiso FROM permisos;

-- Supervisor
INSERT INTO rol_permisos (id_rol, id_permiso)
SELECT 2, id_permiso FROM permisos
WHERE codigo IN (
  'conversaciones.ver_propias','conversaciones.ver_todas','conversaciones.responder',
  'conversaciones.asignar','conversaciones.resolver',
  'clientes.ver','clientes.crear','clientes.editar',
  'canales.ver','agentes.ver','roles.ver',
  'reportes.ver','reportes.exportar','perfil.editar_propio');

-- Agente
INSERT INTO rol_permisos (id_rol, id_permiso)
SELECT 3, id_permiso FROM permisos
WHERE codigo IN (
  'conversaciones.ver_propias','conversaciones.responder','conversaciones.resolver',
  'clientes.ver','clientes.crear','clientes.editar',
  'canales.ver','perfil.editar_propio');

-- ---------------------------------------------------------------------
-- Canales (colores según DESIGN.md)
-- ---------------------------------------------------------------------
INSERT INTO canales (id_canal, nombre, descripcion, icono, color_hex, estado, fecha_conexion) VALUES
(1, 'WhatsApp',  'WhatsApp Business API',         'chat',         '#25D366', 'Activo', NOW()),
(2, 'Email',     'Bandeja de correo de soporte',  'mail',         '#2563EB', 'Activo', NOW()),
(3, 'Web Chat',  'Widget de chat del sitio web',  'language',     '#8B5CF6', 'Activo', NOW()),
(4, 'Instagram', 'Mensajes directos de Instagram','photo_camera', '#E1306C', 'Activo', NOW());
-- =====================================================================
-- OmniDesk · Base de datos v2 · 03 · SP de ROLES, PERMISOS y AUDITORÍA
--
-- CONVENCIÓN DE ERRORES (válida para todos los SP de la v2)
--   p_error_num = 0     OK
--   p_error_num = 404   El registro no existe
--   p_error_num = 403   Operación prohibida (roles del sistema, etc.)
--   p_error_num = 409   Conflicto con el estado actual (en uso, último admin...)
--   p_error_num = 422   Dato inválido
--   p_error_num = 1048 / 1062 / 1451 / 1452   Errores de MySQL (nulo, duplicado, FK)
--   Cualquier otro valor = errno real de MySQL (error inesperado)
-- Siempre revisar p_error_num ANTES de usar el result set: si es != 0,
-- el SP puede no devolver ninguno.
-- =====================================================================
SET NAMES utf8mb4;
USE omnidesk_db;
DELIMITER //

-- ---------------------------------------------------------------------
-- Auditoría (la usan los demás SP y también puede llamarla el backend)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_auditoria//
CREATE PROCEDURE sp_registrar_auditoria(
    IN p_id_usuario INT, IN p_accion VARCHAR(50), IN p_entidad VARCHAR(50),
    IN p_id_entidad INT, IN p_detalle VARCHAR(500), IN p_ip VARCHAR(45)
)
BEGIN
    INSERT INTO auditoria (id_usuario, accion, entidad, id_entidad, detalle, ip)
    VALUES (p_id_usuario, p_accion, p_entidad, p_id_entidad, LEFT(p_detalle, 500), p_ip);
END//

-- ---------------------------------------------------------------------
-- ROLES · CREATE
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_insertar_rol//
CREATE PROCEDURE sp_insertar_rol(
    IN  p_nombre VARCHAR(50), IN p_descripcion VARCHAR(255), IN p_id_actor INT,
    OUT p_id_rol INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1048 BEGIN ROLLBACK; SET p_id_rol = NULL; SET p_error_num = 1048; SET p_error_text = 'Hay un campo obligatorio sin valor.'; END;
    DECLARE EXIT HANDLER FOR 1062 BEGIN ROLLBACK; SET p_id_rol = NULL; SET p_error_num = 1062; SET p_error_text = 'Ya existe un rol con ese nombre.'; END;
    DECLARE EXIT HANDLER FOR 1452 BEGIN ROLLBACK; SET p_id_rol = NULL; SET p_error_num = 1452; SET p_error_text = 'Referencia inválida: verifique los IDs enviados.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_id_rol = NULL; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error inesperado en la base de datos.';
    END;

    SET p_id_rol = NULL; SET p_error_num = 0; SET p_error_text = 'Rol creado correctamente.';
    SET p_nombre = TRIM(p_nombre);
    IF p_nombre IS NULL OR p_nombre = '' THEN
        SET p_error_num = 422; SET p_error_text = 'El nombre del rol es obligatorio.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    INSERT INTO roles (nombre, descripcion) VALUES (p_nombre, NULLIF(TRIM(p_descripcion), ''));
    SET p_id_rol = LAST_INSERT_ID();
    CALL sp_registrar_auditoria(p_id_actor, 'CREAR', 'rol', p_id_rol, CONCAT('nombre=', p_nombre), NULL);
    COMMIT;
END//

-- ---------------------------------------------------------------------
-- ROLES · READ  (NULL = todos). Incluye conteo de usuarios y permisos.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_leer_roles//
CREATE PROCEDURE sp_leer_roles(
    IN p_id_rol INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al consultar roles.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';

    IF p_id_rol IS NOT NULL THEN
        SELECT COUNT(*) INTO v_existe FROM roles WHERE id_rol = p_id_rol;
        IF v_existe = 0 THEN
            SET p_error_num = 404; SET p_error_text = 'El rol no existe.'; LEAVE proc;
        END IF;
    END IF;

    SELECT r.id_rol, r.nombre, r.descripcion, r.es_sistema, r.estado,
           r.fecha_creacion, r.fecha_actualizacion,
           (SELECT COUNT(*) FROM usuarios u WHERE u.id_rol = r.id_rol)       AS total_usuarios,
           (SELECT COUNT(*) FROM rol_permisos rp WHERE rp.id_rol = r.id_rol) AS total_permisos
    FROM roles r
    WHERE p_id_rol IS NULL OR r.id_rol = p_id_rol
    ORDER BY r.id_rol;
END//

-- ---------------------------------------------------------------------
-- ROLES · UPDATE  (p_estado NULL = no cambiar)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_actualizar_rol//
CREATE PROCEDURE sp_actualizar_rol(
    IN  p_id_rol INT, IN p_nombre VARCHAR(50), IN p_descripcion VARCHAR(255),
    IN  p_estado VARCHAR(10), IN p_id_actor INT,
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_sistema TINYINT(1) DEFAULT 0;
    DECLARE v_nombre_actual VARCHAR(50);
    DECLARE v_activos INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1048 BEGIN ROLLBACK; SET p_error_num = 1048; SET p_error_text = 'Hay un campo obligatorio sin valor.'; END;
    DECLARE EXIT HANDLER FOR 1062 BEGIN ROLLBACK; SET p_error_num = 1062; SET p_error_text = 'Ya existe otro rol con ese nombre.'; END;
    DECLARE EXIT HANDLER FOR 1452 BEGIN ROLLBACK; SET p_error_num = 1452; SET p_error_text = 'Referencia inválida: verifique los IDs enviados.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error inesperado en la base de datos.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Rol actualizado correctamente.';
    SET p_nombre = TRIM(p_nombre);
    IF p_nombre IS NULL OR p_nombre = '' THEN
        SET p_error_num = 422; SET p_error_text = 'El nombre del rol es obligatorio.'; LEAVE proc;
    END IF;
    IF p_estado IS NOT NULL AND p_estado NOT IN ('Activo', 'Inactivo') THEN
        SET p_error_num = 422; SET p_error_text = 'Estado inválido (use Activo o Inactivo).'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_existe FROM roles WHERE id_rol = p_id_rol;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El rol no existe.'; LEAVE proc;
    END IF;

    SELECT nombre, es_sistema INTO v_nombre_actual, v_sistema FROM roles WHERE id_rol = p_id_rol;
    IF v_sistema = 1 THEN
        IF CAST(p_nombre AS BINARY) <> CAST(v_nombre_actual AS BINARY) THEN
            SET p_error_num = 403; SET p_error_text = 'Los roles del sistema no se pueden renombrar.'; LEAVE proc;
        END IF;
        IF p_estado = 'Inactivo' THEN
            SET p_error_num = 403; SET p_error_text = 'Los roles del sistema no se pueden desactivar.'; LEAVE proc;
        END IF;
    END IF;

    IF p_estado = 'Inactivo' THEN
        SELECT COUNT(*) INTO v_activos FROM usuarios WHERE id_rol = p_id_rol AND estado = 'Activo';
        IF v_activos > 0 THEN
            SET p_error_num = 409;
            SET p_error_text = CONCAT('No se puede desactivar: ', v_activos, ' usuario(s) activos tienen este rol.');
            LEAVE proc;
        END IF;
    END IF;

    START TRANSACTION;
    UPDATE roles
       SET nombre = p_nombre, descripcion = NULLIF(TRIM(p_descripcion), ''), estado = COALESCE(p_estado, estado)
     WHERE id_rol = p_id_rol;
    CALL sp_registrar_auditoria(p_id_actor, 'ACTUALIZAR', 'rol', p_id_rol,
         CONCAT('nombre=', p_nombre, '; estado=', COALESCE(p_estado, 'sin cambio')), NULL);
    COMMIT;
END//

-- ---------------------------------------------------------------------
-- ROLES · DELETE  (físico; bloqueado para roles del sistema o con usuarios)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_eliminar_rol//
CREATE PROCEDURE sp_eliminar_rol(
    IN p_id_rol INT, IN p_id_actor INT,
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_sistema TINYINT(1) DEFAULT 0;
    DECLARE v_nombre VARCHAR(50);
    DECLARE v_usuarios INT DEFAULT 0;
    DECLARE v_filas INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1451 BEGIN ROLLBACK; SET p_error_num = 1451; SET p_error_text = 'No se puede eliminar: el rol está en uso.'; END;
    DECLARE EXIT HANDLER FOR 1452 BEGIN ROLLBACK; SET p_error_num = 1452; SET p_error_text = 'Referencia inválida: verifique los IDs enviados.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error inesperado en la base de datos.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Rol eliminado correctamente.';

    SELECT COUNT(*) INTO v_existe FROM roles WHERE id_rol = p_id_rol;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El rol no existe.'; LEAVE proc;
    END IF;

    SELECT es_sistema, nombre INTO v_sistema, v_nombre FROM roles WHERE id_rol = p_id_rol;
    IF v_sistema = 1 THEN
        SET p_error_num = 403; SET p_error_text = 'Los roles del sistema no se pueden eliminar.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_usuarios FROM usuarios WHERE id_rol = p_id_rol;
    IF v_usuarios > 0 THEN
        SET p_error_num = 409;
        SET p_error_text = CONCAT('No se puede eliminar: ', v_usuarios, ' usuario(s) tienen este rol. Reasígnelos primero.');
        LEAVE proc;
    END IF;

    START TRANSACTION;
    DELETE FROM roles WHERE id_rol = p_id_rol;
    SET v_filas = ROW_COUNT();
    IF v_filas = 0 THEN
        ROLLBACK;
        SET p_error_num = 404; SET p_error_text = 'El rol no existe.'; LEAVE proc;
    END IF;
    CALL sp_registrar_auditoria(p_id_actor, 'ELIMINAR', 'rol', p_id_rol, CONCAT('nombre=', v_nombre), NULL);
    COMMIT;
END//

-- ---------------------------------------------------------------------
-- PERMISOS · catálogo completo
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_leer_permisos//
CREATE PROCEDURE sp_leer_permisos(OUT p_error_num INT, OUT p_error_text VARCHAR(255))
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al consultar permisos.';
    END;
    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';

    SELECT id_permiso, codigo, modulo, descripcion FROM permisos ORDER BY modulo, codigo;
END//

-- ---------------------------------------------------------------------
-- PERMISOS · matriz de un rol (todos los permisos + flag "asignado")
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_leer_permisos_rol//
CREATE PROCEDURE sp_leer_permisos_rol(
    IN p_id_rol INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al consultar permisos del rol.';
    END;
    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';

    SELECT COUNT(*) INTO v_existe FROM roles WHERE id_rol = p_id_rol;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El rol no existe.'; LEAVE proc;
    END IF;

    SELECT p.id_permiso, p.codigo, p.modulo, p.descripcion,
           (rp.id_rol IS NOT NULL) AS asignado
    FROM permisos p
    LEFT JOIN rol_permisos rp ON rp.id_permiso = p.id_permiso AND rp.id_rol = p_id_rol
    ORDER BY p.modulo, p.codigo;
END//

-- ---------------------------------------------------------------------
-- PERMISOS · sincronizar (reemplaza el conjunto completo del rol)
-- p_ids_permisos: IDs separados por coma, sin corchetes. Ej: '1,3,7,12'
-- Cadena vacía o NULL = quitar todos los permisos.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_asignar_permisos_rol//
CREATE PROCEDURE sp_asignar_permisos_rol(
    IN p_id_rol INT, IN p_ids_permisos VARCHAR(2000), IN p_id_actor INT,
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_sistema TINYINT(1) DEFAULT 0;
    DECLARE v_nombre VARCHAR(50);
    DECLARE v_total INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1452 BEGIN ROLLBACK; SET p_error_num = 1452; SET p_error_text = 'Referencia inválida: verifique los IDs enviados.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error inesperado en la base de datos.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Permisos actualizados correctamente.';
    SET p_ids_permisos = REPLACE(COALESCE(p_ids_permisos, ''), ' ', '');

    SELECT COUNT(*) INTO v_existe FROM roles WHERE id_rol = p_id_rol;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El rol no existe.'; LEAVE proc;
    END IF;

    SELECT nombre, es_sistema INTO v_nombre, v_sistema FROM roles WHERE id_rol = p_id_rol;
    IF v_sistema = 1 AND v_nombre = 'Administrador' THEN
        SET p_error_num = 403; SET p_error_text = 'El rol Administrador siempre conserva todos los permisos.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    DELETE FROM rol_permisos
     WHERE id_rol = p_id_rol AND FIND_IN_SET(id_permiso, p_ids_permisos) = 0;

    INSERT IGNORE INTO rol_permisos (id_rol, id_permiso)
    SELECT p_id_rol, id_permiso FROM permisos WHERE FIND_IN_SET(id_permiso, p_ids_permisos) > 0;

    SELECT COUNT(*) INTO v_total FROM rol_permisos WHERE id_rol = p_id_rol;
    CALL sp_registrar_auditoria(p_id_actor, 'ASIGNAR_PERMISOS', 'rol', p_id_rol,
         CONCAT('permisos asignados=', v_total), NULL);
    COMMIT;

    SET p_error_text = CONCAT('Permisos actualizados correctamente (', v_total, ' asignados).');
END//

DELIMITER ;
-- =====================================================================
-- OmniDesk · Base de datos v2 · 04 · SP de USUARIOS / AGENTES
-- Incluye soporte para el login del backend (Paso C) y protección
-- contra quedarse sin ningún Administrador activo.
-- =====================================================================
SET NAMES utf8mb4;
USE omnidesk_db;
DELIMITER //

-- ---------------------------------------------------------------------
-- fn_es_ultimo_admin: 1 si el usuario es el ÚNICO Administrador activo
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_es_ultimo_admin//
CREATE FUNCTION fn_es_ultimo_admin(p_id_usuario INT) RETURNS TINYINT(1)
READS SQL DATA
BEGIN
    DECLARE v_es_admin INT DEFAULT 0;
    DECLARE v_otros INT DEFAULT 0;

    SELECT COUNT(*) INTO v_es_admin
      FROM usuarios u JOIN roles r ON r.id_rol = u.id_rol
     WHERE u.id_usuario = p_id_usuario AND u.estado = 'Activo'
       AND r.nombre = 'Administrador' AND r.es_sistema = 1;
    IF v_es_admin = 0 THEN RETURN 0; END IF;

    SELECT COUNT(*) INTO v_otros
      FROM usuarios u JOIN roles r ON r.id_rol = u.id_rol
     WHERE u.id_usuario <> p_id_usuario AND u.estado = 'Activo'
       AND r.nombre = 'Administrador' AND r.es_sistema = 1;

    RETURN IF(v_otros = 0, 1, 0);
END//

-- ---------------------------------------------------------------------
-- USUARIOS · CREATE
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_insertar_usuario//
CREATE PROCEDURE sp_insertar_usuario(
    IN  p_id_rol INT, IN p_nombre VARCHAR(100), IN p_correo VARCHAR(100),
    IN  p_password_hash VARCHAR(255), IN p_telefono VARCHAR(20), IN p_zona_horaria VARCHAR(50),
    IN  p_id_actor INT,
    OUT p_id_usuario INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_rol_ok INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1048 BEGIN ROLLBACK; SET p_id_usuario = NULL; SET p_error_num = 1048; SET p_error_text = 'Hay un campo obligatorio sin valor.'; END;
    DECLARE EXIT HANDLER FOR 1062 BEGIN ROLLBACK; SET p_id_usuario = NULL; SET p_error_num = 1062; SET p_error_text = 'El correo electrónico ya está registrado.'; END;
    DECLARE EXIT HANDLER FOR 1452 BEGIN ROLLBACK; SET p_id_usuario = NULL; SET p_error_num = 1452; SET p_error_text = 'Referencia inválida: verifique los IDs enviados.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_id_usuario = NULL; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error inesperado en la base de datos.';
    END;

    SET p_id_usuario = NULL; SET p_error_num = 0; SET p_error_text = 'Usuario creado correctamente.';
    SET p_nombre = TRIM(p_nombre);
    SET p_correo = LOWER(TRIM(p_correo));
    SET p_zona_horaria = COALESCE(NULLIF(TRIM(p_zona_horaria), ''), 'UTC-3');

    IF p_nombre IS NULL OR p_nombre = '' THEN
        SET p_error_num = 422; SET p_error_text = 'El nombre es obligatorio.'; LEAVE proc;
    END IF;
    IF p_correo IS NULL OR p_correo NOT REGEXP '^[^@ ]+@[^@ ]+\\.[^@ ]+$' THEN
        SET p_error_num = 422; SET p_error_text = 'El correo electrónico no es válido.'; LEAVE proc;
    END IF;
    IF p_password_hash IS NULL OR p_password_hash = '' THEN
        SET p_error_num = 422; SET p_error_text = 'La contraseña (hash) es obligatoria.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_rol_ok FROM roles WHERE id_rol = p_id_rol AND estado = 'Activo';
    IF v_rol_ok = 0 THEN
        SET p_error_num = 422; SET p_error_text = 'El rol no existe o está inactivo.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    INSERT INTO usuarios (id_rol, nombre_completo, correo, password_hash, telefono, zona_horaria)
    VALUES (p_id_rol, p_nombre, p_correo, p_password_hash, NULLIF(TRIM(p_telefono), ''), p_zona_horaria);
    SET p_id_usuario = LAST_INSERT_ID();
    CALL sp_registrar_auditoria(p_id_actor, 'CREAR', 'usuario', p_id_usuario,
         CONCAT('correo=', p_correo, '; id_rol=', p_id_rol), NULL);
    COMMIT;
END//

-- ---------------------------------------------------------------------
-- USUARIOS · READ  (filtros opcionales; NULL = sin filtro)
-- Nunca devuelve password_hash.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_leer_usuarios//
CREATE PROCEDURE sp_leer_usuarios(
    IN p_id_usuario INT, IN p_id_rol INT, IN p_estado VARCHAR(10),
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al consultar usuarios.';
    END;
    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';

    IF p_id_usuario IS NOT NULL THEN
        SELECT COUNT(*) INTO v_existe FROM usuarios WHERE id_usuario = p_id_usuario;
        IF v_existe = 0 THEN
            SET p_error_num = 404; SET p_error_text = 'El usuario no existe.'; LEAVE proc;
        END IF;
    END IF;

    SELECT u.id_usuario, u.id_rol, r.nombre AS rol, u.nombre_completo, u.correo, u.telefono,
           u.zona_horaria, u.estado, u.presencia, u.ultimo_acceso, u.fecha_alta,
           (SELECT COUNT(*) FROM conversaciones c
             WHERE c.id_agente = u.id_usuario AND c.estado <> 'Resuelto') AS conversaciones_activas
    FROM usuarios u
    JOIN roles r ON r.id_rol = u.id_rol
    WHERE (p_id_usuario IS NULL OR u.id_usuario = p_id_usuario)
      AND (p_id_rol     IS NULL OR u.id_rol     = p_id_rol)
      AND (p_estado     IS NULL OR u.estado     = p_estado)
    ORDER BY u.nombre_completo;
END//

-- ---------------------------------------------------------------------
-- USUARIOS · UPDATE (datos + estado; el rol se cambia con sp_cambiar_rol_usuario)
-- p_estado NULL = no cambiar.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_actualizar_usuario//
CREATE PROCEDURE sp_actualizar_usuario(
    IN  p_id_usuario INT, IN p_nombre VARCHAR(100), IN p_correo VARCHAR(100),
    IN  p_telefono VARCHAR(20), IN p_zona_horaria VARCHAR(50), IN p_estado VARCHAR(10),
    IN  p_id_actor INT,
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1048 BEGIN ROLLBACK; SET p_error_num = 1048; SET p_error_text = 'Hay un campo obligatorio sin valor.'; END;
    DECLARE EXIT HANDLER FOR 1062 BEGIN ROLLBACK; SET p_error_num = 1062; SET p_error_text = 'El correo ya pertenece a otro usuario.'; END;
    DECLARE EXIT HANDLER FOR 1452 BEGIN ROLLBACK; SET p_error_num = 1452; SET p_error_text = 'Referencia inválida: verifique los IDs enviados.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error inesperado en la base de datos.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Usuario actualizado correctamente.';
    SET p_nombre = TRIM(p_nombre);
    SET p_correo = LOWER(TRIM(p_correo));
    SET p_zona_horaria = COALESCE(NULLIF(TRIM(p_zona_horaria), ''), 'UTC-3');

    IF p_nombre IS NULL OR p_nombre = '' THEN
        SET p_error_num = 422; SET p_error_text = 'El nombre es obligatorio.'; LEAVE proc;
    END IF;
    IF p_correo IS NULL OR p_correo NOT REGEXP '^[^@ ]+@[^@ ]+\\.[^@ ]+$' THEN
        SET p_error_num = 422; SET p_error_text = 'El correo electrónico no es válido.'; LEAVE proc;
    END IF;
    IF p_estado IS NOT NULL AND p_estado NOT IN ('Activo', 'Inactivo') THEN
        SET p_error_num = 422; SET p_error_text = 'Estado inválido (use Activo o Inactivo).'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_existe FROM usuarios WHERE id_usuario = p_id_usuario;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El usuario no existe.'; LEAVE proc;
    END IF;

    IF p_estado = 'Inactivo' AND fn_es_ultimo_admin(p_id_usuario) = 1 THEN
        SET p_error_num = 409; SET p_error_text = 'No se puede desactivar al único Administrador activo.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    UPDATE usuarios
       SET nombre_completo = p_nombre, correo = p_correo, telefono = NULLIF(TRIM(p_telefono), ''),
           zona_horaria = p_zona_horaria, estado = COALESCE(p_estado, estado)
     WHERE id_usuario = p_id_usuario;

    -- Si se desactiva, sus casos abiertos vuelven a la cola sin asignar
    IF p_estado = 'Inactivo' THEN
        UPDATE usuarios SET presencia = 'Desconectado' WHERE id_usuario = p_id_usuario;
        UPDATE conversaciones SET id_agente = NULL
         WHERE id_agente = p_id_usuario AND estado <> 'Resuelto';
    END IF;

    CALL sp_registrar_auditoria(p_id_actor, 'ACTUALIZAR', 'usuario', p_id_usuario,
         CONCAT('correo=', p_correo, '; estado=', COALESCE(p_estado, 'sin cambio')), NULL);
    COMMIT;
END//

-- ---------------------------------------------------------------------
-- USUARIOS · cambiar rol
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_cambiar_rol_usuario//
CREATE PROCEDURE sp_cambiar_rol_usuario(
    IN  p_id_usuario INT, IN p_id_rol INT, IN p_id_actor INT,
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_rol_ok INT DEFAULT 0;
    DECLARE v_nuevo_es_admin INT DEFAULT 0;
    DECLARE v_rol_anterior INT;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1452 BEGIN ROLLBACK; SET p_error_num = 1452; SET p_error_text = 'Referencia inválida: verifique los IDs enviados.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error inesperado en la base de datos.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Rol del usuario actualizado correctamente.';

    SELECT COUNT(*) INTO v_existe FROM usuarios WHERE id_usuario = p_id_usuario;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El usuario no existe.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_rol_ok FROM roles WHERE id_rol = p_id_rol AND estado = 'Activo';
    IF v_rol_ok = 0 THEN
        SET p_error_num = 422; SET p_error_text = 'El rol no existe o está inactivo.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_nuevo_es_admin FROM roles
     WHERE id_rol = p_id_rol AND nombre = 'Administrador' AND es_sistema = 1;
    IF v_nuevo_es_admin = 0 AND fn_es_ultimo_admin(p_id_usuario) = 1 THEN
        SET p_error_num = 409; SET p_error_text = 'No se puede quitar el rol al único Administrador activo.'; LEAVE proc;
    END IF;

    SELECT id_rol INTO v_rol_anterior FROM usuarios WHERE id_usuario = p_id_usuario;

    START TRANSACTION;
    UPDATE usuarios SET id_rol = p_id_rol WHERE id_usuario = p_id_usuario;
    CALL sp_registrar_auditoria(p_id_actor, 'CAMBIAR_ROL', 'usuario', p_id_usuario,
         CONCAT('id_rol: ', v_rol_anterior, ' -> ', p_id_rol), NULL);
    COMMIT;
END//

-- ---------------------------------------------------------------------
-- USUARIOS · DELETE lógico (baja). Sus casos abiertos vuelven a la cola.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_eliminar_usuario//
CREATE PROCEDURE sp_eliminar_usuario(
    IN  p_id_usuario INT, IN p_id_actor INT,
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1452 BEGIN ROLLBACK; SET p_error_num = 1452; SET p_error_text = 'Referencia inválida: verifique los IDs enviados.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error inesperado en la base de datos.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Usuario desactivado correctamente.';

    SELECT COUNT(*) INTO v_existe FROM usuarios WHERE id_usuario = p_id_usuario;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El usuario no existe.'; LEAVE proc;
    END IF;
    IF fn_es_ultimo_admin(p_id_usuario) = 1 THEN
        SET p_error_num = 409; SET p_error_text = 'No se puede desactivar al único Administrador activo.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    UPDATE usuarios SET estado = 'Inactivo', presencia = 'Desconectado' WHERE id_usuario = p_id_usuario;
    UPDATE conversaciones SET id_agente = NULL
     WHERE id_agente = p_id_usuario AND estado <> 'Resuelto';
    CALL sp_registrar_auditoria(p_id_actor, 'DESACTIVAR', 'usuario', p_id_usuario, NULL, NULL);
    COMMIT;
END//

-- ---------------------------------------------------------------------
-- MI PERFIL · el propio usuario edita nombre, teléfono y zona horaria
-- (no puede tocar correo, rol ni estado)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_actualizar_perfil//
CREATE PROCEDURE sp_actualizar_perfil(
    IN  p_id_usuario INT, IN p_nombre VARCHAR(100), IN p_telefono VARCHAR(20), IN p_zona_horaria VARCHAR(50),
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al actualizar el perfil.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Perfil actualizado correctamente.';
    SET p_nombre = TRIM(p_nombre);
    SET p_zona_horaria = COALESCE(NULLIF(TRIM(p_zona_horaria), ''), 'UTC-3');
    IF p_nombre IS NULL OR p_nombre = '' THEN
        SET p_error_num = 422; SET p_error_text = 'El nombre es obligatorio.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_existe FROM usuarios WHERE id_usuario = p_id_usuario AND estado = 'Activo';
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El usuario no existe o está inactivo.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    UPDATE usuarios
       SET nombre_completo = p_nombre, telefono = NULLIF(TRIM(p_telefono), ''), zona_horaria = p_zona_horaria
     WHERE id_usuario = p_id_usuario;
    COMMIT;
END//

-- ---------------------------------------------------------------------
-- CONTRASEÑA · el backend envía el hash (bcrypt/argon2), nunca texto plano
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_actualizar_password//
CREATE PROCEDURE sp_actualizar_password(
    IN  p_id_usuario INT, IN p_password_hash VARCHAR(255),
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al actualizar la contraseña.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Contraseña actualizada correctamente.';
    IF p_password_hash IS NULL OR p_password_hash = '' THEN
        SET p_error_num = 422; SET p_error_text = 'La contraseña (hash) es obligatoria.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_existe FROM usuarios WHERE id_usuario = p_id_usuario;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El usuario no existe.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    UPDATE usuarios SET password_hash = p_password_hash, intentos_fallidos = 0, bloqueado_hasta = NULL
     WHERE id_usuario = p_id_usuario;
    CALL sp_registrar_auditoria(p_id_usuario, 'CAMBIAR_PASSWORD', 'usuario', p_id_usuario, NULL, NULL);
    COMMIT;
END//

-- ---------------------------------------------------------------------
-- PRESENCIA (Disponible / Ausente / Desconectado)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_actualizar_presencia//
CREATE PROCEDURE sp_actualizar_presencia(
    IN  p_id_usuario INT, IN p_presencia VARCHAR(15),
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al actualizar la presencia.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Presencia actualizada.';
    IF p_presencia IS NULL OR p_presencia NOT IN ('Disponible', 'Ausente', 'Desconectado') THEN
        SET p_error_num = 422; SET p_error_text = 'Presencia inválida.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_existe FROM usuarios WHERE id_usuario = p_id_usuario;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El usuario no existe.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    UPDATE usuarios SET presencia = p_presencia WHERE id_usuario = p_id_usuario;
    COMMIT;
END//

-- ---------------------------------------------------------------------
-- LOGIN · datos para validar credenciales (el backend compara el hash)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_leer_usuario_login//
CREATE PROCEDURE sp_leer_usuario_login(
    IN p_correo VARCHAR(100), OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al consultar el usuario.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';
    SET p_correo = LOWER(TRIM(p_correo));

    SELECT COUNT(*) INTO v_existe FROM usuarios WHERE correo = p_correo;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'Usuario no encontrado.'; LEAVE proc;
    END IF;

    SELECT u.id_usuario, u.nombre_completo, u.correo, u.password_hash, u.estado,
           u.id_rol, r.nombre AS rol, r.estado AS rol_estado,
           u.intentos_fallidos, u.bloqueado_hasta,
           (u.bloqueado_hasta IS NOT NULL AND u.bloqueado_hasta > NOW()) AS bloqueado
    FROM usuarios u JOIN roles r ON r.id_rol = u.id_rol
    WHERE u.correo = p_correo;
END//

-- ---------------------------------------------------------------------
-- LOGIN · registrar resultado del intento (bloqueo temporal tras N fallos)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_login//
CREATE PROCEDURE sp_registrar_login(
    IN  p_id_usuario INT, IN p_exito TINYINT, IN p_max_intentos INT, IN p_minutos_bloqueo INT,
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al registrar el intento de acceso.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Intento registrado.';
    SET p_max_intentos = COALESCE(p_max_intentos, 5);
    SET p_minutos_bloqueo = COALESCE(p_minutos_bloqueo, 15);

    SELECT COUNT(*) INTO v_existe FROM usuarios WHERE id_usuario = p_id_usuario;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El usuario no existe.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    IF p_exito = 1 THEN
        UPDATE usuarios
           SET intentos_fallidos = 0, bloqueado_hasta = NULL, ultimo_acceso = NOW()
         WHERE id_usuario = p_id_usuario;
    ELSE
        -- Orden importante: bloqueado_hasta se evalúa ANTES de incrementar el contador
        UPDATE usuarios
           SET bloqueado_hasta = IF(intentos_fallidos + 1 >= p_max_intentos,
                                    DATE_ADD(NOW(), INTERVAL p_minutos_bloqueo MINUTE), bloqueado_hasta),
               intentos_fallidos = LEAST(intentos_fallidos + 1, 60000)
         WHERE id_usuario = p_id_usuario;
    END IF;
    COMMIT;
END//

-- ---------------------------------------------------------------------
-- PERMISOS EFECTIVOS de un usuario (para incluir en el JWT / middleware)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_leer_permisos_usuario//
CREATE PROCEDURE sp_leer_permisos_usuario(
    IN p_id_usuario INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al consultar permisos del usuario.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';

    SELECT COUNT(*) INTO v_existe FROM usuarios WHERE id_usuario = p_id_usuario;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El usuario no existe.'; LEAVE proc;
    END IF;

    -- Usuario o rol inactivos => lista vacía (sin permisos)
    SELECT p.codigo
    FROM usuarios u
    JOIN roles r         ON r.id_rol = u.id_rol AND r.estado = 'Activo'
    JOIN rol_permisos rp ON rp.id_rol = r.id_rol
    JOIN permisos p      ON p.id_permiso = rp.id_permiso
    WHERE u.id_usuario = p_id_usuario AND u.estado = 'Activo'
    ORDER BY p.codigo;
END//

DELIMITER ;
-- =====================================================================
-- OmniDesk · Base de datos v2 · 05 · SP de CLIENTES y CANALES
-- =====================================================================
SET NAMES utf8mb4;
USE omnidesk_db;
DELIMITER //

-- =====================================================================
-- CLIENTES
-- =====================================================================

-- CREATE
DROP PROCEDURE IF EXISTS sp_insertar_cliente//
CREATE PROCEDURE sp_insertar_cliente(
    IN  p_nombre VARCHAR(100), IN p_correo VARCHAR(100), IN p_telefono VARCHAR(20),
    IN  p_nivel_lealtad VARCHAR(10),
    OUT p_id_cliente INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1048 BEGIN ROLLBACK; SET p_id_cliente = NULL; SET p_error_num = 1048; SET p_error_text = 'Hay un campo obligatorio sin valor.'; END;
    DECLARE EXIT HANDLER FOR 1062 BEGIN ROLLBACK; SET p_id_cliente = NULL; SET p_error_num = 1062; SET p_error_text = 'El correo del cliente ya existe.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_id_cliente = NULL; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al insertar cliente.';
    END;

    SET p_id_cliente = NULL; SET p_error_num = 0; SET p_error_text = 'Cliente creado correctamente.';
    SET p_nombre = TRIM(p_nombre);
    SET p_correo = NULLIF(LOWER(TRIM(p_correo)), '');
    SET p_nivel_lealtad = COALESCE(NULLIF(TRIM(p_nivel_lealtad), ''), 'Bronze');

    IF p_nombre IS NULL OR p_nombre = '' THEN
        SET p_error_num = 422; SET p_error_text = 'El nombre del cliente es obligatorio.'; LEAVE proc;
    END IF;
    IF p_correo IS NOT NULL AND p_correo NOT REGEXP '^[^@ ]+@[^@ ]+\\.[^@ ]+$' THEN
        SET p_error_num = 422; SET p_error_text = 'El correo electrónico no es válido.'; LEAVE proc;
    END IF;
    IF p_nivel_lealtad NOT IN ('Bronze', 'Silver', 'Gold', 'Platinum') THEN
        SET p_error_num = 422; SET p_error_text = 'Nivel de lealtad inválido.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    INSERT INTO clientes (nombre, correo, telefono, nivel_lealtad)
    VALUES (p_nombre, p_correo, NULLIF(TRIM(p_telefono), ''), p_nivel_lealtad);
    SET p_id_cliente = LAST_INSERT_ID();
    COMMIT;
END//

-- READ (filtros opcionales; busca por nombre, correo o teléfono)
DROP PROCEDURE IF EXISTS sp_leer_clientes//
CREATE PROCEDURE sp_leer_clientes(
    IN  p_id_cliente INT, IN p_busqueda VARCHAR(100), IN p_estado VARCHAR(10),
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al leer clientes.';
    END;
    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';
    SET p_busqueda = NULLIF(TRIM(p_busqueda), '');

    IF p_id_cliente IS NOT NULL THEN
        SELECT COUNT(*) INTO v_existe FROM clientes WHERE id_cliente = p_id_cliente;
        IF v_existe = 0 THEN
            SET p_error_num = 404; SET p_error_text = 'El cliente no existe.'; LEAVE proc;
        END IF;
    END IF;

    SELECT v.*
    FROM v_clientes_resumen v
    WHERE (p_id_cliente IS NULL OR v.id_cliente = p_id_cliente)
      AND (p_estado     IS NULL OR v.estado     = p_estado)
      AND (p_busqueda   IS NULL
           OR v.nombre   LIKE CONCAT('%', p_busqueda, '%')
           OR v.correo   LIKE CONCAT('%', p_busqueda, '%')
           OR v.telefono LIKE CONCAT('%', p_busqueda, '%'))
    ORDER BY v.nombre;
END//

-- UPDATE (p_estado y p_nivel_lealtad NULL = no cambiar; permite reactivar)
DROP PROCEDURE IF EXISTS sp_actualizar_cliente//
CREATE PROCEDURE sp_actualizar_cliente(
    IN  p_id_cliente INT, IN p_nombre VARCHAR(100), IN p_correo VARCHAR(100), IN p_telefono VARCHAR(20),
    IN  p_nivel_lealtad VARCHAR(10), IN p_estado VARCHAR(10),
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_abiertas INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1048 BEGIN ROLLBACK; SET p_error_num = 1048; SET p_error_text = 'Hay un campo obligatorio sin valor.'; END;
    DECLARE EXIT HANDLER FOR 1062 BEGIN ROLLBACK; SET p_error_num = 1062; SET p_error_text = 'El correo ya pertenece a otro cliente.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al actualizar cliente.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Cliente actualizado correctamente.';
    SET p_nombre = TRIM(p_nombre);
    SET p_correo = NULLIF(LOWER(TRIM(p_correo)), '');

    IF p_nombre IS NULL OR p_nombre = '' THEN
        SET p_error_num = 422; SET p_error_text = 'El nombre del cliente es obligatorio.'; LEAVE proc;
    END IF;
    IF p_correo IS NOT NULL AND p_correo NOT REGEXP '^[^@ ]+@[^@ ]+\\.[^@ ]+$' THEN
        SET p_error_num = 422; SET p_error_text = 'El correo electrónico no es válido.'; LEAVE proc;
    END IF;
    IF p_nivel_lealtad IS NOT NULL AND p_nivel_lealtad NOT IN ('Bronze', 'Silver', 'Gold', 'Platinum') THEN
        SET p_error_num = 422; SET p_error_text = 'Nivel de lealtad inválido.'; LEAVE proc;
    END IF;
    IF p_estado IS NOT NULL AND p_estado NOT IN ('Activo', 'Inactivo') THEN
        SET p_error_num = 422; SET p_error_text = 'Estado inválido (use Activo o Inactivo).'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_existe FROM clientes WHERE id_cliente = p_id_cliente;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El cliente no existe.'; LEAVE proc;
    END IF;

    IF p_estado = 'Inactivo' THEN
        SELECT COUNT(*) INTO v_abiertas FROM conversaciones
         WHERE id_cliente = p_id_cliente AND estado <> 'Resuelto';
        IF v_abiertas > 0 THEN
            SET p_error_num = 409;
            SET p_error_text = CONCAT('No se puede desactivar: tiene ', v_abiertas, ' conversación(es) sin resolver.');
            LEAVE proc;
        END IF;
    END IF;

    START TRANSACTION;
    UPDATE clientes
       SET nombre = p_nombre, correo = p_correo, telefono = NULLIF(TRIM(p_telefono), ''),
           nivel_lealtad = COALESCE(p_nivel_lealtad, nivel_lealtad),
           estado        = COALESCE(p_estado, estado)
     WHERE id_cliente = p_id_cliente;
    COMMIT;
END//

-- DELETE lógico (se conserva el historial de conversaciones)
DROP PROCEDURE IF EXISTS sp_eliminar_cliente//
CREATE PROCEDURE sp_eliminar_cliente(
    IN p_id_cliente INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_abiertas INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al eliminar cliente.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Cliente dado de baja correctamente.';

    SELECT COUNT(*) INTO v_existe FROM clientes WHERE id_cliente = p_id_cliente;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El cliente no existe.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_abiertas FROM conversaciones
     WHERE id_cliente = p_id_cliente AND estado <> 'Resuelto';
    IF v_abiertas > 0 THEN
        SET p_error_num = 409;
        SET p_error_text = CONCAT('No se puede dar de baja: tiene ', v_abiertas, ' conversación(es) sin resolver.');
        LEAVE proc;
    END IF;

    START TRANSACTION;
    UPDATE clientes SET estado = 'Inactivo' WHERE id_cliente = p_id_cliente;
    COMMIT;
END//

-- =====================================================================
-- CANALES
-- =====================================================================

-- CREATE
DROP PROCEDURE IF EXISTS sp_insertar_canal//
CREATE PROCEDURE sp_insertar_canal(
    IN  p_nombre VARCHAR(50), IN p_descripcion VARCHAR(150), IN p_icono VARCHAR(40),
    IN  p_color_hex CHAR(7), IN p_estado VARCHAR(10),
    OUT p_id_canal INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1048 BEGIN ROLLBACK; SET p_id_canal = NULL; SET p_error_num = 1048; SET p_error_text = 'Hay un campo obligatorio sin valor.'; END;
    DECLARE EXIT HANDLER FOR 1062 BEGIN ROLLBACK; SET p_id_canal = NULL; SET p_error_num = 1062; SET p_error_text = 'El canal ya está registrado.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_id_canal = NULL; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al insertar canal.';
    END;

    SET p_id_canal = NULL; SET p_error_num = 0; SET p_error_text = 'Canal creado correctamente.';
    SET p_nombre = TRIM(p_nombre);
    SET p_color_hex = NULLIF(TRIM(p_color_hex), '');
    SET p_estado = COALESCE(NULLIF(TRIM(p_estado), ''), 'Inactivo');

    IF p_nombre IS NULL OR p_nombre = '' THEN
        SET p_error_num = 422; SET p_error_text = 'El nombre del canal es obligatorio.'; LEAVE proc;
    END IF;
    IF p_color_hex IS NOT NULL AND p_color_hex NOT REGEXP '^#[0-9A-Fa-f]{6}$' THEN
        SET p_error_num = 422; SET p_error_text = 'El color debe tener formato #RRGGBB.'; LEAVE proc;
    END IF;
    IF p_estado NOT IN ('Activo', 'Inactivo') THEN
        SET p_error_num = 422; SET p_error_text = 'Estado inválido (use Activo o Inactivo).'; LEAVE proc;
    END IF;

    START TRANSACTION;
    INSERT INTO canales (nombre, descripcion, icono, color_hex, estado, fecha_conexion)
    VALUES (p_nombre, NULLIF(TRIM(p_descripcion), ''), NULLIF(TRIM(p_icono), ''), p_color_hex, p_estado,
            IF(p_estado = 'Activo', NOW(), NULL));
    SET p_id_canal = LAST_INSERT_ID();
    COMMIT;
END//

-- READ
DROP PROCEDURE IF EXISTS sp_leer_canales//
CREATE PROCEDURE sp_leer_canales(
    IN p_id_canal INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al consultar canales.';
    END;
    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';

    IF p_id_canal IS NOT NULL THEN
        SELECT COUNT(*) INTO v_existe FROM canales WHERE id_canal = p_id_canal;
        IF v_existe = 0 THEN
            SET p_error_num = 404; SET p_error_text = 'El canal no existe.'; LEAVE proc;
        END IF;
    END IF;

    SELECT cn.id_canal, cn.nombre, cn.descripcion, cn.icono, cn.color_hex, cn.estado, cn.fecha_conexion,
           (SELECT COUNT(*) FROM conversaciones c WHERE c.id_canal = cn.id_canal) AS total_conversaciones,
           (SELECT COUNT(*) FROM conversaciones c
             WHERE c.id_canal = cn.id_canal AND c.estado <> 'Resuelto')           AS conversaciones_abiertas
    FROM canales cn
    WHERE p_id_canal IS NULL OR cn.id_canal = p_id_canal
    ORDER BY cn.id_canal;
END//

-- UPDATE (fecha_conexion se renueva al pasar de Inactivo a Activo)
DROP PROCEDURE IF EXISTS sp_actualizar_canal//
CREATE PROCEDURE sp_actualizar_canal(
    IN  p_id_canal INT, IN p_nombre VARCHAR(50), IN p_descripcion VARCHAR(150), IN p_icono VARCHAR(40),
    IN  p_color_hex CHAR(7), IN p_estado VARCHAR(10),
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1048 BEGIN ROLLBACK; SET p_error_num = 1048; SET p_error_text = 'Hay un campo obligatorio sin valor.'; END;
    DECLARE EXIT HANDLER FOR 1062 BEGIN ROLLBACK; SET p_error_num = 1062; SET p_error_text = 'Ya existe otro canal con ese nombre.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al actualizar canal.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Canal actualizado correctamente.';
    SET p_nombre = TRIM(p_nombre);
    SET p_color_hex = NULLIF(TRIM(p_color_hex), '');

    IF p_nombre IS NULL OR p_nombre = '' THEN
        SET p_error_num = 422; SET p_error_text = 'El nombre del canal es obligatorio.'; LEAVE proc;
    END IF;
    IF p_color_hex IS NOT NULL AND p_color_hex NOT REGEXP '^#[0-9A-Fa-f]{6}$' THEN
        SET p_error_num = 422; SET p_error_text = 'El color debe tener formato #RRGGBB.'; LEAVE proc;
    END IF;
    IF p_estado IS NOT NULL AND p_estado NOT IN ('Activo', 'Inactivo') THEN
        SET p_error_num = 422; SET p_error_text = 'Estado inválido (use Activo o Inactivo).'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_existe FROM canales WHERE id_canal = p_id_canal;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El canal no existe.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    -- Orden importante: fecha_conexion se evalúa ANTES de modificar estado
    UPDATE canales
       SET nombre = p_nombre, descripcion = NULLIF(TRIM(p_descripcion), ''),
           icono = NULLIF(TRIM(p_icono), ''), color_hex = p_color_hex,
           fecha_conexion = IF(p_estado = 'Activo' AND estado <> 'Activo', NOW(), fecha_conexion),
           estado = COALESCE(p_estado, estado)
     WHERE id_canal = p_id_canal;
    COMMIT;
END//

-- DELETE físico (bloqueado si tiene conversaciones: desactívelo en su lugar)
DROP PROCEDURE IF EXISTS sp_eliminar_canal//
CREATE PROCEDURE sp_eliminar_canal(
    IN p_id_canal INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_convs INT DEFAULT 0;
    DECLARE v_filas INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1451 BEGIN ROLLBACK; SET p_error_num = 1451; SET p_error_text = 'No se puede eliminar: el canal tiene conversaciones. Desactívelo en su lugar.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al eliminar canal.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Canal eliminado correctamente.';

    SELECT COUNT(*) INTO v_existe FROM canales WHERE id_canal = p_id_canal;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El canal no existe.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_convs FROM conversaciones WHERE id_canal = p_id_canal;
    IF v_convs > 0 THEN
        SET p_error_num = 409;
        SET p_error_text = CONCAT('No se puede eliminar: el canal tiene ', v_convs, ' conversación(es). Desactívelo en su lugar.');
        LEAVE proc;
    END IF;

    START TRANSACTION;
    DELETE FROM canales WHERE id_canal = p_id_canal;
    SET v_filas = ROW_COUNT();
    IF v_filas = 0 THEN
        ROLLBACK;
        SET p_error_num = 404; SET p_error_text = 'El canal no existe.'; LEAVE proc;
    END IF;
    COMMIT;
END//

DELIMITER ;
-- =====================================================================
-- OmniDesk · Base de datos v2 · 06 · SP de CONVERSACIONES y MENSAJES
-- fecha_cierre, fecha_ultimo_mensaje, fecha_primera_respuesta y el
-- sentimiento derivado los mantienen los triggers del archivo 01.
-- =====================================================================
SET NAMES utf8mb4;
USE omnidesk_db;
DELIMITER //

-- =====================================================================
-- CONVERSACIONES
-- =====================================================================

-- CREATE (p_id_agente NULL = cola sin asignar; p_prioridad NULL = Normal)
DROP PROCEDURE IF EXISTS sp_insertar_conversacion//
CREATE PROCEDURE sp_insertar_conversacion(
    IN  p_id_cliente INT, IN p_id_canal INT, IN p_id_agente INT,
    IN  p_asunto VARCHAR(200), IN p_prioridad VARCHAR(10),
    OUT p_id_conversacion INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_ok INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1452 BEGIN ROLLBACK; SET p_id_conversacion = NULL; SET p_error_num = 1452; SET p_error_text = 'Referencia inválida: verifique los IDs enviados.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_id_conversacion = NULL; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al crear la conversación.';
    END;

    SET p_id_conversacion = NULL; SET p_error_num = 0; SET p_error_text = 'Conversación creada correctamente.';
    SET p_prioridad = COALESCE(NULLIF(TRIM(p_prioridad), ''), 'Normal');
    IF p_prioridad NOT IN ('Normal', 'Alta', 'Urgente') THEN
        SET p_error_num = 422; SET p_error_text = 'Prioridad inválida.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_ok FROM clientes WHERE id_cliente = p_id_cliente AND estado = 'Activo';
    IF v_ok = 0 THEN
        SET p_error_num = 422; SET p_error_text = 'El cliente no existe o está inactivo.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_ok FROM canales WHERE id_canal = p_id_canal AND estado = 'Activo';
    IF v_ok = 0 THEN
        SET p_error_num = 422; SET p_error_text = 'El canal no existe o está inactivo.'; LEAVE proc;
    END IF;

    IF p_id_agente IS NOT NULL THEN
        SELECT COUNT(*) INTO v_ok FROM usuarios WHERE id_usuario = p_id_agente AND estado = 'Activo';
        IF v_ok = 0 THEN
            SET p_error_num = 422; SET p_error_text = 'El agente no existe o está inactivo.'; LEAVE proc;
        END IF;
    END IF;

    START TRANSACTION;
    INSERT INTO conversaciones (id_cliente, id_canal, id_agente, asunto, prioridad, fecha_ultimo_mensaje)
    VALUES (p_id_cliente, p_id_canal, p_id_agente, NULLIF(TRIM(p_asunto), ''), p_prioridad, NOW());
    SET p_id_conversacion = LAST_INSERT_ID();
    COMMIT;
END//

-- READ · bandeja con filtros (todos opcionales, NULL = sin filtro)
--   p_solo_sin_asignar = 1 -> solo la cola sin agente
--   p_solo_no_leidas   = 1 -> solo con mensajes del cliente sin leer
--   p_busqueda         -> cliente, asunto o contenido de cualquier mensaje
--   p_limite (def. 50, máx. 200) y p_offset para paginar
DROP PROCEDURE IF EXISTS sp_leer_conversaciones//
CREATE PROCEDURE sp_leer_conversaciones(
    IN  p_id_conversacion INT, IN p_estado VARCHAR(10), IN p_id_agente INT, IN p_prioridad VARCHAR(10),
    IN  p_solo_sin_asignar TINYINT, IN p_solo_no_leidas TINYINT, IN p_busqueda VARCHAR(100),
    IN  p_limite INT, IN p_offset INT,
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_limite INT DEFAULT 50;
    DECLARE v_offset INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al leer conversaciones.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';
    SET p_busqueda = NULLIF(TRIM(p_busqueda), '');
    SET v_limite = LEAST(GREATEST(COALESCE(p_limite, 50), 1), 200);
    SET v_offset = GREATEST(COALESCE(p_offset, 0), 0);

    IF p_id_conversacion IS NOT NULL THEN
        SELECT COUNT(*) INTO v_existe FROM conversaciones WHERE id_conversacion = p_id_conversacion;
        IF v_existe = 0 THEN
            SET p_error_num = 404; SET p_error_text = 'La conversación no existe.'; LEAVE proc;
        END IF;
    END IF;

    SELECT v.*
    FROM v_bandeja_conversaciones v
    WHERE (p_id_conversacion IS NULL OR v.id_conversacion = p_id_conversacion)
      AND (p_estado    IS NULL OR v.estado    = p_estado)
      AND (p_id_agente IS NULL OR v.id_agente = p_id_agente)
      AND (p_prioridad IS NULL OR v.prioridad = p_prioridad)
      AND (COALESCE(p_solo_sin_asignar, 0) = 0 OR v.id_agente IS NULL)
      AND (COALESCE(p_solo_no_leidas, 0)   = 0 OR v.mensajes_no_leidos > 0)
      AND (p_busqueda IS NULL
           OR v.cliente LIKE CONCAT('%', p_busqueda, '%')
           OR v.asunto  LIKE CONCAT('%', p_busqueda, '%')
           OR EXISTS (SELECT 1 FROM mensajes m
                       WHERE m.id_conversacion = v.id_conversacion
                         AND m.contenido LIKE CONCAT('%', p_busqueda, '%')))
    ORDER BY v.fecha_ultimo_mensaje DESC, v.id_conversacion DESC
    LIMIT v_limite OFFSET v_offset;
END//

-- UPDATE (p_id_agente NULL = dejar sin asignar; p_estado/p_prioridad NULL = no cambiar)
DROP PROCEDURE IF EXISTS sp_actualizar_conversacion//
CREATE PROCEDURE sp_actualizar_conversacion(
    IN  p_id_conversacion INT, IN p_id_agente INT, IN p_estado VARCHAR(10),
    IN  p_prioridad VARCHAR(10), IN p_asunto VARCHAR(200),
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_ok INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1452 BEGIN ROLLBACK; SET p_error_num = 1452; SET p_error_text = 'Referencia inválida: verifique los IDs enviados.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al actualizar la conversación.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Conversación actualizada correctamente.';

    IF p_estado IS NOT NULL AND p_estado NOT IN ('Abierto', 'Pendiente', 'Resuelto') THEN
        SET p_error_num = 422; SET p_error_text = 'Estado inválido.'; LEAVE proc;
    END IF;
    IF p_prioridad IS NOT NULL AND p_prioridad NOT IN ('Normal', 'Alta', 'Urgente') THEN
        SET p_error_num = 422; SET p_error_text = 'Prioridad inválida.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_existe FROM conversaciones WHERE id_conversacion = p_id_conversacion;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'La conversación no existe.'; LEAVE proc;
    END IF;

    IF p_id_agente IS NOT NULL THEN
        SELECT COUNT(*) INTO v_ok FROM usuarios WHERE id_usuario = p_id_agente AND estado = 'Activo';
        IF v_ok = 0 THEN
            SET p_error_num = 422; SET p_error_text = 'El agente no existe o está inactivo.'; LEAVE proc;
        END IF;
    END IF;

    START TRANSACTION;
    UPDATE conversaciones
       SET id_agente = p_id_agente,
           estado    = COALESCE(p_estado, estado),
           prioridad = COALESCE(p_prioridad, prioridad),
           asunto    = COALESCE(NULLIF(TRIM(p_asunto), ''), asunto)
     WHERE id_conversacion = p_id_conversacion;
    COMMIT;
END//

-- Sentimiento calculado por la IA (0-100). El trigger deriva Molesto/Neutral/Satisfecho:
--   0-39 Molesto · 40-69 Neutral · 70-100 Satisfecho
DROP PROCEDURE IF EXISTS sp_actualizar_sentimiento//
CREATE PROCEDURE sp_actualizar_sentimiento(
    IN  p_id_conversacion INT, IN p_puntaje INT,
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al actualizar el sentimiento.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Sentimiento actualizado correctamente.';
    IF p_puntaje IS NULL OR p_puntaje < 0 OR p_puntaje > 100 THEN
        SET p_error_num = 422; SET p_error_text = 'El puntaje debe estar entre 0 y 100.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_existe FROM conversaciones WHERE id_conversacion = p_id_conversacion;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'La conversación no existe.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    UPDATE conversaciones SET puntaje_sentimiento = p_puntaje WHERE id_conversacion = p_id_conversacion;
    COMMIT;
END//

-- DELETE físico (borra también sus mensajes por ON DELETE CASCADE)
DROP PROCEDURE IF EXISTS sp_eliminar_conversacion//
CREATE PROCEDURE sp_eliminar_conversacion(
    IN p_id_conversacion INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_filas INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al eliminar la conversación.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Conversación eliminada correctamente.';

    START TRANSACTION;
    DELETE FROM conversaciones WHERE id_conversacion = p_id_conversacion;
    SET v_filas = ROW_COUNT();
    IF v_filas = 0 THEN
        ROLLBACK;
        SET p_error_num = 404; SET p_error_text = 'La conversación no existe.'; LEAVE proc;
    END IF;
    COMMIT;
END//

-- =====================================================================
-- MENSAJES
-- =====================================================================

-- CREATE
--   Cliente  -> leido = 0 (cuenta como no leído para el agente)
--   Agente   -> requiere p_id_usuario (autor activo), máx. 1000 caracteres (límite de la UI)
--   Sistema  -> mensajes automáticos / de IA
DROP PROCEDURE IF EXISTS sp_insertar_mensaje//
CREATE PROCEDURE sp_insertar_mensaje(
    IN  p_id_conversacion INT, IN p_remitente VARCHAR(10), IN p_contenido TEXT, IN p_id_usuario INT,
    OUT p_id_mensaje INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_ok INT DEFAULT 0;
    DECLARE v_leido TINYINT DEFAULT 1;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR 1452 BEGIN ROLLBACK; SET p_id_mensaje = NULL; SET p_error_num = 1452; SET p_error_text = 'Referencia inválida: verifique los IDs enviados.'; END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_id_mensaje = NULL; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al enviar el mensaje.';
    END;

    SET p_id_mensaje = NULL; SET p_error_num = 0; SET p_error_text = 'Mensaje enviado con éxito.';
    SET p_contenido = TRIM(p_contenido);

    IF p_remitente IS NULL OR p_remitente NOT IN ('Cliente', 'Agente', 'Sistema') THEN
        SET p_error_num = 422; SET p_error_text = 'Remitente inválido.'; LEAVE proc;
    END IF;
    IF p_contenido IS NULL OR p_contenido = '' THEN
        SET p_error_num = 422; SET p_error_text = 'El mensaje no puede estar vacío.'; LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_ok FROM conversaciones WHERE id_conversacion = p_id_conversacion;
    IF v_ok = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'La conversación no existe.'; LEAVE proc;
    END IF;

    IF p_remitente = 'Agente' THEN
        IF CHAR_LENGTH(p_contenido) > 1000 THEN
            SET p_error_num = 422; SET p_error_text = 'El mensaje supera los 1000 caracteres.'; LEAVE proc;
        END IF;
        SELECT COUNT(*) INTO v_ok FROM usuarios WHERE id_usuario = p_id_usuario AND estado = 'Activo';
        IF p_id_usuario IS NULL OR v_ok = 0 THEN
            SET p_error_num = 422; SET p_error_text = 'El agente autor no existe o está inactivo.'; LEAVE proc;
        END IF;
    ELSE
        SET p_id_usuario = NULL;
    END IF;

    SET v_leido = IF(p_remitente = 'Cliente', 0, 1);

    START TRANSACTION;
    INSERT INTO mensajes (id_conversacion, remitente, id_usuario, contenido, leido, fecha_lectura)
    VALUES (p_id_conversacion, p_remitente, p_id_usuario, p_contenido, v_leido,
            IF(v_leido = 1, NOW(), NULL));
    SET p_id_mensaje = LAST_INSERT_ID();
    COMMIT;
END//

-- READ · mensajes de una conversación en orden cronológico
--   p_despues_de_id (opcional): solo mensajes con id mayor (polling / carga incremental)
DROP PROCEDURE IF EXISTS sp_leer_mensajes//
CREATE PROCEDURE sp_leer_mensajes(
    IN  p_id_conversacion INT, IN p_despues_de_id INT,
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al consultar mensajes.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';

    SELECT COUNT(*) INTO v_existe FROM conversaciones WHERE id_conversacion = p_id_conversacion;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'La conversación no existe.'; LEAVE proc;
    END IF;

    SELECT m.id_mensaje, m.id_conversacion, m.remitente, m.id_usuario,
           u.nombre_completo AS autor, m.contenido, m.leido, m.fecha_envio, m.fecha_lectura
    FROM mensajes m
    LEFT JOIN usuarios u ON u.id_usuario = m.id_usuario
    WHERE m.id_conversacion = p_id_conversacion
      AND (p_despues_de_id IS NULL OR m.id_mensaje > p_despues_de_id)
    ORDER BY m.fecha_envio ASC, m.id_mensaje ASC;
END//

-- UPDATE · marcar UN mensaje como leído
DROP PROCEDURE IF EXISTS sp_actualizar_mensaje_leido//
CREATE PROCEDURE sp_actualizar_mensaje_leido(
    IN p_id_mensaje INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al actualizar el mensaje.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Mensaje marcado como leído.';

    SELECT COUNT(*) INTO v_existe FROM mensajes WHERE id_mensaje = p_id_mensaje;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'El mensaje no existe.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    UPDATE mensajes SET leido = 1, fecha_lectura = COALESCE(fecha_lectura, NOW())
     WHERE id_mensaje = p_id_mensaje;
    COMMIT;
END//

-- UPDATE · al abrir una conversación: marca como leídos todos los mensajes del cliente
DROP PROCEDURE IF EXISTS sp_marcar_conversacion_leida//
CREATE PROCEDURE sp_marcar_conversacion_leida(
    IN  p_id_conversacion INT,
    OUT p_marcados INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_marcados = 0; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al marcar la conversación como leída.';
    END;

    SET p_marcados = 0; SET p_error_num = 0; SET p_error_text = 'Conversación marcada como leída.';

    SELECT COUNT(*) INTO v_existe FROM conversaciones WHERE id_conversacion = p_id_conversacion;
    IF v_existe = 0 THEN
        SET p_error_num = 404; SET p_error_text = 'La conversación no existe.'; LEAVE proc;
    END IF;

    START TRANSACTION;
    UPDATE mensajes SET leido = 1, fecha_lectura = NOW()
     WHERE id_conversacion = p_id_conversacion AND remitente = 'Cliente' AND leido = 0;
    SET p_marcados = ROW_COUNT();   -- aquí sí es fiable: cada fila afectada cambia de 0 a 1
    COMMIT;
END//

-- DELETE
DROP PROCEDURE IF EXISTS sp_eliminar_mensaje//
CREATE PROCEDURE sp_eliminar_mensaje(
    IN p_id_mensaje INT, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_filas INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        ROLLBACK; SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al eliminar el mensaje.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Mensaje eliminado correctamente.';

    START TRANSACTION;
    DELETE FROM mensajes WHERE id_mensaje = p_id_mensaje;
    SET v_filas = ROW_COUNT();
    IF v_filas = 0 THEN
        ROLLBACK;
        SET p_error_num = 404; SET p_error_text = 'El mensaje no existe.'; LEAVE proc;
    END IF;
    COMMIT;
END//

DELIMITER ;
-- =====================================================================
-- OmniDesk · Base de datos v2 · 07 · SP de REPORTES y AUDITORÍA (lectura)
-- Rango de fechas: p_desde / p_hasta (inclusivos). NULL = últimos 30 días.
-- =====================================================================
SET NAMES utf8mb4;
USE omnidesk_db;
DELIMITER //

-- ---------------------------------------------------------------------
-- Resumen general (tarjetas superiores de Reportes)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_reporte_resumen//
CREATE PROCEDURE sp_reporte_resumen(
    IN p_desde DATE, IN p_hasta DATE, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_d DATETIME;
    DECLARE v_h DATETIME;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al generar el reporte.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';
    SET p_desde = COALESCE(p_desde, DATE_SUB(CURDATE(), INTERVAL 30 DAY));
    SET p_hasta = COALESCE(p_hasta, CURDATE());
    IF p_desde > p_hasta THEN
        SET p_error_num = 422; SET p_error_text = 'La fecha inicial no puede ser posterior a la final.'; LEAVE proc;
    END IF;
    SET v_d = CAST(p_desde AS DATETIME);
    SET v_h = DATE_ADD(CAST(p_hasta AS DATETIME), INTERVAL 1 DAY);

    SELECT COUNT(*)                                                    AS total_conversaciones,
           COALESCE(SUM(c.estado = 'Abierto'), 0)                      AS abiertas,
           COALESCE(SUM(c.estado = 'Pendiente'), 0)                    AS pendientes,
           COALESCE(SUM(c.estado = 'Resuelto'), 0)                     AS resueltas,
           ROUND(100 * COALESCE(SUM(c.estado = 'Resuelto'), 0) / NULLIF(COUNT(*), 0), 1) AS tasa_resolucion_pct,
           ROUND(AVG(TIMESTAMPDIFF(SECOND, c.fecha_creacion, c.fecha_primera_respuesta)) / 60, 1)
                                                                        AS minutos_primera_respuesta,
           ROUND(100 * COALESCE(SUM(c.sentimiento_general = 'Satisfecho'), 0) / NULLIF(COUNT(*), 0), 1)
                                                                        AS satisfaccion_pct,
           (SELECT COUNT(*) FROM mensajes m
             WHERE m.fecha_envio >= v_d AND m.fecha_envio < v_h)        AS total_mensajes
    FROM conversaciones c
    WHERE c.fecha_creacion >= v_d AND c.fecha_creacion < v_h;
END//

-- ---------------------------------------------------------------------
-- Mensajes por canal (incluye canales con 0 mensajes)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_reporte_mensajes_por_canal//
CREATE PROCEDURE sp_reporte_mensajes_por_canal(
    IN p_desde DATE, IN p_hasta DATE, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_d DATETIME;
    DECLARE v_h DATETIME;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al generar el reporte.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';
    SET p_desde = COALESCE(p_desde, DATE_SUB(CURDATE(), INTERVAL 30 DAY));
    SET p_hasta = COALESCE(p_hasta, CURDATE());
    IF p_desde > p_hasta THEN
        SET p_error_num = 422; SET p_error_text = 'La fecha inicial no puede ser posterior a la final.'; LEAVE proc;
    END IF;
    SET v_d = CAST(p_desde AS DATETIME);
    SET v_h = DATE_ADD(CAST(p_hasta AS DATETIME), INTERVAL 1 DAY);

    SELECT cn.id_canal, cn.nombre AS canal, cn.color_hex, cn.estado,
           COUNT(m.id_mensaje)               AS total_mensajes,
           COUNT(DISTINCT m.id_conversacion) AS conversaciones_con_actividad
    FROM canales cn
    LEFT JOIN conversaciones c ON c.id_canal = cn.id_canal
    LEFT JOIN mensajes m       ON m.id_conversacion = c.id_conversacion
                              AND m.fecha_envio >= v_d AND m.fecha_envio < v_h
    GROUP BY cn.id_canal, cn.nombre, cn.color_hex, cn.estado
    ORDER BY total_mensajes DESC, cn.nombre;
END//

-- ---------------------------------------------------------------------
-- Sentimiento general (siempre devuelve las 3 categorías)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_reporte_sentimiento//
CREATE PROCEDURE sp_reporte_sentimiento(
    IN p_desde DATE, IN p_hasta DATE, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_d DATETIME;
    DECLARE v_h DATETIME;
    DECLARE v_total INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al generar el reporte.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';
    SET p_desde = COALESCE(p_desde, DATE_SUB(CURDATE(), INTERVAL 30 DAY));
    SET p_hasta = COALESCE(p_hasta, CURDATE());
    IF p_desde > p_hasta THEN
        SET p_error_num = 422; SET p_error_text = 'La fecha inicial no puede ser posterior a la final.'; LEAVE proc;
    END IF;
    SET v_d = CAST(p_desde AS DATETIME);
    SET v_h = DATE_ADD(CAST(p_hasta AS DATETIME), INTERVAL 1 DAY);

    SELECT COUNT(*) INTO v_total FROM conversaciones
     WHERE fecha_creacion >= v_d AND fecha_creacion < v_h;

    SELECT s.sentimiento,
           COUNT(c.id_conversacion) AS total,
           ROUND(100 * COUNT(c.id_conversacion) / NULLIF(v_total, 0), 1) AS porcentaje
    FROM (SELECT 'Satisfecho' AS sentimiento, 1 AS orden
          UNION ALL SELECT 'Neutral', 2
          UNION ALL SELECT 'Molesto', 3) s
    LEFT JOIN conversaciones c ON c.sentimiento_general = s.sentimiento
                              AND c.fecha_creacion >= v_d AND c.fecha_creacion < v_h
    GROUP BY s.sentimiento, s.orden
    ORDER BY s.orden;
END//

-- ---------------------------------------------------------------------
-- Rendimiento por agente (usuarios activos, aunque no tengan casos)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_reporte_rendimiento_agentes//
CREATE PROCEDURE sp_reporte_rendimiento_agentes(
    IN p_desde DATE, IN p_hasta DATE, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_d DATETIME;
    DECLARE v_h DATETIME;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al generar el reporte.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';
    SET p_desde = COALESCE(p_desde, DATE_SUB(CURDATE(), INTERVAL 30 DAY));
    SET p_hasta = COALESCE(p_hasta, CURDATE());
    IF p_desde > p_hasta THEN
        SET p_error_num = 422; SET p_error_text = 'La fecha inicial no puede ser posterior a la final.'; LEAVE proc;
    END IF;
    SET v_d = CAST(p_desde AS DATETIME);
    SET v_h = DATE_ADD(CAST(p_hasta AS DATETIME), INTERVAL 1 DAY);

    SELECT u.id_usuario, u.nombre_completo AS agente, r.nombre AS rol,
           COUNT(c.id_conversacion)                                   AS asignadas,
           COALESCE(SUM(c.estado = 'Resuelto'), 0)                    AS resueltas,
           ROUND(100 * COALESCE(SUM(c.estado = 'Resuelto'), 0) / NULLIF(COUNT(c.id_conversacion), 0), 1)
                                                                       AS tasa_resolucion_pct,
           ROUND(AVG(TIMESTAMPDIFF(SECOND, c.fecha_creacion, c.fecha_primera_respuesta)) / 60, 1)
                                                                       AS minutos_primera_respuesta,
           ROUND(AVG(TIMESTAMPDIFF(SECOND, c.fecha_creacion, c.fecha_cierre)) / 60, 1)
                                                                       AS minutos_resolucion,
           ROUND(100 * COALESCE(SUM(c.sentimiento_general = 'Satisfecho'), 0) / NULLIF(COUNT(c.id_conversacion), 0), 1)
                                                                       AS satisfaccion_pct
    FROM usuarios u
    JOIN roles r ON r.id_rol = u.id_rol
    LEFT JOIN conversaciones c ON c.id_agente = u.id_usuario
                              AND c.fecha_creacion >= v_d AND c.fecha_creacion < v_h
    WHERE u.estado = 'Activo'
    GROUP BY u.id_usuario, u.nombre_completo, r.nombre
    ORDER BY resueltas DESC, u.nombre_completo;
END//

-- ---------------------------------------------------------------------
-- Volumen diario de conversaciones nuevas (para gráficos de línea/barras)
-- Solo devuelve días con actividad; rellena los vacíos en el backend.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_reporte_volumen_diario//
CREATE PROCEDURE sp_reporte_volumen_diario(
    IN p_desde DATE, IN p_hasta DATE, OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
proc: BEGIN
    DECLARE v_d DATETIME;
    DECLARE v_h DATETIME;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al generar el reporte.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';
    SET p_desde = COALESCE(p_desde, DATE_SUB(CURDATE(), INTERVAL 30 DAY));
    SET p_hasta = COALESCE(p_hasta, CURDATE());
    IF p_desde > p_hasta THEN
        SET p_error_num = 422; SET p_error_text = 'La fecha inicial no puede ser posterior a la final.'; LEAVE proc;
    END IF;
    SET v_d = CAST(p_desde AS DATETIME);
    SET v_h = DATE_ADD(CAST(p_hasta AS DATETIME), INTERVAL 1 DAY);

    SELECT DATE(c.fecha_creacion)       AS dia,
           COUNT(*)                      AS conversaciones,
           SUM(c.estado = 'Resuelto')    AS resueltas
    FROM conversaciones c
    WHERE c.fecha_creacion >= v_d AND c.fecha_creacion < v_h
    GROUP BY DATE(c.fecha_creacion)
    ORDER BY dia;
END//

-- ---------------------------------------------------------------------
-- AUDITORÍA · lectura (filtros opcionales, máx. 500 filas)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_leer_auditoria//
CREATE PROCEDURE sp_leer_auditoria(
    IN  p_entidad VARCHAR(50), IN p_id_entidad INT, IN p_id_usuario INT, IN p_limite INT,
    OUT p_error_num INT, OUT p_error_text VARCHAR(255)
)
BEGIN
    DECLARE v_limite INT DEFAULT 100;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;
        SET p_error_num = IFNULL(v_errno, 1); SET p_error_text = 'Error al consultar la auditoría.';
    END;

    SET p_error_num = 0; SET p_error_text = 'Consulta exitosa.';
    SET v_limite = LEAST(GREATEST(COALESCE(p_limite, 100), 1), 500);

    SELECT a.id_auditoria, a.fecha, a.accion, a.entidad, a.id_entidad, a.detalle, a.ip,
           a.id_usuario, u.nombre_completo AS actor
    FROM auditoria a
    LEFT JOIN usuarios u ON u.id_usuario = a.id_usuario
    WHERE (p_entidad    IS NULL OR a.entidad    = p_entidad)
      AND (p_id_entidad IS NULL OR a.id_entidad = p_id_entidad)
      AND (p_id_usuario IS NULL OR a.id_usuario = p_id_usuario)
    ORDER BY a.fecha DESC, a.id_auditoria DESC
    LIMIT v_limite;
END//

DELIMITER ;

--pruebas

-- =====================================================================
-- OmniDesk · Base de datos v2 · 08 · DATOS DEMO (OPCIONAL)
-- Replica lo que muestran las pantallas (María González, bandeja, etc.).
-- Requiere haber ejecutado 01 a 07. NO lo cargues en producción.
--
-- Contraseñas: los usuarios demo llevan un hash inválido a propósito
-- (nadie puede iniciar sesión con él). En el Paso C (backend) crearemos
-- un script que fije la contraseña con bcrypt.
-- =====================================================================
SET NAMES utf8mb4;
USE omnidesk_db;

-- ---------------------------------------------------------------------
-- Usuarios demo
-- ---------------------------------------------------------------------
INSERT INTO usuarios (id_usuario, id_rol, nombre_completo, correo, password_hash, telefono, zona_horaria, presencia) VALUES
(1, 1, 'Admin OmniDesk', 'admin@omnidesk.local',      '!PENDIENTE_ESTABLECER_PASSWORD!', '+5491100000001', 'UTC-3', 'Disponible'),
(2, 2, 'Laura Méndez',   'laura.mendez@omnidesk.local','!PENDIENTE_ESTABLECER_PASSWORD!', '+5491100000002', 'UTC-3', 'Disponible'),
(3, 3, 'Marcos Peña',    'marcos.pena@omnidesk.local', '!PENDIENTE_ESTABLECER_PASSWORD!', '+5491100000003', 'UTC-3', 'Disponible'),
(4, 3, 'Julia Rivas',    'julia.rivas@omnidesk.local', '!PENDIENTE_ESTABLECER_PASSWORD!', '+5491100000004', 'UTC-3', 'Ausente');

-- ---------------------------------------------------------------------
-- Clientes
-- ---------------------------------------------------------------------
INSERT INTO clientes (id_cliente, nombre, correo, telefono, nivel_lealtad, fecha_registro) VALUES
(1, 'María González',   'maria.g@email.com',       '+5491155558901', 'Gold',     '2021-03-15 10:00:00'),
(2, 'Carlos Ruiz',      'carlos.ruiz@email.com',   '+5491155550112', 'Silver',   '2022-06-02 09:30:00'),
(3, 'Lucía Fernández',  'lucia.f@email.com',       '+5491155550223', 'Bronze',   '2024-01-20 16:45:00'),
(4, 'Andrés Torres',    'andres.t@email.com',      '+5491155550334', 'Platinum', '2020-11-08 12:10:00'),
(5, 'Sofía Martínez',   'sofia.m@email.com',       '+5491155550445', 'Gold',     '2023-04-27 08:20:00'),
(6, 'Diego Herrera',    'diego.h@email.com',       '+5491155550556', 'Silver',   '2022-09-14 14:05:00'),
(7, 'Valentina López',  'valentina.l@email.com',   '+5491155550667', 'Bronze',   '2025-02-03 11:00:00');

-- ---------------------------------------------------------------------
-- Conversaciones (30-sep-2026)
-- ---------------------------------------------------------------------
INSERT INTO conversaciones (id_conversacion, id_cliente, id_canal, id_agente, asunto, estado, prioridad, puntaje_sentimiento, fecha_creacion) VALUES
(1, 1, 1, 3,    'Pedido #78412 no llega',          'Abierto',   'Urgente', 18,   '2026-09-30 10:30:00'),
(2, 2, 2, 4,    'Factura del mes de agosto',       'Abierto',   'Normal',  55,   '2026-09-30 10:15:00'),
(3, 3, 3, 3,    'Reembolso pendiente',             'Abierto',   'Normal',  48,   '2026-09-30 09:58:00'),
(4, 4, 4, NULL, 'Cancelación de suscripción',      'Abierto',   'Urgente', 30,   '2026-09-30 09:25:00'),
(5, 5, 1, 4,    'Seguimiento de entrega',          'Abierto',   'Normal',  92,   '2026-09-30 08:50:00'),
(6, 6, 2, NULL, 'Consulta sobre garantía',         'Pendiente', 'Normal',  60,   '2026-09-30 08:40:00'),
(7, 7, 3, 3,    'No puede iniciar sesión',         'Abierto',   'Urgente', 35,   '2026-09-30 08:20:00');

-- ---------------------------------------------------------------------
-- Mensajes (el trigger actualiza último mensaje y primera respuesta)
-- ---------------------------------------------------------------------
-- Conversación 1: María González (3 mensajes del cliente sin leer)
INSERT INTO mensajes (id_conversacion, remitente, id_usuario, contenido, leido, fecha_envio) VALUES
(1, 'Cliente', NULL, 'Hola, necesito ayuda con mi pedido #78412. Llevo 5 días esperando y no llega.', 1, '2026-09-30 10:30:00'),
(1, 'Agente',  3,    'Buenos días María. Entiendo tu preocupación. Déjame verificar el estado de tu pedido ahora mismo.', 1, '2026-09-30 10:32:00'),
(1, 'Cliente', NULL, 'Es que lo necesito con urgencia para este fin de semana. ¿Pueden agilizarlo?', 0, '2026-09-30 10:35:00'),
(1, 'Agente',  3,    'Veo que tu pedido está en tránsito. El transportista lo tiene desde ayer. Te comparto el enlace de seguimiento ahora.', 1, '2026-09-30 10:37:00'),
(1, 'Cliente', NULL, 'Llevo días mirando ese enlace y no actualiza. Esto es inaceptable, llevo semanas siendo cliente y nunca me había pasado esto.', 0, '2026-09-30 10:40:00'),
(1, 'Cliente', NULL, 'Necesito una respuesta concreta, no excusas. ¿Van a solucionar esto o no?', 0, '2026-09-30 10:42:00');

-- Resto de la bandeja
INSERT INTO mensajes (id_conversacion, remitente, id_usuario, contenido, leido, fecha_envio) VALUES
(2, 'Cliente', NULL, 'Re: Factura del mes de agosto. Creo que hay un cargo duplicado, ¿pueden revisarlo?', 0, '2026-09-30 10:15:00'),
(3, 'Cliente', NULL, '¿Cuándo llegará mi reembolso? Ya pasaron más de diez días hábiles.', 0, '2026-09-30 09:58:00'),
(4, 'Cliente', NULL, 'Quiero cancelar mi suscripción hoy mismo.', 0, '2026-09-30 09:25:00'),
(4, 'Cliente', NULL, 'Por favor confírmenme que no me van a cobrar el próximo mes.', 0, '2026-09-30 09:31:00'),
(5, 'Cliente', NULL, 'Hola, ya recibí mi pedido, quería avisarles.', 1, '2026-09-30 08:50:00'),
(5, 'Agente',  4,    '¡Genial, Sofía! ¿Todo llegó en buen estado?', 1, '2026-09-30 09:05:00'),
(5, 'Cliente', NULL, 'Gracias, ¡todo está perfecto!', 1, '2026-09-30 09:10:00'),
(6, 'Cliente', NULL, 'Consulta sobre garantía del producto que compré en julio.', 0, '2026-09-30 08:47:00'),
(7, 'Cliente', NULL, 'El sistema no me deja iniciar sesión, me dice que mi contraseña es incorrecta.', 0, '2026-09-30 08:22:00');

-- Sofía queda resuelta DESPUÉS de insertar sus mensajes
-- (un mensaje del cliente en una conversación resuelta la reabre automáticamente)
UPDATE conversaciones SET estado = 'Resuelto' WHERE id_conversacion = 5;
UPDATE conversaciones SET fecha_cierre = '2026-09-30 09:15:00' WHERE id_conversacion = 5;

-- Auditoría de ejemplo
INSERT INTO auditoria (id_usuario, accion, entidad, id_entidad, detalle)
VALUES (1, 'CREAR', 'usuario', 3, 'correo=marcos.pena@omnidesk.local; id_rol=3');

-- sp y triggers pruebas
-- =====================================================================
-- OmniDesk · Base de datos v2 · 99 · PRUEBAS DE HUMO
-- Ejecutar DESPUÉS de 01-07 y 08 (datos demo), preferiblemente bloque por bloque
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

