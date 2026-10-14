// Tiempo real con Socket.IO.
// El servidor solo AVISA ("la conversación 3 cambió"); el navegador vuelve a pedir los datos por la API normal,
// así los permisos se siguen comprobando en un único sitio (las rutas REST) y por el socket nunca viajan datos sensibles.
const { Server } = require('socket.io');
const { verificar } = require('./auth');

let io = null;

function iniciar(httpServer, origenes) {
  io = new Server(httpServer, { cors: { origin: origenes } });

  // Para conectarse hay que presentar el mismo token JWT del login
  io.use((socket, next) => {
    try { socket.data.user = verificar(socket.handshake.auth && socket.handshake.auth.token); next(); }
    catch { next(new Error('No autorizado')); }
  });

  io.on('connection', socket => {
    const u = socket.data.user;
    socket.join('u:' + u.sub);                                                  // sala personal: sus conversaciones asignadas
    if ((u.permisos || []).includes('conversaciones.ver_todas')) socket.join('todos'); // quien ve todo, recibe todo
  });
  return io;
}

// avisar('mensaje', 5, 3, 2) -> avisa a quienes ven todo y a los agentes 3 y 2 (el actual y el anterior, p. ej.)
function avisar(tipo, idConversacion, ...agentes) {
  if (!io) return;
  let destino = io.to('todos');
  for (const a of agentes) if (a) destino = destino.to('u:' + a);
  destino.emit('conversacion', { tipo, id_conversacion: idConversacion });
}

module.exports = { iniciar, avisar };
