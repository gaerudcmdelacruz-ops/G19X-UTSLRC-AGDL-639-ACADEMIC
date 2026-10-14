# OmniDesk · Sistema de diseño (dark emerald)

**Fuente única de tokens:** `assets/omnidesk-tokens.js` (config de Tailwind). Ninguna pantalla define su propia config.
**Layout compartido:** `assets/omnidesk-layout.js` (cabecera superior + barra lateral de Configuración, filtradas por permisos).

## Estructura real de las pantallas
- Cabecera fija superior de 64 px (`h-16`) con navegación: Conversaciones · Reportes · Configuración.
- Configuración (Mi Perfil, Agentes, Canales, Roles y permisos) usa barra lateral fija de 256 px (`w-64`) y contenido con `pl-64`.
- Tipografía: Plus Jakarta Sans (texto), JetBrains Mono (IDs, horas, códigos). Iconos: Material Symbols Outlined.
- Superficies en capas: `surface #031427` → `surface-container-low #0b1c30` → `surface-container #102034` → `-high #1b2b3f` → `-highest #26364a`. Bordes de 1 px con `outline-variant`.
- Acento: `primary #10b981` (hover/enfoque `primary-light #4edea3`). Radios 8–16 px.

## Valores que las pantallas definían distinto (decisión adoptada)
| Token | Valores encontrados | Adoptado |
|---|---|---|
| primary | #4edea3 · #10b981 | #10b981 |
| primary-container | #10b981 · #005236 · #047857 | #005236 |
| on-surface | #d3e4fe · #f8fafc | #f8fafc |
| on-surface-variant | #bbcabf · #94a3b8 · #8ca3ba | #94a3b8 |
| outline | #86948a · #334155 | #334155 |
| outline-variant | #3c4a42 · #2a3a4f · #1e3347 · #1e293b | #1e293b |
| surface-container-low | #0b1c30 · #071727 | #0b1c30 |
| surface-container | #102034 · #0b1c30 · #0f233a | #102034 |
| tertiary | #bec6e0 · #8ca3ba · #64748b | #8ca3ba |
| error | #ffb4ab · #f87171 | #f87171 |
| secondary | #8ad892 · #34d399 | #34d399 |

Se priorizó la paleta de las pantallas más recientes (Conversaciones, Reportes, Mi Perfil). Cambiar un valor aquí lo cambia en todas las vistas.

## Pendiente
Muchas pantallas aún usan colores en hexadecimal directo (`bg-[#000f21]`, `border-[#1e293b]`) en lugar de tokens; conviene sustituirlos de forma gradual.
