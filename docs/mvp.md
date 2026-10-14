# OmniDesk — MVP

**Objetivo:** que un equipo pequeño atienda, asigne y analice conversaciones de clientes desde un solo lugar, sin pagar APIs de mensajería.

## Incluido en el MVP

- Inicio de sesión con JWT y bloqueo tras 5 intentos fallidos (15 min)
- Roles y permisos (Administrador, Supervisor, Agente) con 25 permisos; creación de roles propios
- Gestión de agentes y perfil propio
- Canales (alta, edición, baja)
- Conversaciones: lista, detalle, responder, resolver/reabrir, asignar, nueva conversación, escalar
- Tiempo real con Socket.IO (con *polling* de respaldo)
- Análisis con IA: puntaje de sentimiento, etiquetas, resumen y respuesta sugerida (nunca se envía sola)
- Reportes y pantalla de Auditoría
- Modo demo para simular mensajes del cliente

## Fuera del MVP

- Adjuntos de archivos
- Pantalla de Clientes
- Integración real con WhatsApp, Instagram o correo
- Recuperación de contraseña y renovación de token

## Siguiente

1. Widget de chat web propio (costo 0)
2. Telegram Bot API (gratis)
3. Correo IMAP/SMTP
4. Canales de Meta (WhatsApp/Instagram), con costos y verificación
