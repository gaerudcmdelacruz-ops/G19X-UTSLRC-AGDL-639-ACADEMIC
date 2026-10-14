// Reportes de atención. Permiso: reportes.ver. Usa los SP del Paso B (07_sp_reportes_auditoria.sql).
const express = require('express');
const { callSP } = require('./db');
const { autenticar, requierePermiso } = require('./auth');
const { falloSP } = require('./http');

const router = express.Router();
const h = fn => (req, res, next) => fn(req, res).catch(next);
const ymd = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const suma = (d, n) => { const x = new Date(d); x.setDate(x.getDate() + n); return x; };
// MySQL devuelve DECIMAL/SUM como texto: se convierte a número aquí para que el navegador no tenga que adivinar
const num = v => (v === null || v === undefined || v === '') ? null : Number(v);
const numeros = (fila, campos) => { const o = { ...fila }; campos.forEach(c => { if (c in o) o[c] = num(o[c]); }); return o; };

router.get('/reportes', autenticar, requierePermiso('reportes.ver'), h(async (req, res) => {
  const dias = [7, 30, 90].includes(Number(req.query.dias)) ? Number(req.query.dias) : 7;
  const hoy = new Date(), desde = suma(hoy, -(dias - 1));
  const d = ymd(desde), hasta = ymd(hoy);
  const [resumen, anterior, canales, sentimiento, agentes] = await Promise.all([
    callSP('sp_reporte_resumen', [d, hasta]),
    callSP('sp_reporte_resumen', [ymd(suma(desde, -dias)), ymd(suma(desde, -1))]),   // periodo anterior, mismo largo
    callSP('sp_reporte_mensajes_por_canal', [d, hasta]),
    callSP('sp_reporte_sentimiento', [d, hasta]),
    callSP('sp_reporte_rendimiento_agentes', [d, hasta])
  ]);
  const fallo = [resumen, anterior, canales, sentimiento, agentes].find(r => r.err !== 0);
  if (fallo) { falloSP(res, fallo); return; }

  const RES = ['total_conversaciones', 'abiertas', 'pendientes', 'resueltas', 'tasa_resolucion_pct', 'minutos_primera_respuesta', 'satisfaccion_pct', 'total_mensajes'];
  res.json({
    dias, desde: d, hasta,
    resumen: numeros(resumen.rows[0] || {}, RES),
    anterior: numeros(anterior.rows[0] || {}, RES),
    canales: canales.rows.map(r => numeros(r, ['total_mensajes', 'conversaciones_con_actividad'])),
    sentimiento: sentimiento.rows.map(r => numeros(r, ['total', 'porcentaje'])),
    agentes: agentes.rows.map(r => numeros(r, ['asignadas', 'resueltas', 'tasa_resolucion_pct', 'minutos_primera_respuesta', 'minutos_resolucion', 'satisfaccion_pct']))
  });
}));

module.exports = router;
