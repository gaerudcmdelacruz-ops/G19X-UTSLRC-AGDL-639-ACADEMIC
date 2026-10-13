// Conversaciones y mensajes. Visibilidad: 'conversaciones.ver_todas' ve todo; con solo 'ver_propias' ve las asignadas a sí mismo.
const express = require('express');
const { callSP } = require('./db');
const { autenticar, requierePermiso } = require('./auth');
const { falloSP } = require('./http');

const router = express.Router();
const h = fn => (req, res, next) => fn(req, res).catch(next);
const tiene = (req, p) => req.user.permisos.includes(p);
const err = (res, codigo, mensaje) => res.status(codigo).json({ error: { codigo, mensaje } });
const algunPermiso = (...cs) => (req, res, next) => cs.some(c => tiene(req, c)) ? next() : err(res, 403, 'No tienes permiso para esta acción.');

// Carga la conversación y comprueba que este usuario pueda verla. Devuelve la fila, o null si ya respondió con error.
async function cargarConv(req, res) {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) { err(res, 422, 'El identificador no es válido.'); return null; }
  const r = await callSP('sp_leer_conversaciones', [id, null, null, null, 0, 0, null, 1, 0]);
  if (falloSP(res, r)) return null;
  const c = r.rows[0];
  if (!tiene(req, 'conversaciones.ver_todas') && c.id_agente !== req.user.sub) { err(res, 403, 'Esta conversación no está asignada a ti.'); return null; }
  return c;
}
const ver = [autenticar, algunPermiso('conversaciones.ver_propias', 'conversaciones.ver_todas')];

router.get('/conversaciones', ...ver, h(async (req, res) => {
  const q = req.query;
  const estado = ['Abierto', 'Pendiente', 'Resuelto'].includes(q.estado) ? q.estado : null;
  const prioridad = ['Normal', 'Alta', 'Urgente'].includes(q.prioridad) ? q.prioridad : null;
  const agente = tiene(req, 'conversaciones.ver_todas') ? null : req.user.sub;
  const r = await callSP('sp_leer_conversaciones', [null, estado, agente, prioridad,
    q.sin_asignar === '1' ? 1 : 0, q.sin_leer === '1' ? 1 : 0, String(q.q || '').slice(0, 100) || null,
    Number(q.limite) || 50, Number(q.offset) || 0]);
  if (!falloSP(res, r)) res.json({ conversaciones: r.rows });
}));

router.get('/conversaciones/:id', ...ver, h(async (req, res) => {
  const c = await cargarConv(req, res); if (c) res.json({ conversacion: c });
}));

router.get('/conversaciones/:id/mensajes', ...ver, h(async (req, res) => {
  const c = await cargarConv(req, res); if (!c) return;
  const r = await callSP('sp_leer_mensajes', [c.id_conversacion, Number(req.query.despues_de) || null]);
  if (!falloSP(res, r)) res.json({ mensajes: r.rows });
}));

router.post('/conversaciones/:id/mensajes', ...ver, requierePermiso('conversaciones.responder'), h(async (req, res) => {
  const c = await cargarConv(req, res); if (!c) return;
  const contenido = (req.body || {}).contenido;
  if (typeof contenido !== 'string') return err(res, 422, 'El mensaje no puede estar vacío.');
  const r = await callSP('sp_insertar_mensaje', [c.id_conversacion, 'Agente', contenido, req.user.sub], ['p_id_mensaje']);
  if (falloSP(res, r)) return;
  // Al responder una conversación sin asignar, queda asignada a quien responde
  if (c.id_agente === null) await callSP('sp_actualizar_conversacion', [c.id_conversacion, req.user.sub, null, null, null]);
  res.status(201).json({ id: r.out.p_id_mensaje, mensaje: r.text });
}));

router.post('/conversaciones/:id/leer', ...ver, h(async (req, res) => {
  const c = await cargarConv(req, res); if (!c) return;
  const r = await callSP('sp_marcar_conversacion_leida', [c.id_conversacion], ['p_marcados']);
  if (!falloSP(res, r)) res.json({ marcados: r.out.p_marcados });
}));

// Resolver / reabrir. OJO: el SP pone id_agente = lo que reciba, así que se envía el agente actual para no desasignar.
router.put('/conversaciones/:id/estado', ...ver, requierePermiso('conversaciones.resolver'), h(async (req, res) => {
  const c = await cargarConv(req, res); if (!c) return;
  const estado = (req.body || {}).estado;
  if (!['Abierto', 'Pendiente', 'Resuelto'].includes(estado)) return err(res, 422, 'Estado inválido.');
  const r = await callSP('sp_actualizar_conversacion', [c.id_conversacion, c.id_agente, estado, null, null]);
  if (!falloSP(res, r)) res.json({ mensaje: r.text });
}));

// Datos del cliente para el panel derecho (solo se accede a través de una conversación visible)
router.get('/conversaciones/:id/cliente', ...ver, requierePermiso('clientes.ver'), h(async (req, res) => {
  const c = await cargarConv(req, res); if (!c) return;
  const r = await callSP('sp_leer_clientes', [c.id_cliente, null, null]);
  if (falloSP(res, r)) return;
  const { nombre, correo, telefono_enmascarado, nivel_lealtad, total_tickets, miembro_desde } = r.rows[0];
  res.json({ cliente: { nombre, correo, telefono_enmascarado, nivel_lealtad, total_tickets, miembro_desde } });
}));

module.exports = router;
