// Conversaciones y mensajes. Visibilidad: 'conversaciones.ver_todas' ve todo; con solo 'ver_propias' ve las asignadas a sí mismo.
const express = require('express');
const { callSP, auditar } = require('./db');
const { autenticar, requierePermiso } = require('./auth');
const { falloSP } = require('./http');
const { avisar } = require('./tiempo-real');

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
  // Modo demo (MODO_DEMO=1 en .env): quien ve todas las conversaciones puede registrar un mensaje COMO el cliente, para probar sin canales reales
  const comoCliente = process.env.MODO_DEMO === '1' && tiene(req, 'conversaciones.ver_todas') && (req.body || {}).como_cliente === true;
  const r = await callSP('sp_insertar_mensaje', [c.id_conversacion, comoCliente ? 'Cliente' : 'Agente', contenido, comoCliente ? null : req.user.sub], ['p_id_mensaje']);
  if (falloSP(res, r)) return;
  // Al responder una conversación sin asignar, queda asignada a quien responde
  if (!comoCliente && c.id_agente === null) await callSP('sp_actualizar_conversacion', [c.id_conversacion, req.user.sub, null, null, null]);
  avisar('mensaje', c.id_conversacion, c.id_agente || req.user.sub);
  res.status(201).json({ id: r.out.p_id_mensaje, mensaje: r.text });
}));

router.post('/conversaciones/:id/leer', ...ver, h(async (req, res) => {
  const c = await cargarConv(req, res); if (!c) return;
  const r = await callSP('sp_marcar_conversacion_leida', [c.id_conversacion], ['p_marcados']);
  if (falloSP(res, r)) return;
  avisar('leida', c.id_conversacion, c.id_agente);
  res.json({ marcados: r.out.p_marcados });
}));

// Resolver / reabrir. OJO: el SP pone id_agente = lo que reciba, así que se envía el agente actual para no desasignar.
router.put('/conversaciones/:id/estado', ...ver, requierePermiso('conversaciones.resolver'), h(async (req, res) => {
  const c = await cargarConv(req, res); if (!c) return;
  const estado = (req.body || {}).estado;
  if (!['Abierto', 'Pendiente', 'Resuelto'].includes(estado)) return err(res, 422, 'Estado inválido.');
  const r = await callSP('sp_actualizar_conversacion', [c.id_conversacion, c.id_agente, estado, null, null]);
  if (falloSP(res, r)) return;
  await auditar(req, estado === 'Resuelto' ? 'RESOLVER' : estado === 'Abierto' ? 'REABRIR' : 'CAMBIAR_ESTADO', 'conversacion', c.id_conversacion, `${c.numero_ticket}: ${c.estado} -> ${estado}`);
  avisar('estado', c.id_conversacion, c.id_agente);
  res.json({ mensaje: r.text });
}));

// Datos del cliente para el panel derecho (solo se accede a través de una conversación visible)
router.get('/conversaciones/:id/cliente', ...ver, requierePermiso('clientes.ver'), h(async (req, res) => {
  const c = await cargarConv(req, res); if (!c) return;
  const r = await callSP('sp_leer_clientes', [c.id_cliente, null, null]);
  if (falloSP(res, r)) return;
  const { nombre, correo, telefono_enmascarado, nivel_lealtad, total_tickets, miembro_desde } = r.rows[0];
  res.json({ cliente: { nombre, correo, telefono_enmascarado, nivel_lealtad, total_tickets, miembro_desde } });
}));

// Usuarios activos a los que se puede asignar una conversación (con su carga actual)
router.get('/agentes-asignables', autenticar, requierePermiso('conversaciones.asignar'), h(async (req, res) => {
  const r = await callSP('sp_leer_usuarios', [null, null, 'Activo']);
  if (falloSP(res, r)) return;
  res.json({ agentes: r.rows.map(u => ({ id_usuario: u.id_usuario, nombre: u.nombre_completo, rol: u.rol, activas: Number(u.conversaciones_activas) || 0 })) });
}));

// Asignar o reasignar. body { id_agente: 3 } · { id_agente: null } deja la conversación sin asignar.
// El SP valida que el agente exista y esté activo. Conserva estado, prioridad y asunto (se envían como NULL).
router.put('/conversaciones/:id/asignar', ...ver, requierePermiso('conversaciones.asignar'), h(async (req, res) => {
  const c = await cargarConv(req, res); if (!c) return;
  const v = (req.body || {}).id_agente;
  const agente = (v === null || v === undefined || v === '') ? null : Number(v);
  if (agente !== null && (!Number.isInteger(agente) || agente < 1)) return err(res, 422, 'El agente no es válido.');
  const r = await callSP('sp_actualizar_conversacion', [c.id_conversacion, agente, null, null, null]);
  if (falloSP(res, r)) return;
  let nombreNuevo = 'sin asignar';
  if (agente !== null) { const u = await callSP('sp_leer_usuarios', [agente, null, null]); if (u.err === 0 && u.rows[0]) nombreNuevo = u.rows[0].nombre_completo; }
  await auditar(req, 'ASIGNAR', 'conversacion', c.id_conversacion, `${c.numero_ticket}: ${c.agente || 'sin asignar'} -> ${nombreNuevo}`);
  avisar('asignada', c.id_conversacion, c.id_agente, agente);   // avisa al agente anterior (la pierde) y al nuevo (la gana)
  res.json({ mensaje: r.text });
}));


