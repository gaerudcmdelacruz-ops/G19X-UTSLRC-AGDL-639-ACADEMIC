// Consulta de la auditoría (solo lectura). Permiso: auditoria.ver.
const express = require('express');
const { callSP } = require('./db');
const { autenticar, requierePermiso } = require('./auth');
const { falloSP } = require('./http');

const router = express.Router();
const h = fn => (req, res, next) => fn(req, res).catch(next);
const ENTIDADES = ['rol', 'usuario', 'canal', 'cliente', 'conversacion'];

router.get('/auditoria', autenticar, requierePermiso('auditoria.ver'), h(async (req, res) => {
  const entidad = ENTIDADES.includes(req.query.entidad) ? req.query.entidad : null;
  const limite = Math.min(Math.max(Number(req.query.limite) || 100, 1), 500);
  const r = await callSP('sp_leer_auditoria', [entidad, null, null, limite]);
  if (!falloSP(res, r)) res.json({ registros: r.rows });
}));

module.exports = router;
