// JWT + control de permisos (RBAC). El servidor es quien decide; el frontend solo oculta enlaces.
const crypto = require('crypto');
const jwt = require('jsonwebtoken');

let SECRET = process.env.JWT_SECRET;
if (!SECRET) {
  SECRET = crypto.randomBytes(32).toString('hex');
  console.warn('[aviso] JWT_SECRET no definido: se generó uno temporal. Las sesiones se cierran al reiniciar el servidor.');
}
const EXPIRA = process.env.JWT_EXPIRA || '8h';

const firmar = payload => jwt.sign(payload, SECRET, { expiresIn: EXPIRA });

function autenticar(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: { codigo: 401, mensaje: 'Debes iniciar sesión.' } });
  try { req.user = jwt.verify(token, SECRET); next(); }
  catch { res.status(401).json({ error: { codigo: 401, mensaje: 'Sesión inválida o expirada.' } }); }
}

// requierePermiso('roles.editar') -> el usuario debe tener TODOS los permisos indicados
const requierePermiso = (...codigos) => (req, res, next) => {
  const tiene = (req.user && req.user.permisos) || [];
  if (codigos.every(c => tiene.includes(c))) return next();
  res.status(403).json({ error: { codigo: 403, mensaje: 'No tienes permiso para esta acción.' } });
};

module.exports = { firmar, autenticar, requierePermiso };
