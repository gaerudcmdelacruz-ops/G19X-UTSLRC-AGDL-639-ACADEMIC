// Traduce p_error_num (Paso B) a códigos HTTP y respuestas de error uniformes.
const MAPA = { 0: 200, 404: 404, 403: 403, 409: 409, 422: 422, 1048: 422, 1062: 409, 1451: 409, 1452: 422 };
const estado = err => MAPA[err] || 500;

// Responde con error si el SP falló. Devuelve true si respondió.
function falloSP(res, r) {
  if (r.err === 0) return false;
  res.status(estado(r.err)).json({ error: { codigo: r.err, mensaje: r.text } });
  return true;
}
module.exports = { estado, falloSP };
