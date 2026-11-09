# OmniDesk

Plataforma de atención al cliente con IA: bandeja de conversaciones en tiempo real, asignación a agentes, roles y permisos, reportes, auditoría y análisis de sentimiento con IA (Gemini o Claude).

Proyecto académico — TODO Academy.

## Tecnologías

- **Frontend:** HTML + JavaScript + Tailwind (CDN). Sin compilación.
- **Backend:** Node.js 18+ · Express 4 · mysql2 · JWT · bcryptjs · Socket.IO
- **Base de datos:** MySQL/MariaDB (XAMPP) con procedimientos almacenados
- **IA:** servicio en **Python + FastAPI** (`ia-python/`) que llama a Gemini o Claude. La clave vive solo en el servidor. Si no se enciende, el backend Node puede llamar a Gemini/Claude directamente.

## Estructura

```
omnidesk/
├── backend/    API (src/, scripts/, package.json, .env.example)
├── frontend/   Páginas HTML y assets/
├── ia-python/  Servicio de IA (Python + FastAPI)
├── db/         base-de-datos.sql (esquema + procedimientos), datos-demo.sql, pruebas-humo.sql, migracion-token-widget.sql, migracion-foto-perfil.sql
├── docs/       mvp, prd, decisiones-tecnicas, api, backlog y evidencias/
└── README.md
```

## Requisitos

- XAMPP con **Apache** y **MySQL** encendidos (usuario `root`, sin contraseña)
- Node.js 18 o superior (`node -v`)
- Python 3.10 o superior (`python --version`) — solo para el servicio de IA

## Instalación paso a paso

### 1. Base de datos

1. Abre `http://localhost/phpmyadmin`.
2. Pestaña **Importar** → elige `db/base-de-datos.sql` → **Importar**. Crea la base `omnidesk_db` con sus tablas, roles y permisos.
3. Importa ahora `db/datos-demo.sql` (una sola vez). Crea los usuarios, clientes y conversaciones de ejemplo.
4. Comprueba que exista la base `omnidesk_db` y que la tabla `usuarios` tenga 4 filas.

> ⚠ `base-de-datos.sql` **borra y recrea** las tablas de `omnidesk_db`. No lo uses sobre datos que quieras conservar.

### 2. Backend

En PowerShell, dentro de la carpeta `backend`:

```powershell
npm install
copy .env.example .env
```

Abre `.env` y cambia `JWT_SECRET` por una frase larga y propia. Para generarla:

```powershell
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

(Opcional) Para la IA, pon `GEMINI_API_KEY` **o** `ANTHROPIC_API_KEY` en el `.env`. Sin clave, todo funciona menos el panel de IA.

Arranca:

```powershell
npm start
```

Debe decir que escucha en `http://localhost:3000`.

### 3. Servicio de IA en Python (opcional pero recomendado)

En **otra** ventana de PowerShell, dentro de la carpeta `ia-python`:

```powershell
python -m pip install -r requirements.txt
python -m uvicorn main:app --port 8000
```

Comprueba en `http://localhost:8000/salud` que diga `"activa": true`. La página `http://localhost:8000/docs` permite probar el servicio.

Luego, en `backend/.env`, añade `IA_SERVICIO_URL=http://localhost:8000` y reinicia el backend (`npm start`). El servicio Python lee las claves de `backend/.env`; no hay que repetirlas.

Si no lo enciendes y no defines `IA_SERVICIO_URL`, el backend llama a Gemini/Claude directamente y todo sigue funcionando.

> Si agregas o cambias `GEMINI_API_KEY` en `backend/.env` con el servicio ya encendido, detenlo (Ctrl+C) y vuelve a correr `python -m uvicorn main:app --port 8000`: solo lee las claves al arrancar.

### 4. Usuario de prueba

Los usuarios de `db/datos-demo.sql` se crean **sin contraseña** (nadie puede entrar todavía). En PowerShell, dentro de la carpeta `backend`, fíjala con:

```powershell
npm run admin
```

Correo: `admin@omnidesk.local` (Enter) · escribe una contraseña de 8+ caracteres.

Otros usuarios demo: `laura.mendez@omnidesk.local` (Supervisor), `marcos.pena@omnidesk.local` y `julia.rivas@omnidesk.local` (Agentes). Repite `npm run admin` para ponerles contraseña.

### 5. Frontend

Copia la carpeta `frontend` dentro de `C:\xampp\htdocs\` (por ejemplo `C:\xampp\htdocs\omnidesk`) y abre:

`http://localhost/omnidesk/` (página de inicio)

La portada tiene dos accesos: **Soy agente o administrador** (lleva al login y, si ya hay sesión, directo al panel) y **Soy cliente** (abre el chat público `widget.html`). Abajo muestra si el servidor responde. También puedes ir directo a `login.html` o `widget.html`.

