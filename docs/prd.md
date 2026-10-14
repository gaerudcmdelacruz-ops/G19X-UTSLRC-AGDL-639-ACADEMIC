# OmniDesk — PRD

## Problema
Los equipos de soporte pierden tiempo saltando entre canales y no saben qué clientes están molestos.

## Usuarios
- **Administrador:** configura roles, usuarios y canales.
- **Supervisor:** ve todo, asigna, revisa reportes y auditoría.
- **Agente:** atiende sus conversaciones asignadas.

## Requisitos funcionales
| ID | Requisito |
|---|---|
| RF-01 | Autenticación con JWT y bloqueo por intentos fallidos |
| RF-02 | RBAC: el servidor valida el permiso en cada ruta; el frontend oculta lo no permitido |
| RF-03 | CRUD de roles y asignación de permisos; roles del sistema protegidos |
| RF-04 | CRUD de agentes y edición de perfil |
| RF-05 | CRUD de canales |
| RF-06 | Bandeja de conversaciones filtrada por permiso (todas / asignadas) |
| RF-07 | Responder, resolver, reabrir, asignar y escalar conversaciones |
| RF-08 | Crear conversación nueva con cliente existente o nuevo |
| RF-09 | Actualizaciones en tiempo real |
| RF-10 | Análisis con IA (puntaje, etiquetas, resumen, respuesta sugerida), con límite de 12/min por usuario |
| RF-11 | Reportes |
| RF-12 | Auditoría de acciones y pantalla de consulta |

## Requisitos no funcionales
- Claves de IA solo en el servidor (`.env`)
- Contraseñas con bcrypt
- Toda la lógica de datos en procedimientos almacenados con códigos de error uniformes
- Con datos reales de clientes, usar un plan de IA de pago (el nivel gratuito de Gemini puede usar el contenido para mejorar productos de Google)

## Métricas de éxito
- Tiempo de primera respuesta
- % de conversaciones resueltas
- Satisfacción del cliente (puntaje de sentimiento)

## Riesgos
- Costos de APIs de mensajería (WhatsApp/Instagram)
- Permisos en el token: los cambios aplican al volver a iniciar sesión
