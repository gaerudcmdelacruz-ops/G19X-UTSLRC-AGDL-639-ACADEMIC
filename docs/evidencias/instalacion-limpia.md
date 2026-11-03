# Evidencia de instalación limpia

Prueba de que el proyecto se levanta desde cero siguiendo solo el README.

- Fecha: 03-nov-2026 · commit 5abc673
- Carpeta usada: `C:\prueba-omnidesk` (clon nuevo del repositorio)
- Base de datos usada: MariaDB 10.4 de XAMPP

| # | Paso | Resultado esperado | ¿Salió? | Nota |
|---|---|---|---|---|
| 1 | `git clone` del repositorio | Carpeta con `backend`, `frontend`, `db`, `docs`, `ia-python` | Si | |
| 2 | Importar `db/base-de-datos.sql` y luego `db/datos-demo.sql` | Base creada con datos | Si | Se hizo un cambio en la base de datos|
| 3 | `cd backend`, copiar `.env.example` a `.env`, poner `JWT_SECRET` | Archivo `.env` creado | Si | |
| 4 | `npm install` | Sin errores | Si | |
| 5 | `npm run admin` | Contraseña asignada al usuario de prueba |Si | admin@omnidesk.local|
| 6 | `npm start` | "OmniDesk API lista en http://localhost:3000" |Si | |
| 7 | Abrir `http://localhost:3000/api/salud` | `base_de_datos: conectada` | Si | |
| 8 | Servicio Python: `pip install -r requirements.txt` y `python -m uvicorn main:app --port 8000` |  `http://localhost:8000/salud` responde | Si | |
| 9 | Iniciar sesión en el frontend | Entra al panel | Si | entro |
| 10 | Analizar con IA la conversación de María González | Aparece puntaje, resumen y respuesta sugerida | Si | |
| 11 | Abrir `frontend/widget.html`, enviar un mensaje | "Recibimos tu mensaje" y aparece una conversación nueva en el panel | Si | |

Capturas: (pega aquí las imágenes o enlaces)
