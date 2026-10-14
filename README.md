# OmniDesk

Plataforma de atención al cliente con IA: bandeja de conversaciones en tiempo real, asignación a agentes, roles y permisos, reportes, auditoría y análisis de sentimiento con IA (Gemini o Claude).

Proyecto académico — TODO Academy.

## Tecnologías

- **Frontend:** HTML + JavaScript + Tailwind (CDN). Sin compilación.
- **Backend:** Node.js 18+ · Express 4 · mysql2 · JWT · bcryptjs · Socket.IO
- **Base de datos:** MySQL/MariaDB (XAMPP) con procedimientos almacenados
- **IA:** Gemini o Claude (por `fetch`, la clave vive solo en el servidor)

## Estructura

```
omnidesk/
├── backend/    API (src/, scripts/, package.json, .env.example)
├── frontend/   Páginas HTML y assets/
├── db/         base-de-datos.sql (esquema + procedimientos + datos demo)
├── docs/       mvp.md y prd.md
└── README.md
```

## Requisitos

- XAMPP con **Apache** y **MySQL** encendidos (usuario `root`, sin contraseña)
- Node.js 18 o superior (`node -v`)

## Instalación paso a paso

### 1. Base de datos

1. Abre `http://localhost/phpmyadmin`.
2. Pestaña **Importar** → elige `db/base-de-datos.sql` → **Importar**.
3. Debe aparecer la base `omnidesk_db`.

> ⚠ El script **borra y recrea** las tablas de `omnidesk_db`. No lo uses sobre datos que quieras conservar.

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

### 3. Usuario de prueba

Los usuarios demo se crean **sin contraseña**. Fíjala con:

```powershell
npm run admin
```

Correo: `admin@omnidesk.local` (Enter) · escribe una contraseña de 8+ caracteres.

Otros usuarios demo: `laura.mendez@omnidesk.local` (Supervisor), `marcos.pena@omnidesk.local` y `julia.rivas@omnidesk.local` (Agentes). Repite `npm run admin` para ponerles contraseña.

### 4. Frontend

Copia la carpeta `frontend` dentro de `C:\xampp\htdocs\` (por ejemplo `C:\xampp\htdocs\omnidesk`) y abre:

`http://localhost/omnidesk/login.html`

Inicia sesión con el usuario de prueba.

## Variables de entorno (`backend/.env`)

| Variable | Para qué |
|---|---|
| `JWT_SECRET` | Firma de sesiones (obligatoria) |
| `GEMINI_API_KEY` / `ANTHROPIC_API_KEY` | IA (una de las dos) |
| `IA_PROVEEDOR` | `gemini` o `claude` si tienes ambas |
| `MODO_DEMO` | `1` permite simular mensajes del cliente |

El archivo `.env` **no se sube** a GitHub (está en `.gitignore`).

## Documentación

- [MVP](docs/mvp.md)
- [PRD](docs/prd.md)
