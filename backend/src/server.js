require('dotenv').config();
const http = require('http');
const express = require('express');
const cors = require('cors');
const { pool } = require('./db');

const app = express();
// El frontend corre en Apache (http://localhost). Puedes añadir más orígenes en CORS_ORIGIN, separados por coma.
const ORIGENES = (process.env.CORS_ORIGIN || 'http://localhost').split(',').map(s => s.trim());
app.use(cors({ origin: ORIGENES }));
app.use(express.json({ limit: '1mb' }));

app.get('/api/salud', async (req, res) => {
  try { await pool.query('SELECT 1'); res.json({ ok: true, base_de_datos: 'conectada' }); }
  catch (e) { res.status(503).json({ ok: false, base_de_datos: 'sin conexión', detalle: e.code || e.message }); }
});

app.use('/api/auth', require('./rutas-auth'));
app.use('/api', require('./rutas-roles'));
app.use('/api', require('./rutas-usuarios'));
app.use('/api', require('./rutas-perfil'));
app.use('/api', require('./rutas-canales'));
app.use('/api', require('./rutas-conversaciones'));
app.use('/api', require('./rutas-reportes'));
app.use('/api', require('./rutas-ia'));
app.use('/api', require('./rutas-clientes'));
app.use('/api', require('./rutas-auditoria'));
app.use('/api', require('./rutas-widget'));   // público (sin login), con límite por IP

app.use('/api', (req, res) => res.status(404).json({ error: { codigo: 404, mensaje: 'Ruta no encontrada.' } }));
app.use((err, req, res, next) => {          // errores inesperados: se registran en consola, no se exponen al cliente
  console.error(err);
  res.status(500).json({ error: { codigo: 500, mensaje: 'Error interno del servidor.' } });
});

const PUERTO = Number(process.env.PORT || 3000);
const servidor = http.createServer(app);
require('./tiempo-real').iniciar(servidor, ORIGENES);   // WebSocket en el mismo puerto
servidor.listen(PUERTO, () => console.log(`OmniDesk API lista en http://localhost:${PUERTO}  (prueba: /api/salud)`));
