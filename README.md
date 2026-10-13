```markdown

\\# Omnidesk - Plataforma de Gestión (Proyecto Integrador)



Plataforma web integral \\\*\\\*Omnidesk\\\*\\\*, desarrollada como proyecto integrador. El sistema incluye un \\\*\\\*Frontend\\\*\\\* dinámico estructurado con un diseño unificado y un \\\*\\\*Backend\\\*\\\* en Node.js/Express con conexión a base de datos MySQL.



\\---



\\## 🛠️ Tecnologías Utilizadas



\\\* \\\*\\\*Frontend:\\\*\\\* HTML5, CSS3, JavaScript (ES6+), Tokens de diseño (`omnidesk-tokens.js`), Layout dinámico (`omnidesk-layout.js`).

\\\* \\\*\\\*Backend:\\\*\\\* Node.js, Express.js.

\\\* \\\*\\\*Base de Datos:\\\*\\\* MySQL / MariaDB (vía XAMPP).

\\\* \\\*\\\*Seguridad \\\& Autenticación:\\\*\\\* JWT (JSON Web Tokens), Bcryptjs.



\\---



\\## 📂 Estructura General del Proyecto



```text

.

├── omnidesk\\\_frontend/                  # Módulo de Frontend / Interfaz de Usuario

│   ├── assets/

│   │   ├── omnidesk-layout.js          # Componente y maquetación general

│   │   └── omnidesk-tokens.js          # Tokens de diseño y estilos

│   ├── agentes.html                    # Vista de gestión de agentes

│   ├── canales.html                    # Vista de administración de canales

│   ├── conversaciones.html             # Vista de chats y conversaciones

│   ├── index.html                      # Panel principal / Dashboard

│   ├── login.html                      # Pantilla de inicio de sesión

│   ├── mi-perfil.html                  # Vista de edición de perfil

│   ├── reportes.html                   # Vista de reportes y métricas

│   ├── roles.html                      # Vista de gestión de roles y permisos

│   └── DESIGN.md                       # Especificaciones de diseño

│

└── omnidesk\\\_backend/                   # Módulo de Backend / API REST

\&#x20;   ├── scripts/

\&#x20;   │   └── set-password.js             # Script de utilidad para contraseñas

\&#x20;   ├── src/

\&#x20;   │   ├── auth.js                     # Middleware y lógica de autenticación

\&#x20;   │   ├── db.js                       # Conexión a la base de datos MySQL

\&#x20;   │   ├── http.js                     # Configuración y utilidades HTTP

\&#x20;   │   ├── server.js                   # Punto de entrada principal de la API

\&#x20;   │   ├── rutas-auth.js               # Endpoints de login y sesión

\&#x20;   │   ├── rutas-canales.js            # Endpoints de canales

\&#x20;   │   ├── rutas-conversaciones.js     # Endpoints de mensajes y chats

\&#x20;   │   ├── rutas-perfil.js             # Endpoints de perfil de usuario

\&#x20;   │   ├── rutas-roles.js              # Endpoints de roles y permisos

\&#x20;   │   └── rutas-usuarios.js           # Endpoints de administración de usuarios

\&#x20;   └── package.json                    # Dependencias y scripts de Node.js



```



\---



\## 📋 Requisitos Previos



\* \*\*Node.js\*\* (Versión 16.x o superior)

\* \*\*XAMPP Control Panel\*\* (Con servicio \*\*Apache\*\* y \*\*MySQL\*\* activos)



\---



\## 🚀 Instalación y Ejecución



\### 1. Clonar el repositorio



```bash

git clone \\\[https://github.com/gaerudcmdelacruz-ops/G19X-UTSLRC-AGDL-639-ACADEMIC.git](https://github.com/gaerudcmdelacruz-ops/G19X-UTSLRC-AGDL-639-ACADEMIC.git)



```



\### 2. Configurar y Ejecutar el Backend



```bash

cd omnidesk\\\_backend

npm install



```



Crea un archivo `.env` dentro de `omnidesk\\\_backend/` con las siguientes variables:



```env

PORT=3000

DB\\\_HOST=localhost

DB\\\_USER=root

DB\\\_PASS=

DB\\\_NAME=omnidesk\\\_db

JWT\\\_SECRET=tu\\\_clave\\\_secreta\\\_jwt



```



Iniciar el servidor:



```bash

npm start



```



\*El servidor estará ejecutándose en `http://localhost:3000`.\*



\### 3. Ejecutar el Frontend



\* Si utilizas \*\*XAMPP\*\*, coloca la carpeta `omnidesk\\\_frontend` dentro del directorio `htdocs` y accede vía navegador en: `http://localhost/omnidesk\\\_frontend/login.html`

\* O puedes abrir los archivos `.html` directamente desde un servidor local (como \*Live Server\* en VS Code).



\---



\## 📡 Endpoints Principales de la API



| Módulo | Ruta | Descripción |

| --- | --- | --- |

| \*\*Autenticación\*\* | `/auth` | Inicio de sesión y verificación |

| \*\*Usuarios\*\* | `/usuarios` | CRUD de usuarios del sistema |

| \*\*Roles\*\* | `/roles` | Administración de roles y permisos |

| \*\*Perfil\*\* | `/perfil` | Consulta y actualización de datos personales |

| \*\*Canales\*\* | `/canales` | Gestión de canales de comunicación |

| \*\*Conversaciones\*\* | `/conversaciones` | Envío, recepción y gestión de chats |



\---



\## 👨‍💻 Autor



\* \*\*Gael de la Cruz\*\* - \*\[@gaerudcmdelacruz-ops](https://www.google.com/search?q=https://github.com/gaerudcmdelacruz-ops)\*



```



```

