-- Cirugia de catalogo + un paso UIA + resolucion ruta portable.
-- Plantilla guardada : {localappdata}\AIAssistant\Portables\{handle}\{slug}\{version}
-- Esta funcion reemplaza cada plantilla por datos reales y te devuelve
-- {localappdata}\AIAssistant\Portables\shiriaru\notepadpp-portable\8.6
create or replace function public.fn_ruta_portable(
    p_yo bigint, -- ID del usuario. Ej: 1 = Shiriaru.
    p_aplicacion_id bigint -- ID de la app portable. Ej: Notepad++
)
returns text
language plpgsql
stable
parallel safe
set search_path = ''
as $$
declare
    v_app public.aplicaciones_catalogo%ROWTYPE; -- Guarda una fila completa de aplicaciones_catalogo
    v_handle text; -- Aqui se guarda el nombre del usuario limpio. Ej: shiriaru
begin
    -- Busca la app con ese ID y que este activa , la guarda en v_app.
    select * into v_app
    from public.aplicaciones_catalogo
    where id = p_aplicacion_id
    and activa;

    if not found then -- Si no encontro o esta desactivada lanza error.
        raise exception 'aplicacion % no existe o inactiva', p_aplicacion_id;
    end if;

    -- Busca el nombre del usuario
    select public.fn_normalizar_slug(
        -- nullif -> Si handle es texto vacio '' , convierte en null
        -- Si handle es null, usa username.
        coalesce(nullif(handle, ''), username)::public.citext
    )
    into v_handle
    from public.usuarios
    where id = p_yo; -- Segun el id del usuario que se pasa como parametro.

    return replace(replace(replace(replace( -- replace siempre reemplaza un texto por otro.
        v_app.ruta_plantilla,
        -- Busca '{localappdata}' en la plantilla y lo replaza por '{localappdata}'
        '{localappdata}', '{localappdata}'
        ),
        -- Busca {handle} en la plantilla y lo remplaza por
        '{handle}',
        -- Si v_handle es null , usa 'u' + id del usuario Ej: u1
        coalesce(v_handle, 'u' || p_yo::text)
        ),
        -- Busca {slug}, en la plantilla y lo remplaza por v_app.slug Ej: notepadpp-portable.
        '{slug}',
        v_app.slug
        ),
        -- Busca {version}, en la plantilla y lo reemplaza por v_app.version_paquete. Ej: 8.6.
        '{version}',
        v_app.version_paquete
        );
end;
$$;

-- PRUEBA 1 Ruta portable con handle existente.
-- Objetivo: Verificar que la funcion resuelva la plantilla usando el handle del usuario y NO una ruta absoluta.
-- Estado inicial: usuarios.id = 1 , username = Shiriaru , handle = @Shiriaru ,
-- aplicaciones_catalogo.slug = notepadpp-portable , version_paquete = 8.6
-- Accion: llamar fn_ruta_portable(1, id_de_notepad)
-- Resultado esperado: {localappdata}\AIAssistant\Portables\shiriaru\notepadpp-portable\8.6

-- Valida select public.fn_normalizar_slug , replace(..., '{handle}', coalesce(v_handle, 'u' || p_yo::text))

-- 1 = Shiriaru, usuarios.id. handle @Shiriaru se normaliza a shiriaru.
-- El subquery es notepadpp-portable, aplicaciones_catalgo.id. version_paquete 8.6
select public.fn_ruta_portable(
       1,
       (select  id from public.aplicaciones_catalogo where slug = 'notepadpp-portable')
) as ruta;
-- Esperado: {localappdata}\AIAssistant\Portables\shiriaru\notepadpp-portable\8.6

-- PRUEBA 2. Julio no tiene handle. La funcion usa el username
-- Objetivo: Verificar el fallback a username cuando handle es null o vacio.
-- Estado inicial: usuarios.id = 2 , username = Julio, handle = null (o '')
-- aplicaciones_catalogo.slug = notepadpp-portable , version_paquete = 8.6
-- Accion: Llamar fn_ruta_portable(2, id_de_notepad)
-- Resultado esperado: {localappdata}\AIAssistant\Portables\julio\notepadpp-portable\8.6

select '--- PRUEBA 2: ruta sin handle ---' as test;

select public.fn_ruta_portable(
    2,
     (select id from public.aplicaciones_catalogo where slug = 'notepadpp-portable')
) as ruta;
-- Esperado: {localappdata}\AIAssistant\Portables\julio\notepadpp-portable\8.6

-- PRUEBA 3 Aplicacion inexistente debe lanzar error.
-- Objetivo : Verificar que la funcion valide que la app existe y esta activa.
-- Estado inicial: p_yo = 1 (Shiriraru existente) , p_aplicacion_id = 99999 (No existe en aplicaciones_catalogo)
-- Accion: Llamar fn_ruta_portable(1, 99999)
-- Resultado esperado: La funcion debe hacer RAISE EXCEPTION , Mensaje: aplicacion 99999 no existe o inactiva.

-- 1 = Shiriaru. 99999 no esta en aplicaciones_catalogo

select '--- PRUEBA 3 ---'
-- Valida  select * into v_app .
do $$
begin
    perform public.fn_ruta_portable(1, 99999);
    raise exception 'FALLO: acepto un id que no existe';
exception
    when others then
    if sqlerrm like 'FALLO:%' then
        raise;
    end if;
    raise notice 'OK app inexistente: %', sqlerrm;
end;
$$;