Inicia sesión con el usuario de prueba.

> ¿Abriste `login.html` o `widget.html` con doble clic (la barra dice `file:///…`)? Entonces agrega `null` a `CORS_ORIGIN` en `backend/.env`, por ejemplo `CORS_ORIGIN=http://localhost,null`, y reinicia el backend. Con Apache (`http://localhost/omnidesk/…`) no hace falta.

**Widget de chat web (público, sin login):** abre `http://localhost/omnidesk/widget.html`, escribe un nombre y un mensaje y envía. Aparece una conversación nueva en el canal Web Chat dentro del panel. El cliente ve las respuestas del agente: la página guarda un token secreto y consulta la conversación cada 10 segundos. Si el backend no está en `localhost:3000`, cambia `API_URL` dentro de `widget.html`.

> Si tu base de datos ya existía antes de este cambio, corre una sola vez `db/migracion-token-widget.sql` (agrega la columna `token_publico`). Una base nueva ya la trae.
>
> Lo mismo con la foto de perfil: si tu base ya existía, corre una sola vez `db/migracion-foto-perfil.sql` (agrega `usuarios.foto`). Las fotos se guardan en `backend/uploads/avatares/` (esa carpeta no se sube a GitHub).

## Prueba rápida (10 minutos)

Con MySQL y el backend encendidos (y, si quieres la IA, el servicio de Python), recorre esto en orden. Las páginas están en `http://localhost/omnidesk/`; la portada (`index.html`) enlaza al panel y al widget.

1. **`login.html`**, usuario `admin@omnidesk.local` (Administrador): entra al panel.
2. **Conversaciones**, usuario Administrador: abre la de **María González** y pulsa **Analizar con IA**. Aparecen puntaje, etiquetas, resumen y respuesta sugerida.
3. **`widget.html`**, sin usuario (es público): escribe un nombre y un mensaje y envía. Aparece "Recibimos tu mensaje".
4. **Conversaciones**, Administrador: aparece una conversación nueva del canal **Web Chat**, sin asignar. Ábrela y respóndele.
5. **`widget.html`**, la misma pestaña del paso 3: en menos de 10 segundos aparece **"Agente: …"** con tu respuesta.
6. **Mi perfil**, Administrador: sube una foto (se ve también en la cabecera), luego cambia tu nombre y guarda. La foto y el nombre nuevo se mantienen.
7. Cierra sesión y entra como `marcos.pena@omnidesk.local` (Agente; pon su contraseña antes con `npm run admin`): **no** ve Reportes, Agentes, Roles y permisos ni Auditoría. El Administrador sí.

## Uso de IA

- **En el producto:** el botón *Analizar con IA* envía los mensajes de una conversación a Gemini o Claude (por el servicio Python o directo desde Node) y devuelve puntaje de sentimiento, etiquetas, resumen y una respuesta sugerida. La IA nunca envía nada sola: el agente decide. No se entrenan modelos; solo se consulta uno externo.
- **En el desarrollo:** el código, la base de datos y la documentación se elaboraron con ayuda de Claude (asistente de IA). Lo revisé, ejecuté y probé yo; los resultados de la instalación desde cero están en `docs/evidencias/instalacion-limpia.md`.

## Variables de entorno (`backend/.env`)

| Variable | Para qué |
|---|---|
| `JWT_SECRET` | Firma de sesiones (obligatoria) |
| `DB_HOST` / `DB_PORT` | Servidor y puerto de MariaDB (por defecto `localhost` / `3306`) |
| `DB_USER` / `DB_PASSWORD` | Usuario y contraseña (por defecto `root` y vacía, como en XAMPP) |
| `DB_NAME` | Nombre de la base (por defecto `omnidesk_db`) |
| `PORT` | Puerto del backend (por defecto `3000`) |
| `CORS_ORIGIN` | Orígenes permitidos, separados por coma (por defecto `http://localhost`) |
| `GEMINI_API_KEY` / `ANTHROPIC_API_KEY` | IA (una de las dos) |
| `IA_PROVEEDOR` | `gemini` o `claude` si tienes ambas |
| `IA_SERVICIO_URL` | Dirección del servicio Python (ej. `http://localhost:8000`). Opcional |
| `IA_SERVICIO_CLAVE` | Clave compartida Node ↔ Python. Opcional |
| `MODO_DEMO` | `1` permite simular mensajes del cliente |

El archivo `.env` **no se sube** a GitHub (está en `.gitignore`).

## Documentación

- [Decisiones técnicas](docs/decisiones-tecnicas.md)
- [API](docs/api.md)
- [Backlog y plan](docs/backlog.md)
- [Evidencia de instalación limpia](docs/evidencias/instalacion-limpia.md)
- [MVP](docs/mvp.md)
- [PRD](docs/prd.md)
