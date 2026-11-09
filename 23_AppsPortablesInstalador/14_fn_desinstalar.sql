-- Objetivo es : Marcar una aplicacion como desinstala y devolver los rastros necesarios para eliminarla.
-- 1. Busca los rastros guardados. 2. Marca la aplicacion como desinstalada
-- 3. Devuelve los rastros. 4. El agente usa esos rastros para borrar cosas fuera de PostgreSQL
create or replace function public.fn_desinstalar(
    p_yo bigint, -- Id del usuario que quiere desistalar la aplicacion.
    p_aplicacion_id bigint -- Es la aplicacion que se quiere desinstalar.
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_rastros jsonb; -- Guardara los rastros encontrados. Que carpeta borrar. Que exe borrar. Que acceso directo borrar.
    v_tipo public.app_tipo_paquete; -- Guardara portable , instalada , runtime
begin
    -- Obtiene los rastros y El tipo de aplicacion.
    select au.rastros, c.tipo
    into v_rastros, v_tipo
    from public.aplicaciones_usuario as au
    -- Une aplicaciones_usuario con aplicaciones_catalogo mediante aplicacion_id
    join public.aplicaciones_catalogo as c on c.id = au.aplicacion_id
    -- Busca exactamente: Esta aplicacion , de este usuario .
    where au.usuario_id = p_yo and au.aplicacion_id = p_aplicacion_id
    for update;

    if not found then
        raise exception 'no hay instalacion para usuario % app %', p_yo, p_aplicacion_id;
    end if;

    if v_tipo = 'runtime' then
        raise exception 'runtime no se borra como carpeta portable (Hyper-V / jDK) - usa panel Windows';
    end if;

    -- Se actualiza el invetarios del usuario.
    update public.aplicaciones_usuario
    set estado = 'desinstalada',
        desistalada_en = now(), -- Guarda fecha de desistalacion.
        updated_at = now() -- Actualiza fecha de modificacion.
    -- Actualiza unicamente: La aplicacion indicada , del usuario indicado.
    where usuario_id = p_yo and aplicacion_id = p_aplicacion_id;

    -- Devuelve los rastros , Si existen rastros : devuelvelos . Si son null : devuelve {}.
    return coalesce(v_rastros, '{}'::jsonb);
end;
$$;

-- PRUEBA 1 Registrar una desinstalacion de aplicacion portable.
-- Objetivo: Verificar que fn_desistalar() , marque correctamente la aplicacion como desinstalada
-- y devuelva los rastros necesarios para la limpieza.
-- Estado inicial: La aplicacion esta instalada , Existen rastros almacenados.
-- Accion: Solicitar la desinstalacion.
-- Resultado esperado: estado = desinstalada , desistalada_en recibe fecha, La funcion devuelve el JSON con rastros.

select '--- PRUEBA 1: desinstalar Notepad ---' as test;

select estado, rastros->>'carpeta' as carpeta
from public.aplicaciones_usuario
where usuario_id = 1
    and aplicacion_id = (select id from public.aplicaciones_catalogo where slug = 'notepadpp-portable');
-- Esperado ahora: estado instalada. carpeta con la ruta de Portables\shiriaru\notepadpp-portable\8.6.

-- 1 = Shiriaru, usuario.id.
-- El subquery es notepadpp-portable
select public.fn_desinstalar(
       1,
       (select id from public.aplicaciones_catalogo where slug = 'notepadpp-portable')
) as rastros;
-- Esperado: el objeto JSON. carpeta, accesos_directos, appdata, localappdata y registro.

select estado, desistalada_en is not null as tiene_fecha
from public.aplicaciones_usuario
where usuario_id = 1
    and aplicacion_id = (select id from public.aplicaciones_catalogo where slug = 'notepadpp-portable');
-- Esperado: estado desinstalada, tiene_fecha true.

-- PRUEBA 2 Impedir la desisntalacion de runtimes.
-- Objetivo: Verificar que fn_desistalar() bloquee componentes marcados como runtime
-- Estado inicial: Hyper-V aparece como instalada , Hyper-V esta catalogada como runtime.
-- Accion: Intentar desinstalarla mediante fn_desinstalar().
-- Resultado esperado: Se genera una excepcion, No se devuelve ningun rastro , El estado permanece instalada.

select '--- PRUEBA 2: runtime no se borra ---' as test;

-- 1 = Shiriaru. El subquery es hyper-v, aplicaicones_catalogo.id. tipo runtime.
select public.fn_marcar_detectada(
    1,
    (select id from public.aplicaciones_catalogo where slug = 'hyper-v')
);

select estado, origen
from public.aplicaciones_usuario
where usuario_id = 1
    and aplicacion_id = (select id from public.aplicaciones_catalogo where slug = 'hyper-v');
-- Esperado ahora: estado instalada, origen detectada.

do $$
begin
    perform public.fn_desinstalar(
        1,
        (select id from public.aplicaciones_catalogo where slug = 'hyper-v')
    );
    raise exception 'FALLO: borro un runtime';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK runtime: %', sqlerrm;
end
$$;
-- Esperado en Messages: OK runtime: runtime no se borra como carpeta portable (Hyper-V / JDK) - usa panel Windows.

select estado
from public.aplicaciones_usuario
where usuario_id = 1
  and aplicacion_id = (select id from public.aplicaciones_catalogo where slug = 'hyper-v');
-- Esperado: sigue instalada.

