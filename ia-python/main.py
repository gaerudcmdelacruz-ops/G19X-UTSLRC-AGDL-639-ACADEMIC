"""Servicio de IA de OmniDesk (FastAPI).

Arranque (desde la carpeta ia-python):
    uvicorn main:app --port 8000
Documentación interactiva y pruebas: http://localhost:8000/docs
"""
import hmac
import os

from fastapi import FastAPI, Header
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

import analisis

analisis.cargar_env()

app = FastAPI(
    title="OmniDesk · Servicio de IA",
    description="Analiza una conversación de atención al cliente: sentimiento, etiquetas, resumen y respuesta sugerida.",
    version="1.0.0",
)


class Mensaje(BaseModel):
    remitente: str = ""
    autor: str | None = None
    contenido: str = ""


class Conversacion(BaseModel):
    cliente: str | None = None
    nivel: str | None = None
    canal: str | None = None
    asunto: str | None = None
    prioridad: str | None = None
    mensajes: list[Mensaje] = Field(min_length=1, max_length=60)
    anterior: str | None = None


def _error(codigo: int, mensaje: str) -> JSONResponse:
    return JSONResponse(status_code=codigo, content={"codigo": codigo, "mensaje": mensaje})


def _clave_valida(recibida: str | None) -> bool:
    esperada = (os.environ.get("IA_SERVICIO_CLAVE") or "").strip()
    return not esperada or hmac.compare_digest((recibida or "").encode(), esperada.encode())


@app.get("/salud", summary="Comprueba que el servicio está encendido y configurado")
def salud():
    return {"activa": analisis.proveedor() is not None, "proveedor": analisis.proveedor(), "modelo": analisis.modelo()}


@app.post("/analizar", summary="Analiza una conversación")
def analizar(datos: Conversacion, x_servicio_clave: str | None = Header(default=None)):
    # Es una función normal (def), así FastAPI la ejecuta en un hilo y la espera a la IA no bloquea otras peticiones
    if not _clave_valida(x_servicio_clave):
        return _error(401, "Clave del servicio de IA incorrecta. Revisa IA_SERVICIO_CLAVE en los dos .env.")
    try:
        return analisis.analizar(datos.model_dump())
    except analisis.ErrorIA as e:
        return _error(e.codigo, e.mensaje)
