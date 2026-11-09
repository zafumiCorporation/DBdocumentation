-- Elimina un tutorial de una coleccion.
create or replace function public.fn_coleccion_quitar_item(
    p_yo bigint, -- Id del usuario que intenta quitar el tutorial.
    p_coleccion_id bigint, -- Coleccion donde se eliminara.
    p_tutorial_id bigint -- Tutorial que se eliminara.
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_dueno bigint; -- Almacenara el dueno de la coleccion.
begin

    -- Obtiene Propietario de la coleccion.
    select dueno_id into v_dueno
    from public.colecciones
    where id = p_coleccion_id;

    -- El que elimina es el dueno?.
    if v_dueno is distinct from p_yo then
        raise exception 'solo el dueno quita items';
    end if;

    -- Elimina el tutorial de la coleccion.
    delete from public.coleccion_items
    where coleccion_id = p_coleccion_id
        and tutorial_id = p_tutorial_id;

    if not found then
        raise exception 'tutorial % no esta en al coleccion', p_tutorial_id;
    end if;

    return ( -- Cantidad de tutoriales que quedan en la coleccion.
        select items_count from public.colecciones where id = p_coleccion_id
    );
end;
$$;

-- PRUEBA 1. Eliminar un tutorial de una coleccion.
-- Accion: Eliminar tutorial_id = 1 de la coleccion 1.
-- Resultado esperado: Se elimina la fila correspondiente a tutorial_id = 1.
-- La coleccion conserva los tutoriales 4 y 2. items_count disminuye de 3 a 2.
-- La funcion devuelve 2.
-- Las posiciones restantes no se compactan:
-- tutorial_id = 4 conserva orden = 1.
-- tutorial_id = 2 conserva orden = 3.

select '--- PRUEBA 1: quitar item ---' as test;

select items_count
from public.colecciones
where id = 1;
-- Esperado ahora: 3.

-- 1 = Shiriaru. 1 sy playlist. 1 = "Create Sheet in Word", ahora en orden 2.
select public.fn_coleccion_quitar_item(1,1,1);
-- Esperado: 2.

select tutorial_id, orden
from public.coleccion_items
where coleccion_id = 1
order by orden;
-- Esperado: 4 orden 1. 2 orden 3. No compacta. Eso lo hace un reordenar despues.

select items_count
from public.colecciones
where id = 1;
-- Esperado: 2.

-- PRUEBA 2: Impedir eliminaciones invalidas o sin autorizacion.

select '--- PRUEBA 2: ausente y dueno ---' as test;

-- No se puede eliminar un tutorial que ya no pertenece a la coleccion.
do $$
begin
    perform public.fn_coleccion_quitar_item(1, 1,1);
    raise exception 'FALLO: quito word otra vez';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK ausente: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK ausente: tutorial 1 no esta en la coleccio.

-- Un usuario que no es propietario no puede eliminar tutoriales.
do $$
begin
    perform public.fn_coleccion_quitar_item(2, 1, 4);
    raise exception 'FALLO: Julio quita Unreal';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK dueno: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK dueno: solo el dueno quita items.

select items_count
from public.colecciones
where id = 1;
-- Esperado: 2.