// ---------------------------------------------------------------------------------------------
// Nueva conversación: con un cliente existente (id_cliente) o uno nuevo (cliente:{nombre,correo,telefono}).
// El primer mensaje se registra como mensaje del cliente y la conversación queda asignada a quien la crea.
router.post('/conversaciones', ...ver, requierePermiso('conversaciones.responder'), h(async (req, res) => {
  const b = req.body || {};
  const mensaje = typeof b.mensaje === 'string' ? b.mensaje.trim() : '';
  if (!mensaje || mensaje.length > 1000) return err(res, 422, 'El primer mensaje es obligatorio y admite hasta 1000 caracteres.');
  const idCanal = Number(b.id_canal);
  if (!Number.isInteger(idCanal) || idCanal < 1) return err(res, 422, 'Elige un canal.');
  const prioridad = ['Normal', 'Alta', 'Urgente'].includes(b.prioridad) ? b.prioridad : 'Normal';
  const asunto = String(b.asunto || '').trim().slice(0, 200) || mensaje.slice(0, 60);

  let idCliente = Number(b.id_cliente) || null;
  if (idCliente) {
    if (!tiene(req, 'clientes.ver')) return err(res, 403, 'No tienes permiso para consultar clientes.');
  } else {
    const c = b.cliente || {};
    if (!tiene(req, 'clientes.crear')) return err(res, 403, 'No tienes permiso para registrar clientes nuevos.');
    const nombre = typeof c.nombre === 'string' ? c.nombre.trim() : '';
    if (!nombre || nombre.length > 100) return err(res, 422, 'El nombre del cliente es obligatorio (hasta 100 caracteres).');
    const correo = String(c.correo || '').trim() || null, tel = String(c.telefono || '').trim() || null;
    if (tel && tel.length > 20) return err(res, 422, 'El teléfono admite hasta 20 caracteres.');
    const rc = await callSP('sp_insertar_cliente', [nombre, correo, tel, 'Bronze'], ['p_id_cliente']);
    if (falloSP(res, rc)) return;
    idCliente = rc.out.p_id_cliente;
    await auditar(req, 'CREAR', 'cliente', idCliente, `nombre=${nombre}`);
  }

  const rv = await callSP('sp_insertar_conversacion', [idCliente, idCanal, req.user.sub, asunto, prioridad], ['p_id_conversacion']);
  if (falloSP(res, rv)) return;
  const idConv = rv.out.p_id_conversacion;
  const rm = await callSP('sp_insertar_mensaje', [idConv, 'Cliente', mensaje, null], ['p_id_mensaje']);
  if (falloSP(res, rm)) return;
  await auditar(req, 'CREAR', 'conversacion', idConv, `cliente=${idCliente}; canal=${idCanal}; prioridad=${prioridad}`);
  avisar('nueva', idConv, req.user.sub);
  res.status(201).json({ id: idConv, mensaje: 'Conversación creada.' });
}));

// Escalar a supervisión: queda Urgente y sin asignar (la cola que ven los supervisores) y se deja una nota del sistema.
router.post('/conversaciones/:id/escalar', ...ver, requierePermiso('conversaciones.responder'), h(async (req, res) => {
  const c = await cargarConv(req, res); if (!c) return;
  if (c.estado === 'Resuelto') return err(res, 409, 'La conversación ya está resuelta.');
  if (c.id_agente === null && c.prioridad === 'Urgente') return err(res, 409, 'Esta conversación ya está escalada.');
  const r = await callSP('sp_actualizar_conversacion', [c.id_conversacion, null, null, 'Urgente', null]);
  if (falloSP(res, r)) return;
  await callSP('sp_insertar_mensaje', [c.id_conversacion, 'Sistema', `Escalada a supervisión por ${req.user.nombre}.`, null], ['p_id_mensaje']);
  await auditar(req, 'ESCALAR', 'conversacion', c.id_conversacion, `${c.numero_ticket}: de ${c.agente || 'sin asignar'} a la cola de supervisión`);
  avisar('asignada', c.id_conversacion, c.id_agente);
  res.json({ mensaje: 'Conversación escalada: quedó urgente y sin asignar para que la tome un supervisor.' });
}));

// Ajustes visibles para el navegador (hoy solo el modo demo)
router.get('/config', autenticar, (req, res) => res.json({ demo: process.env.MODO_DEMO === '1' && tiene(req, 'conversaciones.ver_todas') }));

module.exports = router;
module.exports.cargarConv = cargarConv;   // los usa rutas-ia.js
module.exports.ver = ver;
