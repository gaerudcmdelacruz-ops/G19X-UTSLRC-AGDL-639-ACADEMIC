// Mi Perfil: cada usuario ve y edita SOLO sus propios datos (el id sale del token, nunca del cliente).
const express = require('express');
const bcrypt = require('bcryptjs');
const { callSP, auditar } = require('./db');
const { autenticar, requierePermiso } = require('./auth');
const { falloSP } = require('./http');

const router = express.Router();
const h = fn => (req, res, next) => fn(req, res).catch(next);
const mal = (res, mensaje) => res.status(422).json({ error: { codigo: 422, mensaje } });

router.get('/perfil', autenticar, h(async (req, res) => {
  const r = await callSP('sp_leer_usuarios', [req.user.sub, null, null]);
  if (falloSP(res, r)) return;
  const { id_usuario, nombre_completo, correo, telefono, zona_horaria, rol, presencia, fecha_alta } = r.rows[0];
  res.json({ usuario: { id_usuario, nombre_completo, correo, telefono, zona_horaria, rol, presencia, fecha_alta } });
}));

router.put('/perfil', autenticar, requierePermiso('perfil.editar_propio'), h(async (req, res) => {
  const { nombre, telefono, zona_horaria } = req.body || {};
  if (typeof nombre !== 'string' || nombre.trim().length > 100) return mal(res, 'El nombre es obligatorio y admite hasta 100 caracteres.');
  if (telefono && String(telefono).trim().length > 20) return mal(res, 'El teléfono admite hasta 20 caracteres.');
  if (zona_horaria && String(zona_horaria).length > 50) return mal(res, 'La zona horaria no es válida.');
  const r = await callSP('sp_actualizar_perfil', [req.user.sub, nombre, telefono || null, zona_horaria || null]);
  if (falloSP(res, r)) return;
  await auditar(req, 'ACTUALIZAR_PERFIL', 'usuario', req.user.sub, `nombre=${nombre.trim()}`);
  res.json({ mensaje: r.text });
}));

// Límite de intentos con la contraseña actual (protege si alguien usa una sesión ajena): 5 fallos / 15 min por usuario
const fallos = new Map();
router.post('/perfil/password', autenticar, requierePermiso('perfil.editar_propio'), h(async (req, res) => {
  const { actual, nueva } = req.body || {};
  if (typeof actual !== 'string' || typeof nueva !== 'string' || !actual) return mal(res, 'Debes indicar la contraseña actual y la nueva.');
  if (nueva.length < 8) return mal(res, 'La nueva contraseña debe tener al menos 8 caracteres.');
  if (nueva === actual) return mal(res, 'La nueva contraseña debe ser distinta de la actual.');

  const f = fallos.get(req.user.sub);
  if (f && f.n >= 5 && Date.now() - f.t < 15 * 60 * 1000)
    return res.status(429).json({ error: { codigo: 429, mensaje: 'Demasiados intentos. Espera 15 minutos.' } });

  const u = await callSP('sp_leer_usuario_login', [req.user.correo]);
  if (falloSP(res, u)) return;
  if (!(await bcrypt.compare(actual, u.rows[0].password_hash))) {
    const n = f && Date.now() - f.t < 15 * 60 * 1000 ? f.n + 1 : 1;
    fallos.set(req.user.sub, { n, t: Date.now() });
    return mal(res, 'La contraseña actual no es correcta.');   // 422, no 401: un 401 cerraría la sesión en el navegador
  }
  fallos.delete(req.user.sub);
  const r = await callSP('sp_actualizar_password', [req.user.sub, await bcrypt.hash(nueva, 12)]);
  if (!falloSP(res, r)) res.json({ mensaje: r.text });
}));

module.exports = router;
