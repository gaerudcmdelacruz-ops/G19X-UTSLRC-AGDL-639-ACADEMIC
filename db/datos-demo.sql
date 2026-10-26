-- =====================================================================
-- OmniDesk · DATOS DE DEMOSTRACIÓN (opcional)
-- Crea 4 usuarios, 7 clientes y 7 conversaciones con mensajes de ejemplo
-- (María González, bandeja, etc.).
--
-- Cárgalo UNA SOLA VEZ, justo DESPUÉS de db/base-de-datos.sql.
-- (Si lo importas dos veces, MySQL avisará de claves duplicadas: es inofensivo.)
-- NO lo cargues en producción.
--
-- Usuarios demo (los 4 con contraseña pendiente a propósito, ver abajo):
--   admin@omnidesk.local         Administrador
--   laura.mendez@omnidesk.local  Supervisor
--   marcos.pena@omnidesk.local   Agente
--   julia.rivas@omnidesk.local   Agente
--
-- Contraseñas: llevan un hash inválido a propósito, así que nadie puede entrar
-- con ellos hasta que tú elijas una. Desde la carpeta backend ejecuta:
--     npm run admin
-- y escribe el correo y la nueva contraseña (mínimo 8 caracteres).
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
