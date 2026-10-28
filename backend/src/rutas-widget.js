// Widget de chat web (público, sin login): un visitante deja su mensaje y se crea un ticket en el canal "Web Chat".
// Es la única ruta sin autenticación, por eso valida todo y limita los envíos por IP.
const express = require('express');
const { callSP } = require('./db');
const { falloSP } = require('./http');
const { avisar } = require('./tiempo-real');

const router = express.Router();
const h = fn => (req, res, next) => fn(req, res).catch(next);
const err = (res, codigo, mensaje) => res.status(codigo).json({ error: { codigo, mensaje } });

const CANAL_WEB = 3;            // id_canal de "Web Chat" en db/base-de-datos.sql
const MAX_POR_MINUTO = 5;
const USOS = new Map();         // ip -> [marcas de tiempo]

function limitar(req, res, next) {
  const ahora = Date.now(), ip = req.ip;
  const recientes = (USOS.get(ip) || []).filter(t => ahora - t < 60000);
  if (recientes.length >= MAX_POR_MINUTO) { USOS.set(ip, recientes); return err(res, 429, 'Enviaste muchos mensajes seguidos. Espera un minuto.'); }
  recientes.push(ahora); USOS.set(ip, recientes);
  if (USOS.size > 5000) USOS.delete(USOS.keys().next().value);
  next();
}

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

  avisar('nueva', id);
  res.status(201).json({ mensaje: 'Recibimos tu mensaje. Un agente te responderá pronto.' });
}));

module.exports = router;
