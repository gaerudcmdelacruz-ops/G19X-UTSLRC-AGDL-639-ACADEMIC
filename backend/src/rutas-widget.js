// Widget de chat web (público, sin login): un visitante deja su mensaje y se crea un ticket en el canal "Web Chat".
// Es la única ruta sin autenticación, por eso valida todo y limita los envíos por IP.
const crypto = require('crypto');
const express = require('express');
const { callSP, pool } = require('./db');
const { falloSP } = require('./http');
const { avisar } = require('./tiempo-real');

const router = express.Router();
const h = fn => (req, res, next) => fn(req, res).catch(next);
const err = (res, codigo, mensaje) => res.status(codigo).json({ error: { codigo, mensaje } });

const CANAL_WEB = 3;            // id_canal de "Web Chat" en db/base-de-datos.sql
const MAX_POR_MINUTO = 5;
const MAX_LECTURAS_POR_MINUTO = 30;

// Un limitador por tipo de petición: leer se hace cada pocos segundos, así que tiene un tope más alto que enviar.
function crearLimite(maximo) {
  const usos = new Map();       // ip -> [marcas de tiempo]
  return (req, res, next) => {
    const ahora = Date.now(), ip = req.ip;
    const recientes = (usos.get(ip) || []).filter(t => ahora - t < 60000);
    if (recientes.length >= maximo) { usos.set(ip, recientes); return err(res, 429, 'Demasiadas peticiones seguidas. Espera un minuto.'); }
    recientes.push(ahora); usos.set(ip, recientes);
    if (usos.size > 5000) usos.delete(usos.keys().next().value);
    next();
  };
}
const limitar = crearLimite(MAX_POR_MINUTO);
const limitarLectura = crearLimite(MAX_LECTURAS_POR_MINUTO);

router.post('/widget/mensajes', limitar, h(async (req, res) => {
  const b = req.body || {};
  const nombre = typeof b.nombre === 'string' ? b.nombre.trim() : '';
  const mensaje = typeof b.mensaje === 'string' ? b.mensaje.trim() : '';
  const correo = typeof b.correo === 'string' ? b.correo.trim() : '';
  if (!nombre || nombre.length > 100) return err(res, 422, 'Escribe tu nombre (hasta 100 caracteres).');
  if (!mensaje || mensaje.length > 1000) return err(res, 422, 'Escribe tu mensaje (hasta 1000 caracteres).');
  if (correo && (correo.length > 100 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo))) return err(res, 422, 'El correo no es válido.');

  // Si el correo ya existe como cliente (1062) se crea el cliente sin correo para no exponer datos de otro.
  let rc = await callSP('sp_insertar_cliente', [nombre, correo || null, null, 'Bronze'], ['p_id_cliente']);
  if (rc.err === 1062) rc = await callSP('sp_insertar_cliente', [nombre, null, null, 'Bronze'], ['p_id_cliente']);
  if (falloSP(res, rc)) return;

  const rv = await callSP('sp_insertar_conversacion', [rc.out.p_id_cliente, CANAL_WEB, null, mensaje.slice(0, 60), 'Normal'], ['p_id_conversacion']);
  if (falloSP(res, rv)) return;
  const id = rv.out.p_id_conversacion;
  const rm = await callSP('sp_insertar_mensaje', [id, 'Cliente', mensaje, null], ['p_id_mensaje']);
  if (falloSP(res, rm)) return;

  // Token secreto (48 caracteres al azar): es lo único que permite leer las respuestas de ESTA conversación.
  const token = crypto.randomBytes(24).toString('hex');
  await pool.query('UPDATE conversaciones SET token_publico = ? WHERE id_conversacion = ?', [token, id]);

  avisar('nueva', id);
  res.status(201).json({ mensaje: 'Recibimos tu mensaje. Un agente te responderá pronto.', token });
}));

// Lectura pública de UNA conversación: solo con su token. Devuelve únicamente remitente, contenido y fecha.
router.get('/widget/mensajes', limitarLectura, h(async (req, res) => {
  const token = typeof req.query.token === 'string' ? req.query.token : '';
  if (!/^[a-f0-9]{48}$/.test(token)) return err(res, 404, 'Conversación no encontrada.');
  const [filas] = await pool.query('SELECT id_conversacion FROM conversaciones WHERE token_publico = ?', [token]);
  if (!filas.length) return err(res, 404, 'Conversación no encontrada.');
  const r = await callSP('sp_leer_mensajes', [filas[0].id_conversacion, null]);
  if (falloSP(res, r)) return;
  res.json({ mensajes: r.rows
    .filter(m => m.remitente !== 'Sistema')
    .map(m => ({ remitente: m.remitente, contenido: m.contenido, fecha: m.fecha_envio })) });
}));

module.exports = router;
