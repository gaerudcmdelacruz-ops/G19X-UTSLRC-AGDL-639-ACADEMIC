# API de OmniDesk

Base: `http://localhost:3000`. Todas las rutas van bajo `/api`. Salvo `/api/salud`, `/api/auth/login` y `/api/widget/mensajes`, requieren `Authorization: Bearer <token>` (JWT de 8 h obtenido en el login).
Errores: `{ "error": { "codigo": 422, "mensaje": "..." } }`. Un permiso faltante responde 403.

| Método | Ruta | Permiso | Qué hace |
|---|---|---|---|
| GET | `/api/salud` | público | Estado del servidor y de la base de datos |
| POST | `/api/auth/login` | público | Inicia sesión (bloqueo 5 intentos / 15 min) |
| GET | `/api/auth/yo` | sesión | Datos y permisos del usuario actual |
| POST | `/api/auth/logout` | sesión | Cierra sesión |
| POST | `/api/widget/mensajes` | público (5 por minuto por IP) | Widget web: crea cliente, conversación y primer mensaje en el canal Web Chat |
| GET | `/api/conversaciones` | `conversaciones.ver_propias` o `ver_todas` | Lista de conversaciones |
| POST | `/api/conversaciones` | `conversaciones.responder` | Crea una conversación nueva |
| GET | `/api/conversaciones/:id` | ver_propias / ver_todas | Detalle |
| GET | `/api/conversaciones/:id/mensajes` | ver_propias / ver_todas | Mensajes |
| POST | `/api/conversaciones/:id/mensajes` | `conversaciones.responder` | Envía un mensaje |
| POST | `/api/conversaciones/:id/leer` | ver_propias / ver_todas | Marca como leída |
| PUT | `/api/conversaciones/:id/estado` | `conversaciones.resolver` | Resolver / reabrir |
| GET | `/api/conversaciones/:id/cliente` | `clientes.ver` | Cliente de la conversación |
| PUT | `/api/conversaciones/:id/asignar` | `conversaciones.asignar` | Asigna a un agente |
| POST | `/api/conversaciones/:id/escalar` | `conversaciones.responder` | Escala a supervisión |
| POST | `/api/conversaciones/:id/ia` | `conversaciones.responder` | Análisis con IA (sentimiento, etiquetas, resumen, respuesta sugerida) |
| GET | `/api/ia/estado` | sesión | Proveedor de IA activo y si responde |
| GET | `/api/agentes-asignables` | `conversaciones.asignar` | Agentes a los que se puede asignar |
| GET | `/api/config` | sesión | Ajustes visibles (modo demo) |
| GET | `/api/clientes` | `clientes.ver` | Lista de clientes |
| GET | `/api/canales` | `canales.ver` | Lista de canales |
| POST | `/api/canales` | `canales.gestionar` | Crea canal |
| PUT | `/api/canales/:id` | `canales.gestionar` | Edita canal |
| DELETE | `/api/canales/:id` | `canales.gestionar` | Da de baja un canal |
| GET | `/api/usuarios` | `agentes.ver` | Lista de agentes |
| GET | `/api/usuarios/:id` | `agentes.ver` | Detalle de un agente |
| GET | `/api/roles-asignables` | `agentes.ver` | Roles disponibles al crear agentes |
| POST | `/api/usuarios` | `agentes.crear` | Crea agente |
| PUT | `/api/usuarios/:id` | `agentes.editar` | Edita agente |
| PUT | `/api/usuarios/:id/rol` | `agentes.editar` | Cambia el rol |
| DELETE | `/api/usuarios/:id` | `agentes.desactivar` | Desactiva agente |
| GET | `/api/perfil` | sesión | Perfil propio |
| PUT | `/api/perfil` | `perfil.editar_propio` | Edita perfil propio |
| POST | `/api/perfil/password` | `perfil.editar_propio` | Cambia la contraseña propia |
| GET | `/api/permisos` | `roles.ver` | Catálogo de permisos |
| GET | `/api/roles` | `roles.ver` | Lista de roles |
| GET | `/api/roles/:id` | `roles.ver` | Detalle de rol |
| POST | `/api/roles` | `roles.crear` | Crea rol |
| PUT | `/api/roles/:id` | `roles.editar` | Edita rol |
| DELETE | `/api/roles/:id` | `roles.eliminar` | Elimina rol |
| GET | `/api/roles/:id/permisos` | `roles.ver` | Permisos de un rol |
| PUT | `/api/roles/:id/permisos` | `roles.asignar_permisos` | Reemplaza los permisos de un rol |
| GET | `/api/reportes` | `reportes.ver` | Métricas |
| GET | `/api/auditoria` | `auditoria.ver` | Registro de acciones |

## Servicio de IA (Python, puerto 8000)

| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/salud` | Estado y proveedor |
| POST | `/analizar` | Recibe la conversación y devuelve `{puntaje, etiquetas, resumen, respuesta_sugerida}`. Cabecera opcional `x-servicio-clave` |
