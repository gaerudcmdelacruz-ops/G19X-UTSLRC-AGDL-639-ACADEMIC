# Decisiones técnicas

La propuesta del proyecto (PluriOne / Develop Talent & Technology) lista como tecnologías aplicables: Python, FastAPI, React.js, Azure OpenAI Service, Azure AI Search, Azure Machine Learning, PostgreSQL, Redis, Docker, GitHub Actions, Microsoft Entra ID, Power BI, APIs de WhatsApp Business y Scrum.

Este documento dice, sin adornos, qué se usó, qué no y por qué.

| Tecnología de la propuesta | Estado | Qué se usó / por qué |
|---|---|---|
| **Python + FastAPI** | ✅ Usado | Servicio de IA (`ia-python/`): análisis de sentimiento, etiquetas, resumen y respuesta sugerida |
| JavaScript | ✅ Usado | Backend principal (Node.js + Express) y frontend |
| React.js | ❌ No | Frontend en HTML + JavaScript + Tailwind, sin compilación; más simple de desplegar en XAMPP |
| Azure OpenAI Service | ❌ No | Gemini (capa gratuita) o Claude, intercambiables por configuración. Sin costo de nube |
| Azure AI Search / Azure ML | ❌ No | No se necesitó: la clasificación y el análisis se resuelven con el modelo de lenguaje |
| PostgreSQL | ❌ No | MySQL/MariaDB (XAMPP), con 44 procedimientos almacenados, triggers y vistas |
| Redis | ❌ No | Caché en memoria del proceso (análisis de IA por último mensaje) |
| Docker / GitHub Actions | ❌ No | Pendiente. Repositorio en GitHub; despliegue manual |
| Microsoft Entra ID | ❌ No | Login propio: JWT + bcrypt + roles y permisos (25 permisos) + bloqueo por intentos |
| Power BI | ⚠ Parcial | Pantalla de Reportes propia; sin tableros de Power BI |
| API de WhatsApp Business | ⚠ Pendiente | Planeada. Alternativas gratuitas: chat web propio, Telegram, correo |
| Scrum | ✅ Metodología | Backlog y plan en [`backlog.md`](backlog.md) |

## Por qué esta arquitectura

- **Costo cero para desarrollar y demostrar:** XAMPP, Node, Python/FastAPI y la capa gratuita de Gemini.
- **IA separada en su propio servicio:** el backend de Node no habla con el proveedor de IA; se lo pide al servicio Python por HTTP. Cambiar de Gemini a Claude o a Azure OpenAI se hace solo dentro de `ia-python/`.
- **Degradación segura:** si no se define `IA_SERVICIO_URL`, el backend Node llama directo a Gemini/Claude; si el servicio Python se apaga, solo falla el análisis de IA y el resto del sistema sigue.
- **La IA nunca actúa sola:** la respuesta sugerida solo se copia al cuadro de texto; el agente decide si la envía.

## Qué implementación de IA es la principal

El servicio **Python/FastAPI** (`ia-python/`) es la implementación principal cuando `IA_SERVICIO_URL` está definida. Si no lo está, el backend Node usa su propio módulo (`backend/src/ia.js`) como respaldo, con el mismo contrato de entrada y salida.

## Flujo del análisis de IA

1. El agente pulsa *Analizar con IA* en una conversación.
2. El navegador pide al backend Node `POST /api/conversaciones/:id/ia` (con su sesión JWT y permiso `conversaciones.responder`).
3. Node lee los mensajes, aplica caché y límite (12 por minuto por usuario) y envía la conversación al servicio Python `POST /analizar`.
4. El servicio Python llama a Gemini o Claude, valida la respuesta y la devuelve.
5. Node guarda el puntaje en la base de datos (el trigger deriva Molesto / Neutral / Satisfecho) y avisa en tiempo real.

## Diferencias que conviene acordar con el asesor

React, PostgreSQL, Azure y Docker no se usaron. Si son obligatorios, deben quedar como fase posterior; el diseño por capas (frontend, API, base de datos, servicio de IA) permite cambiarlos por separado.
