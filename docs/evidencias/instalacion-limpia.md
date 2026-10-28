# Evidencia de instalación limpia

Prueba de que el proyecto se levanta desde cero siguiendo solo el README.

- Fecha: __________
- Carpeta usada: `C:\prueba-omnidesk` (clon nuevo del repositorio)
- Base de datos usada: __________

| # | Paso | Resultado esperado | ¿Salió? | Nota |
|---|---|---|---|---|
| 1 | `git clone` del repositorio | Carpeta con `backend`, `frontend`, `db`, `docs`, `ia-python` | | |
| 2 | Importar `db/base-de-datos.sql` y luego `db/datos-demo.sql` | Base creada con datos | | |
| 3 | `cd backend`, copiar `.env.example` a `.env`, poner `JWT_SECRET` | Archivo `.env` creado | | |
| 4 | `npm install` | Sin errores | | |
| 5 | `npm run admin` | Contraseña asignada al usuario de prueba | | |
| 6 | `npm start` | "OmniDesk API lista en http://localhost:3000" | | |
| 7 | Abrir `http://localhost:3000/api/salud` | `base_de_datos: conectada` | | |
| 8 | Servicio Python: `pip install -r requirements.txt` y `python -m uvicorn main:app --port 8000` | `http://localhost:8000/salud` responde | | |
| 9 | Iniciar sesión en el frontend | Entra al panel | | |
| 10 | Analizar con IA la conversación de María González | Aparece puntaje, resumen y respuesta sugerida | | |
| 11 | Abrir `frontend/widget.html`, enviar un mensaje | "Recibimos tu mensaje" y aparece una conversación nueva en el panel | | |

Capturas: (pega aquí las imágenes o enlaces)
