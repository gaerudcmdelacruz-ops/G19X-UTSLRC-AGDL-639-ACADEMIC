// Roles y permisos (RBAC). Cada ruta exige un permiso; las reglas de negocio viven en los SP (Paso B).
const express = require('express');
const { callSP } = require('./db');
const { autenticar, requierePermiso } = require('./auth');
const { falloSP } = require('./http');

const router = express.Router();
const h = fn => (req, res, next) => fn(req, res).catch(next);   // Express 4: envía errores async al manejador
const idDe = req => { const n = Number(req.params.id); return Number.isInteger(n) && n > 0 ? n : null; };
const idMal = res => res.status(422).json({ error: { codigo: 422, mensaje: 'El identificador no es válido.' } });

router.get('/permisos', autenticar, requierePermiso('roles.ver'), h(async (req, res) => {
  const r = await callSP('sp_leer_permisos');
  if (!falloSP(res, r)) res.json({ permisos: r.rows });
}));

router.get('/roles', autenticar, requierePermiso('roles.ver'), h(async (req, res) => {
  const r = await callSP('sp_leer_roles', [null]);
  if (!falloSP(res, r)) res.json({ roles: r.rows });
}));

router.get('/roles/:id', autenticar, requierePermiso('roles.ver'), h(async (req, res) => {
  const id = idDe(req); if (!id) return idMal(res);
  const r = await callSP('sp_leer_roles', [id]);
  if (!falloSP(res, r)) res.json({ rol: r.rows[0] });
}));

router.post('/roles', autenticar, requierePermiso('roles.crear'), h(async (req, res) => {
  const { nombre, descripcion } = req.body || {};
  const r = await callSP('sp_insertar_rol', [nombre, descripcion, req.user.sub], ['p_id_rol']);
  if (!falloSP(res, r)) res.status(201).json({ id: r.out.p_id_rol, mensaje: r.text });
}));

router.put('/roles/:id', autenticar, requierePermiso('roles.editar'), h(async (req, res) => {
  const id = idDe(req); if (!id) return idMal(res);
  const { nombre, descripcion, estado } = req.body || {};
  const r = await callSP('sp_actualizar_rol', [id, nombre, descripcion, estado || null, req.user.sub]);
  if (!falloSP(res, r)) res.json({ mensaje: r.text });
}));

router.delete('/roles/:id', autenticar, requierePermiso('roles.eliminar'), h(async (req, res) => {
  const id = idDe(req); if (!id) return idMal(res);
  const r = await callSP('sp_eliminar_rol', [id, req.user.sub]);
  if (!falloSP(res, r)) res.json({ mensaje: r.text });
}));

router.get('/roles/:id/permisos', autenticar, requierePermiso('roles.ver'), h(async (req, res) => {
  const id = idDe(req); if (!id) return idMal(res);
  const r = await callSP('sp_leer_permisos_rol', [id]);
  if (!falloSP(res, r)) res.json({ permisos: r.rows });
}));

// Reemplaza el conjunto completo de permisos del rol: body { permisos: [1, 3, 7] }
router.put('/roles/:id/permisos', autenticar, requierePermiso('roles.asignar_permisos'), h(async (req, res) => {
  const id = idDe(req); if (!id) return idMal(res);
  const lista = (req.body || {}).permisos;
  if (!Array.isArray(lista) || lista.length > 200 || !lista.every(n => Number.isInteger(n) && n > 0))
    return res.status(422).json({ error: { codigo: 422, mensaje: 'La lista de permisos no es válida.' } });
  const r = await callSP('sp_asignar_permisos_rol', [id, lista.join(','), req.user.sub]);
  if (!falloSP(res, r)) res.json({ mensaje: r.text });
}));

module.exports = router;
