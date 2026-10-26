// Fija la contraseña de un usuario existente (reemplaza el hash inválido de los datos demo).
// Uso:  npm run admin
const readline = require('readline');
const bcrypt = require('bcryptjs');
const { pool, callSP } = require('../src/db');

const rl = readline.createInterface({ input: process.stdin, output: process.stdout, terminal: true });
let oculto = false;
const original = rl._writeToOutput;
rl._writeToOutput = function (s) { if (oculto && s.trim() !== '' && !s.includes('\n')) return original.call(rl, '*'); original.call(rl, s); };
const preguntar = (q, ocultar = false) => new Promise(r => { oculto = false; process.stdout.write(q); oculto = ocultar; rl.question('', a => { oculto = false; if (ocultar) process.stdout.write('\n'); r(a); }); });

(async () => {
  try {
    const correo = (await preguntar('Correo del usuario [admin@omnidesk.local]: ')).trim() || 'admin@omnidesk.local';
    const u = await callSP('sp_leer_usuario_login', [correo]);
    if (u.err !== 0) { console.log('\nNo existe un usuario con ese correo. ¿Cargaste db/datos-demo.sql?'); return; }
    const p1 = await preguntar('Nueva contraseña (mínimo 8 caracteres): ', true);
    if (p1.length < 8) { console.log('La contraseña es demasiado corta. No se hizo ningún cambio.'); return; }
    const p2 = await preguntar('Repite la contraseña: ', true);
    if (p1 !== p2) { console.log('Las contraseñas no coinciden. No se hizo ningún cambio.'); return; }
    const r = await callSP('sp_actualizar_password', [u.rows[0].id_usuario, await bcrypt.hash(p1, 12)]);
    console.log(r.err === 0 ? `\nListo: contraseña actualizada para ${correo}.` : `\nError: ${r.text}`);
  } catch (e) {
    console.log('\nNo se pudo conectar a la base de datos:', e.code || e.message);
  } finally { rl.close(); await pool.end(); }
})();
