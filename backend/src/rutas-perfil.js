// Mi Perfil: cada usuario ve y edita SOLO sus propios datos (el id sale del token, nunca del cliente).
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const bcrypt = require('bcryptjs');
const { callSP, pool, auditar } = require('./db');
const { autenticar, requierePermiso } = require('./auth');
const { falloSP } = require('./http');

const router = express.Router();
const h = fn => (req, res, next) => fn(req, res).catch(next);
const mal = (res, mensaje) => res.status(422).json({ error: { codigo: 422, mensaje } });

router.get('/perfil', autenticar, h(async (req, res) => {
  const r = await callSP('sp_leer_usuarios', [req.user.sub, null, null]);
  if (falloSP(res, r)) return;
  const { id_usuario, nombre_completo, correo, telefono, zona_horaria, rol, presencia, fecha_alta } = r.rows[0];
  const [f] = await pool.query('SELECT foto FROM usuarios WHERE id_usuario = ?', [req.user.sub]);
  res.json({ usuario: { id_usuario, nombre_completo, correo, telefono, zona_horaria, rol, presencia, fecha_alta, foto: f[0] ? f[0].foto : null } });
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

// ---------------------------------------------------------------------------------------------
// Foto de perfil. Cada usuario cambia SOLO la suya (el id sale del token). El navegador manda la imagen como cuerpo
// binario (Content-Type: image/png|jpeg|webp, máx. 1 MB). El servidor NO confía en el tipo declarado ni en el nombre:
// revisa los primeros bytes del archivo y lo guarda con un nombre generado en backend/uploads/avatares.
const DIR_AVATARES = path.join(__dirname, '..', 'uploads', 'avatares');
fs.mkdirSync(DIR_AVATARES, { recursive: true });
const MAX_FOTO = 1024 * 1024;
const NOMBRE_FOTO = /^\d+-[a-f0-9]{16}\.(png|jpg|webp)$/;
const FORMATOS = {
  'image/png':  { ext: 'png',  valida: b => b.length > 8  && b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) },
  'image/jpeg': { ext: 'jpg',  valida: b => b.length > 3  && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  'image/webp': { ext: 'webp', valida: b => b.length > 12 && b.toString('ascii', 0, 4) === 'RIFF' && b.toString('ascii', 8, 12) === 'WEBP' }
};
const borrarArchivo = async nombre => {          // solo borra nombres con la forma que genera este módulo
  if (nombre && NOMBRE_FOTO.test(nombre)) await fs.promises.unlink(path.join(DIR_AVATARES, nombre)).catch(() => {});
};
const cambios = new Map();                        // id_usuario -> marcas de tiempo (10 cambios por minuto)
const limiteFoto = (req, res, next) => {
  const ahora = Date.now(), r = (cambios.get(req.user.sub) || []).filter(t => ahora - t < 60000);
  if (r.length >= 10) return res.status(429).json({ error: { codigo: 429, mensaje: 'Demasiados cambios de foto. Espera un minuto.' } });
  r.push(ahora); cambios.set(req.user.sub, r); next();
};

router.put('/perfil/foto', autenticar, requierePermiso('perfil.editar_propio'), limiteFoto,
  express.raw({ type: Object.keys(FORMATOS), limit: MAX_FOTO }),
  h(async (req, res) => {
    const tipo = String(req.headers['content-type'] || '').split(';')[0].trim().toLowerCase();
    const formato = FORMATOS[tipo];
    if (!formato || !Buffer.isBuffer(req.body) || !req.body.length) return res.status(415).json({ error: { codigo: 415, mensaje: 'Sube una imagen PNG, JPG o WebP.' } });
    if (!formato.valida(req.body)) return mal(res, 'El archivo no es una imagen válida.');

    const nombre = `${req.user.sub}-${crypto.randomBytes(8).toString('hex')}.${formato.ext}`;
    await fs.promises.writeFile(path.join(DIR_AVATARES, nombre), req.body, { flag: 'wx' });
    const [antes] = await pool.query('SELECT foto FROM usuarios WHERE id_usuario = ?', [req.user.sub]);
    await pool.query('UPDATE usuarios SET foto = ? WHERE id_usuario = ?', [nombre, req.user.sub]);
    if (antes[0]) await borrarArchivo(antes[0].foto);
    await auditar(req, 'ACTUALIZAR_FOTO', 'usuario', req.user.sub, 'foto de perfil cambiada');
    res.json({ mensaje: 'Foto actualizada.', foto: nombre });
  }),
  (e, req, res, next) => {                        // cuerpo demasiado grande u otro error de lectura
    if (e && e.type === 'entity.too.large') return res.status(413).json({ error: { codigo: 413, mensaje: 'La imagen pesa más de 1 MB.' } });
    next(e);
  });

router.delete('/perfil/foto', autenticar, requierePermiso('perfil.editar_propio'), h(async (req, res) => {
  const [antes] = await pool.query('SELECT foto FROM usuarios WHERE id_usuario = ?', [req.user.sub]);
  await pool.query('UPDATE usuarios SET foto = NULL WHERE id_usuario = ?', [req.user.sub]);
  if (antes[0]) await borrarArchivo(antes[0].foto);
  await auditar(req, 'QUITAR_FOTO', 'usuario', req.user.sub, 'foto de perfil eliminada');
  res.json({ mensaje: 'Foto eliminada.' });
}));

module.exports = router;
module.exports.DIR_AVATARES = DIR_AVATARES;
