// Usuarios / Agentes. Las reglas (último admin, correo único, rol activo...) viven en los SP del Paso B.
const express = require('express');
const bcrypt = require('bcryptjs');
const { callSP } = require('./db');
const { autenticar, requierePermiso } = require('./auth');
const { falloSP } = require('./http');

const router = express.Router();
const h = fn => (req, res, next) => fn(req, res).catch(next);
const idDe = req => { const n = Number(req.params.id); return Number.isInteger(n) && n > 0 ? n : null; };
const idMal = res => res.status(422).json({ error: { codigo: 422, mensaje: 'El identificador no es válido.' } });

// Roles activos para el selector del formulario
router.get('/roles-asignables', autenticar, requierePermiso('agentes.ver'), h(async (req, res) => {
  const r = await callSP('sp_leer_roles', [null]);
  if (falloSP(res, r)) return;
  res.json({ roles: r.rows.filter(x => x.estado === 'Activo').map(x => ({ id_rol: x.id_rol, nombre: x.nombre })) });
}));

router.get('/usuarios', autenticar, requierePermiso('agentes.ver'), h(async (req, res) => {
  const rol = Number(req.query.id_rol) > 0 ? Number(req.query.id_rol) : null;
  const estado = ['Activo', 'Inactivo'].includes(req.query.estado) ? req.query.estado : null;
  const r = await callSP('sp_leer_usuarios', [null, rol, estado]);
  if (!falloSP(res, r)) res.json({ usuarios: r.rows });
}));

router.get('/usuarios/:id', autenticar, requierePermiso('agentes.ver'), h(async (req, res) => {
  const id = idDe(req); if (!id) return idMal(res);
  const r = await callSP('sp_leer_usuarios', [id, null, null]);
  if (!falloSP(res, r)) res.json({ usuario: r.rows[0] });
}));

router.post('/usuarios', autenticar, requierePermiso('agentes.crear'), h(async (req, res) => {
  const { nombre, correo, password, id_rol, telefono, zona_horaria } = req.body || {};
  if (typeof password !== 'string' || password.length < 8)
    return res.status(422).json({ error: { codigo: 422, mensaje: 'La contraseña debe tener al menos 8 caracteres.' } });
  const hash = await bcrypt.hash(password, 12);
  const r = await callSP('sp_insertar_usuario',
    [Number(id_rol) || null, nombre, correo, hash, telefono, zona_horaria, req.user.sub], ['p_id_usuario']);
  if (!falloSP(res, r)) res.status(201).json({ id: r.out.p_id_usuario, mensaje: r.text });
}));

router.put('/usuarios/:id', autenticar, requierePermiso('agentes.editar'), h(async (req, res) => {
  const id = idDe(req); if (!id) return idMal(res);
  const { nombre, correo, telefono, zona_horaria, estado } = req.body || {};
  if (estado === 'Inactivo' && !req.user.permisos.includes('agentes.desactivar'))
    return res.status(403).json({ error: { codigo: 403, mensaje: 'No tienes permiso para desactivar agentes.' } });
  const r = await callSP('sp_actualizar_usuario', [id, nombre, correo, telefono, zona_horaria, estado || null, req.user.sub]);
  if (!falloSP(res, r)) res.json({ mensaje: r.text });
}));

router.put('/usuarios/:id/rol', autenticar, requierePermiso('agentes.editar'), h(async (req, res) => {
  const id = idDe(req); if (!id) return idMal(res);
  const r = await callSP('sp_cambiar_rol_usuario', [id, Number((req.body || {}).id_rol) || null, req.user.sub]);
  if (!falloSP(res, r)) res.json({ mensaje: r.text });
}));

router.delete('/usuarios/:id', autenticar, requierePermiso('agentes.desactivar'), h(async (req, res) => {
  const id = idDe(req); if (!id) return idMal(res);
  const r = await callSP('sp_eliminar_usuario', [id, req.user.sub]);
  if (!falloSP(res, r)) res.json({ mensaje: r.text });
}));

module.exports = router;
