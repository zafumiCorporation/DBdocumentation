-- Devuelve los tutoriales de una coleccion en el orden correcto.
create or replace function public.fn_coleccion_listar(
    p_yo bigint, -- Usuario que intenta ver la coleccion.
    p_coleccion_id bigint -- coleccion que se desea mostrar.
)
returns table(
    tutorial_id bigint, -- Id del tutorial
    titulo varchar, -- Nombre del tutorial
    orden int, -- Posicion dentro de la playlist.
    anterior_id bigint, -- Tutorial anterior.
    siguiente_id bigint -- Tutorial siguiente.
)
language plpgsql
stable
parallel safe
set search_path = ''
as $$
declare
    v_dueno bigint; --  Dueno de la coleccion.
    v_vis public.coleccion_visibilidad; -- Visibilidad de la coleccion.
begin
    -- Obtiene dueno , visibilidad.
    select dueno_id, visibilidad
    into v_dueno, v_vis
    from public.colecciones
    where id = p_coleccion_id;

    if v_dueno is null then
        raise exception 'coleccion % no existe', p_coleccion_id;
    end if;

    if v_vis = 'privada' and v_dueno is distinct from p_yo then
        raise exception 'coleccion privada';
    end if;

    return query
    select
        t.id,
        t.titulo,
        i.orden,
        -- lag()-> Obtiene la fila anterior.
        lag(t.id) over (order by i.orden),
        -- lead() -> Obtiene la fila siguiente.
        lead(t.id) over (order by i.orden)
    from public.coleccion_items as i
    -- join -> Permite obtener Titulo , Id. de cada tutorial
    join public.tutoriales as t on t.id = i.tutorial_id
    where i.coleccion_id = p_coleccion_id -- Solo trae tutoriales de esa coleccion.
    order by i.orden; -- Devuelve los tutoriales en el orden de la playlist.
end;
$$;

-- PRUEBA 1: Listar los tutoriales en el orden correcto.
-- Consultar la coleccion utilizando fn_coleccion_listar().
-- Resultado esperado: Se devuelve tres filas.
-- tutorial_id = 4 ocupa la posicion 1.
-- anterior_id = null.
-- siguiente_id = 1.

-- tutorial_id = 1 ocupa la posicion 2.
-- anterior_id = 4.
-- siguiente_id = 2.

-- tutorial_id = 2 ocupa la posicion 3.
-- anterior_id = 1.
-- siguiente_id = null.

select '--- PRUEBA 1: listar el dueno ---' as test;

-- 1 = Shiriaru. 1 = "Word + Excel".
select tutorial_id, titulo, orden, anterior_id, siguiente_id
from public.fn_coleccion_listar(1, 1);

-- PRUEBA 2: Restringir el acceso segun la visibilidad.
-- 1. Julio intenta consultar la coleccion privada.
-- 2. Cambiar temporalmente la visibilidad a no listada.
-- 3. Julio vuelve a consultar la coleccion .
-- 4. Restaurar la visibilidad privada.

-- Resultado esperado:
-- Con visibilidad no_listada: Julio puede consultar los tres tutoriales.
-- Se conserva el orden de los tutoriales. Finalmente, la coleccion vuelve a ser privada.

select '--- PRUEBA 2: privada vs no_listada ---' as test;

-- Primer intento: se lanza la excepcion: 'coleccion privada'.
do $$
begin
    perform *
    from public.fn_coleccion_listar(2, 1);
    raise exception 'FALLO: Julio vio la privada ';
exception
    when others then
    if sqlerrm like 'FALLO%' then
        raise;
    end if;
    raise notice 'OK privada: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK privada: coleccion privada.

update public.colecciones
set visibilidad = 'no_listada'
where id = 1;

select tutorial_id, orden
from public.fn_coleccion_listar(2, 1);
-- Esperado: Las mismas tres filas.

update public.colecciones
set visibilidad = 'privada'
where id = 1;

-- PRUEBA 3. Rechar colecciones inexistentes.
-- Objetivo: Verificar que fn_coleccion_listar() , rechace solicitudes de colecciones que no existen.
-- Estado inicial: Shiriaru (usuario_id = 1) existente. No existe una coleccion con id = 99.
-- Accion: Intentar listar la coleccion 99.

select '--- PRUEBA 3: ausente ---' as test;

do $$
begin
    perform *
    from public.fn_coleccion_listar(1, 99);
    raise exception 'FALLO: listo la 99';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK ausente: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK ausente: coleccion 99 no existe.