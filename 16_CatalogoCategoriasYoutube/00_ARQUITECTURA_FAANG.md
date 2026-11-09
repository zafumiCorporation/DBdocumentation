# Arquitectura FAANG — AI Assistant Desktop

Fuente de verdad para ir creando tablas bloque a bloque.
Fecha de analisis: 2026-08-24.

## Producto

App de escritorio en system tray. Guia al usuario paso a paso sobre otras apps
(Word, Unreal, PowerPoint, Excel, Photoshop, Tools) con overlay UIA
(rectangulo neon + etiqueta). Blueprints editables, scripts verificados,
amigos en sidebar, instalador con recomendacion IA, monitor privacy-first
(sin grabar pantalla). Fork al editar el tutorial de otro usuario.

## Estado real del curso (disco + BD)

Carpetas 02 a 12: vacias (espacio de practica SQL, no de producto).

En disco y ya usados:
- `00_ConfiguracionGlobal` — pgcrypto, pg_trgm, unaccent, immutable_unaccent
- `02_tablas_base` — usuarios, tutoriales, sesiones_ram
- `13_AuthSeguraFAANG` — login_desktop, logout_desktop, job 8h
- `14_BusquedaTrgmYoutubeStile` — GIN trgm + buscar_tutoriales
- `15_BlueprintsScriptsDataset` — DDL de producto (NO ejecutado en la BD viva)
- `16_PlataformaSocialFAANG` — recorte limpio, tabla a tabla

BD viva hoy: `usuarios`, `tutoriales`, `sesiones_ram`, `categorias`.
`tutoriales.categoria` sigue siendo VARCHAR, no FK. Eso se cambia despues
de cerrar `categorias`.

## Decisiones de ingenieria (YouTube / TikTok / Facebook)

1. Catalogo, no strings. Chips y filtros salen de `categorias`, no de un CHECK
   hardcodeado en `tutoriales`.
2. "Todo" no es fila. Es el filtro de la UI sin WHERE de categoria.
3. `categorias` != inventario de software. Los chips son discovery (Word).
   NetBeans Portable / VMware Player viven luego en `aplicaciones_usuario`
   + catalogo de instalables. No mezclar granos.
4. Presencia online sale de `sesiones_ram`, no de una columna en `usuarios`.
5. Likes/vistas: tabla de hechos + contador denormalizado + trigger.
   Nunca COUNT(*) en el feed.
6. JSONB solo para payloads flexibles (UIA, overlay, script). El grafo
   (nodos, aristas, pasos) es relacional.
7. Fork: copia nueva + `tutorial_padre_id` + fila en `tutorial_forks`.
8. Privacy: consentimiento UIA; `screen_record` forzado a false.
9. Telemetria (vistas, eventos sistema) particionada por mes.
10. Usuario/tutorial `id = 0` (system) para no perder historial al borrar.

## Orden de construccion (esta carpeta 16_)

| # | Tabla / objeto | Estado | UI que desbloquea |
|---|----------------|--------|-------------------|
| 1 | categorias | EN CURSO | chips Imagen 2 y 3 |
| 2 | tutoriales.categoria_id FK | pendiente | deja de ser texto suelto |
| 3 | tags + tutorial_tags | pendiente | Blueprints, Platformer |
| 4 | amistades + vista_amigos_sidebar | pendiente | panel Amigos |
| 5 | notificaciones | pendiente | solicitudes, forks, BSOD |
| 6 | tutorial_videos / media_assets | pendiente | preview video de cards |
| 7 | likes, favoritos, comentarios | pendiente | engagement |
| 8 | tipos_nodo, nodos, conexiones | pendiente | editor Blueprint |
| 9 | tutorial_pasos | pendiente | overlay Step 1..N |
| 10 | tutorial_scripts | pendiente | boton Ejecutar |
| 11 | tutorial_forks | pendiente | editar sin dañar original |
| 12 | tutorial_ejecuciones + pasos | pendiente | flujo pasos 5-9 |
| 13 | aplicaciones_catalogo (instalables) | pendiente | tab apps + VMware |
| 14 | aplicaciones_usuario | pendiente | Run / Uninstall |
| 15 | recomendaciones_instalacion | pendiente | Imagen 5 |
| 16 | consentimiento_uia, tipos_error, eventos_sistema, guias | pendiente | BSOD |
| 17 | dataset_entrenamiento, ia_correcciones_ruta | pendiente | learning loop |
| 18 | tutorial_vistas (particion), interacciones | pendiente | analytics feed |
| 19 | colecciones | pendiente | playlists |

No crear `aplicaciones_catalogo` como duplicado de `categorias`.
El catalogo de instalables llega en el bloque 13, con grano distinto
(version, publisher, tipo Portable vs Instalada).
