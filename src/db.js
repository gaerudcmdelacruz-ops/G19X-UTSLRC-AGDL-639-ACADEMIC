// Conexión a MySQL y ayudante para llamar Stored Procedures (Paso B).
require('dotenv').config();
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',   // XAMPP: normalmente vacío
  database: process.env.DB_NAME || 'omnidesk_db',
  charset: 'utf8mb4',
  waitForConnections: true,
  connectionLimit: 10
});

/**
 * Llama a un SP. Convención de la v2: los OUT extra (ej. p_id_rol) van ANTES de p_error_num / p_error_text.
 *   callSP('sp_insertar_rol', [nombre, desc, actor], ['p_id_rol'])
 * Devuelve { err, text, rows, sets, out }.  err === 0 significa OK.
 */
async function callSP(nombre, params = [], extraOut = []) {
  const conn = await pool.getConnection();
  try {
    const nOut = extraOut.length + 2;
    const vars = Array.from({ length: nOut }, (_, i) => `@o${i}`);
    const marks = params.map(() => '?');
    const [res] = await conn.query(`CALL ${nombre}(${[...marks, ...vars].join(',')})`,
                                   params.map(p => (p === undefined ? null : p)));
    const sets = Array.isArray(res) ? res.filter(Array.isArray) : [];
    const [[o]] = await conn.query(`SELECT ${vars.map((v, i) => `${v} AS o${i}`).join(',')}`);
    const out = {};
    extraOut.forEach((n, i) => { out[n] = o['o' + i]; });
    const err = o['o' + extraOut.length];
    return { err: err == null ? 1 : Number(err), text: o['o' + (extraOut.length + 1)], rows: sets[0] || [], sets, out };
  } finally {
    conn.release();
  }
}

module.exports = { pool, callSP };
