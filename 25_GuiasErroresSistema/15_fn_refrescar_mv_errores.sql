-- Es un wrapper Simplemente ejecuta: refresh materialized view.
-- Objetivo: Administrar la actualizacion de las vistas materializadas utilizadas para consultar
-- rapidamente el catalogo de errores conocidos y resumir las ocurrencias registradas durante los ultimos siete dias.
create or replace function public.fn_refrescar_mv_errores()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- Con concurrently: no se bloquea los usuarios pueden seguir leyendo.
    refresh materialized view concurrently public.mv_errores_frecuentes;
end
$$;

-- PRUEBA 1: refrescar errores frecuentes .
-- Objetivo: Comprobar que la fotografia del catalogo se encuentra inicialmente vacia y que la funcion
-- wrapper consigue poblarla correctamente.
-- Consulta count(*) sobre mv_errores_frecuentes.
-- Resultado esperado: 0 filas almacenadas. Comprobacion: La vista fue creada con with no data.
select '--- PRUEBA 1: refrescar errores frecuentes ---' as test;

select count(*) as filas
from public.mv_errores_frecuentes;
-- Esperado ahora: 0. la vista fue creada con With no data.

select public.fn_refrescar_mv_errores();

-- Verificar por que en mv_errores_frecuentes no se registro nada.
select slug, veces_visto, guia_id is not null as trae_guia, tutorial_id
from public.mv_errores_frecuentes
order by veces_visto desc, slug;
-- Esperado: cinco filas.
-- hyperv-hypervisor-bloqueado, veces 2, trae_guia true, tutorial_id 1.
-- notepad-missing-files, veces 0, trae_guia true, tutorial_id null.
-- overlay-boton-ausente, veces 0, trae_guia false, tutorial_id null.
-- reloj-sistema, veces 0, trae_guia true, tutorial_id 4.
-- windows-bsod-pantalla-azul-de-la-muerte-7eea0689, veces 0, trae_guia false, tutorial_id null.

-- La funcion no toca la foto de 7 dias. El primer refresh va sin concurrently.
refresh materialized view public.mv_errores_frecuentes_7d;

select slug, eventos_7d
from public.mv_errores_frecuentes_7d
order by eventos_7d desc;
-- Esperado: una fila. hyperv-hypervisor-bloqueado, eventos_7d 2.
-- La pantalla azul se borro en el 04, asi que no entra.

