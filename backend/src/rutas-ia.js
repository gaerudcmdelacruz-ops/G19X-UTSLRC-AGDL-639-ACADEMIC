// Rutas de IA (Paso D): análisis de una conversación con Claude.
// Una sola llamada devuelve sentimiento, etiquetas, resumen y respuesta sugerida. El resultado se guarda en memoria
// mientras la conversación no tenga mensajes nuevos, para no pagar dos veces por lo mismo.
const express = require('express');
const { callSP } = require('./db');
const { autenticar, requierePermiso } = require('./auth');
const { falloSP } = require('./http');
const { analizar, iaActiva, proveedor, modelo, ErrorIA } = require('./ia');
const { avisar } = require('./tiempo-real');
const { cargarConv, ver } = require('./rutas-conversaciones');

const router = express.Router();
const h = fn => (req, res, next) => fn(req, res).catch(next);
const err = (res, codigo, mensaje) => res.status(codigo).json({ error: { codigo, mensaje } });

const CACHE = new Map();        // id_conversacion -> { ultimo, analisis }
const EN_CURSO = new Map();     // id_conversacion -> Promise (evita análisis duplicados simultáneos)
const USOS = new Map();         // id_usuario -> [marcas de tiempo]
const MAX_POR_MINUTO = 12;

function limite(idUsuario) {
  const ahora = Date.now(), recientes = (USOS.get(idUsuario) || []).filter(t => ahora - t < 60000);
  if (recientes.length >= MAX_POR_MINUTO) { USOS.set(idUsuario, recientes); return false; }
  recientes.push(ahora); USOS.set(idUsuario, recientes); return true;
}
const sentimientoDe = p => (p < 40 ? 'Molesto' : p < 70 ? 'Neutral' : 'Satisfecho');

router.get('/ia/estado', autenticar, (req, res) => res.json({ activa: iaActiva(), proveedor: proveedor(), modelo: modelo() }));

// body { regenerar: true } fuerza un nuevo análisis y pide un borrador distinto
router.post('/conversaciones/:id/ia', ...ver, requierePermiso('conversaciones.responder'), h(async (req, res) => {
  if (!iaActiva()) return err(res, 503, 'La IA no está configurada en el servidor (falta GEMINI_API_KEY o ANTHROPIC_API_KEY).');
  const c = await cargarConv(req, res); if (!c) return;
  const regenerar = (req.body || {}).regenerar === true;

  const rm = await callSP('sp_leer_mensajes', [c.id_conversacion, null]);
  if (falloSP(res, rm)) return;
  const mensajes = rm.rows.slice(-30);
  if (!mensajes.length) return err(res, 422, 'La conversación aún no tiene mensajes para analizar.');
  const ultimo = mensajes[mensajes.length - 1].id_mensaje;

  const previo = CACHE.get(c.id_conversacion);
  if (!regenerar && previo && previo.ultimo === ultimo) return res.json({ analisis: previo.analisis, desde_cache: true });

  if (!limite(req.user.sub)) return err(res, 429, 'Has pedido demasiados análisis seguidos. Espera un minuto.');

  let tarea = EN_CURSO.get(c.id_conversacion);
  if (!tarea || regenerar) {
    tarea = analizar({
      cliente: c.cliente, nivel: c.nivel_lealtad, canal: c.canal, asunto: c.asunto, prioridad: c.prioridad,
      mensajes, anterior: regenerar && previo ? previo.analisis.respuesta_sugerida : null
    }).finally(() => EN_CURSO.delete(c.id_conversacion));
    EN_CURSO.set(c.id_conversacion, tarea);
  }
  let a;
  try { a = await tarea; }
  catch (e) { if (e instanceof ErrorIA) return err(res, e.codigo, e.message); throw e; }

  const analisis = { ...a, sentimiento: sentimientoDe(a.puntaje), fecha: new Date().toISOString() };
  if (CACHE.size > 300) CACHE.delete(CACHE.keys().next().value);
  CACHE.set(c.id_conversacion, { ultimo, analisis });

  // El puntaje se guarda en la base de datos (el trigger deriva Molesto/Neutral/Satisfecho)
  const rs = await callSP('sp_actualizar_sentimiento', [c.id_conversacion, a.puntaje]);
  if (rs.err !== 0) console.error('[IA] no se pudo guardar el sentimiento:', rs.text);
  else avisar('analisis', c.id_conversacion, c.id_agente);
  res.json({ analisis, desde_cache: false });
}));

module.exports = router;
