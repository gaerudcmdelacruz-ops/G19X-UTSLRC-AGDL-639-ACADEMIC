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
├── db/         base-de-datos.sql (esquema + procedimientos), datos-demo.sql, pruebas-humo.sql
├── docs/       mvp.md y prd.md
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

### 4. Usuario de prueba

Los usuarios de `db/datos-demo.sql` se crean **sin contraseña** (nadie puede entrar todavía). En PowerShell, dentro de la carpeta `backend`, fíjala con:

```powershell
npm run admin
```

Correo: `admin@omnidesk.local` (Enter) · escribe una contraseña de 8+ caracteres.

Otros usuarios demo: `laura.mendez@omnidesk.local` (Supervisor), `marcos.pena@omnidesk.local` y `julia.rivas@omnidesk.local` (Agentes). Repite `npm run admin` para ponerles contraseña.

### 5. Frontend

Copia la carpeta `frontend` dentro de `C:\xampp\htdocs\` (por ejemplo `C:\xampp\htdocs\omnidesk`) y abre:

`http://localhost/omnidesk/login.html`

Inicia sesión con el usuario de prueba.

## Variables de entorno (`backend/.env`)

| Variable | Para qué |
|---|---|
| `JWT_SECRET` | Firma de sesiones (obligatoria) |
| `GEMINI_API_KEY` / `ANTHROPIC_API_KEY` | IA (una de las dos) |
| `IA_PROVEEDOR` | `gemini` o `claude` si tienes ambas |
| `IA_SERVICIO_URL` | Dirección del servicio Python (ej. `http://localhost:8000`). Opcional |
| `IA_SERVICIO_CLAVE` | Clave compartida Node ↔ Python. Opcional |
| `MODO_DEMO` | `1` permite simular mensajes del cliente |

El archivo `.env` **no se sube** a GitHub (está en `.gitignore`).

## Documentación

- [Decisiones técnicas](docs/decisiones-tecnicas.md)
- [MVP](docs/mvp.md)
- [PRD](docs/prd.md)
