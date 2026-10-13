// Canales (WhatsApp, Email, Web Chat, Instagram...). Ver: canales.ver · Gestionar: canales.gestionar
const express = require('express');
const { callSP } = require('./db');
const { autenticar, requierePermiso } = require('./auth');
const { falloSP } = require('./http');

const router = express.Router();
const h = fn => (req, res, next) => fn(req, res).catch(next);
const idDe = req => { const n = Number(req.params.id); return Number.isInteger(n) && n > 0 ? n : null; };
const idMal = res => res.status(422).json({ error: { codigo: 422, mensaje: 'El identificador no es válido.' } });
const largo = (res, nombre, descripcion) =>
  (typeof nombre === 'string' && nombre.trim().length > 50) ? res.status(422).json({ error: { codigo: 422, mensaje: 'El nombre admite hasta 50 caracteres.' } })
  : (descripcion && String(descripcion).length > 150) ? res.status(422).json({ error: { codigo: 422, mensaje: 'La descripción admite hasta 150 caracteres.' } })
  : null;

router.get('/canales', autenticar, requierePermiso('canales.ver'), h(async (req, res) => {
  const r = await callSP('sp_leer_canales', [null]);
  if (!falloSP(res, r)) res.json({ canales: r.rows });
}));

router.post('/canales', autenticar, requierePermiso('canales.gestionar'), h(async (req, res) => {
  const { nombre, descripcion, icono, color_hex, estado } = req.body || {};
  if (largo(res, nombre, descripcion)) return;
  const r = await callSP('sp_insertar_canal', [nombre, descripcion, icono, color_hex, estado || null], ['p_id_canal']);
  if (!falloSP(res, r)) res.status(201).json({ id: r.out.p_id_canal, mensaje: r.text });
}));

router.put('/canales/:id', autenticar, requierePermiso('canales.gestionar'), h(async (req, res) => {
  const id = idDe(req); if (!id) return idMal(res);
  const { nombre, descripcion, icono, color_hex, estado } = req.body || {};
  if (largo(res, nombre, descripcion)) return;
  const r = await callSP('sp_actualizar_canal', [id, nombre, descripcion, icono, color_hex, estado || null]);
  if (!falloSP(res, r)) res.json({ mensaje: r.text });
}));

router.delete('/canales/:id', autenticar, requierePermiso('canales.gestionar'), h(async (req, res) => {
  const id = idDe(req); if (!id) return idMal(res);
  const r = await callSP('sp_eliminar_canal', [id]);
  if (!falloSP(res, r)) res.json({ mensaje: r.text });
}));

module.exports = router;
