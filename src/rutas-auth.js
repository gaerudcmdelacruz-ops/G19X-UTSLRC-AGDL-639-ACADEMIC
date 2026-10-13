const express = require('express');
const bcrypt = require('bcryptjs');
const { callSP } = require('./db');
const { firmar, autenticar } = require('./auth');
const { falloSP } = require('./http');

const router = express.Router();
const HASH_FALSO = bcrypt.hashSync('no-es-una-clave', 10);   // para tardar igual si el correo no existe
const MAX_INTENTOS = 5, MINUTOS_BLOQUEO = 15;
const credencialesMal = res => res.status(401).json({ error: { codigo: 401, mensaje: 'Correo o contraseña incorrectos.' } });

router.post('/login', async (req, res, next) => {
  try {
    const { correo, password } = req.body || {};
    if (!correo || !password)
      return res.status(422).json({ error: { codigo: 422, mensaje: 'Correo y contraseña son obligatorios.' } });

    const u = await callSP('sp_leer_usuario_login', [correo]);
    const user = u.err === 0 ? u.rows[0] : null;

    if (user && user.bloqueado)
      return res.status(423).json({ error: { codigo: 423, mensaje: `Cuenta bloqueada temporalmente por intentos fallidos. Intenta de nuevo en ${MINUTOS_BLOQUEO} minutos.` } });

    const ok = await bcrypt.compare(String(password), user ? user.password_hash : HASH_FALSO);
    if (!user || !ok) {
      if (user) await callSP('sp_registrar_login', [user.id_usuario, 0, MAX_INTENTOS, MINUTOS_BLOQUEO]);
      return credencialesMal(res);
    }
    if (user.estado !== 'Activo' || user.rol_estado !== 'Activo')
      return res.status(403).json({ error: { codigo: 403, mensaje: 'Tu cuenta o tu rol está inactivo. Contacta al administrador.' } });

    await callSP('sp_registrar_login', [user.id_usuario, 1, MAX_INTENTOS, MINUTOS_BLOQUEO]);
    await callSP('sp_actualizar_presencia', [user.id_usuario, 'Disponible']);
    const p = await callSP('sp_leer_permisos_usuario', [user.id_usuario]);
    if (falloSP(res, p)) return;

    const usuario = { id: user.id_usuario, nombre: user.nombre_completo, correo: user.correo,
                      rol: user.rol, permisos: p.rows.map(r => r.codigo) };
    res.json({ token: firmar({ sub: usuario.id, ...usuario }), usuario });
  } catch (e) { next(e); }
});

router.get('/yo', autenticar, (req, res) => {
  const { sub, nombre, correo, rol, permisos } = req.user;
  res.json({ usuario: { id: sub, nombre, correo, rol, permisos } });
});

router.post('/logout', autenticar, async (req, res, next) => {
  try { await callSP('sp_actualizar_presencia', [req.user.sub, 'Desconectado']); res.json({ ok: true }); }
  catch (e) { next(e); }
});

module.exports = router;
