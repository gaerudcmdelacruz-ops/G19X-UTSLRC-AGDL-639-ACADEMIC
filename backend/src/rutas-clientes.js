// Clientes: por ahora solo el buscador que usa "Nueva conversación". Permiso: clientes.ver.
const express = require('express');
const { callSP } = require('./db');
const { autenticar, requierePermiso } = require('./auth');
const { falloSP } = require('./http');

const router = express.Router();
const h = fn => (req, res, next) => fn(req, res).catch(next);

router.get('/clientes', autenticar, requierePermiso('clientes.ver'), h(async (req, res) => {
  const r = await callSP('sp_leer_clientes', [null, String(req.query.q || '').slice(0, 100) || null, 'Activo']);
  if (falloSP(res, r)) return;
  res.json({ clientes: r.rows.slice(0, 20).map(c => ({
    id_cliente: c.id_cliente, nombre: c.nombre, correo: c.correo, nivel_lealtad: c.nivel_lealtad, telefono_enmascarado: c.telefono_enmascarado })) });
}));

module.exports = router;
