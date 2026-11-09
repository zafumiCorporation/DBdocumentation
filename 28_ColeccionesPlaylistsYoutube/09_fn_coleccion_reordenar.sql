-- Cambia el orden de los tutoriales dentro de una coleccion.
create or replace function public.fn_coleccion_reordenar(
    p_yo bigint, -- Id del usuario que intenta reordenar la playlist.
    p_coleccion_id bigint, -- Id de la coleccion que sera reordenada.
    p_tutorial_ids bigint[] -- Arreglo con el nuevo orden de los tutoriales. Ej: ARRAY[6,3,1] . Tutorial 6 sera posicion 1. Tutorial 3 sera posicion 2 , Tutorial 1 sera posicion 3.
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_dueno bigint; -- Almacenara el id del dueno de la coleccion.
    v_n int; -- Almacenara cuantos tutoriales tiene actualmente la coleccion.
begin
    -- Obtiene dueno de la coleccion.
    select dueno_id into v_dueno
    from public.colecciones
    where id = p_coleccion_id;

    -- Verifica que quien reordena sea el dueno.
    if v_dueno is distinct from p_yo then
        raise exception 'solo el dueno reordena';
    end if;

    -- cardinality -> Devuelve el numero de elementos del array.
    if p_tutorial_ids is null or cardinality(p_tutorial_ids) = 0 then
        raise exception 'lista de orden vacia';
    end if;

    -- Cuenta cuantos tutoriales tiene actualmente la coleccion.
    select count(*)::int into v_n
    from public.coleccion_items
    where coleccion_id = p_coleccion_id;

    -- Verifica que el array traiga exactamente los tutoriales(items) de la coleccion.
    if v_n is distinct from cardinality(p_tutorial_ids) then
        raise exception 'el array debe tener exactamente los  % items', v_n;
    end if;


    if exists(
        select 1
        -- unnest() -> convierte un array en filas Ej: Array[6,3,1] , Resultado: 6, 3, 1
        -- as u(id)-> Le pone nombre a la columna generada. Resultado: u.i: 6,3,1
        from unnest(p_tutorial_ids) as u(id)
        group by u.id
        having count(*) > 1 -- Busca ids repetidos > 1.
    )then
        raise exception 'tutorial repetido en el array de orden';
    end if;

    update public.coleccion_items as ci
    set orden = u.ord::int -- Asigna el nuevo orden
    -- Genera dos columnas , Resultado tutorial_id | ord
    from unnest(p_tutorial_ids) with ordinality as u(tutorial_id, ord)
    where ci.coleccion_id = p_coleccion_id
        and ci.tutorial_id = u.tutorial_id;

    if not found then
        raise exception 'ningun item coincidio con el array';
    end if;

    return v_n; -- Devuelve cuantos tutoriales tiene la coleccion.
end;
$$;

-- PRUEBA 1: Reordenar los tutoriales de una coleccion. Contiene tres tutoriales.
-- tutorial_id = 1 ocupa la posicion 1.
-- tutorial_id = 2 ocupa la posicion 2.
-- tutorial_id = 4 ocupa la posicion 3.
-- Accion: Enviar array[4,1,2] para establecer el nuevo orden.

select '--- PRUEBA 1: reordenar ---' as test;

select tutorial_id
from public.coleccion_items
where coleccion_id = 1
order by orden;
-- Esperado ahora: 1, 2, 4.

-- 1 = Shiriaru. 1 = "Word + Excel".
-- ARRAY[4,1,2] = Unreal, Word, Resume.
select public.fn_coleccion_reordenar(1, 1, array[4, 1, 2]::bigint[]);
-- Esperado: 3.

select tutorial_id, orden
from public.coleccion_items
where coleccion_id = 1
order by orden;
-- Esperado: La funcion devuelve 3. No se crean ni eliminan tutoriales.
-- tutorial_id = 4 ocupa la posicion 1. tutorial_id = 1 ocupa la posicion 2.
-- tutorial_id = 2 ocupa la posicion 3.

-- PRUEBA 2: Rechazar arrays con informacion invalida.
select '--- PRUEBA 2: array invalido ---' as test;

-- Que el array contenga exactamente la cantidad de tutoriales existentes.
do $$
begin
    perform public.fn_coleccion_reordenar(1, 1,array[4, 1]::bigint[]);
    raise exception 'FALLO: acepto dos de tres';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK largo: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK largo: el array debe tener exactamente los 3 items.

-- Que no existan tutoriales repetidos.
do $$
begin
    perform public.fn_coleccion_reordenar(1, 1, array[4, 1, 4]::bigint[]);
    raise exception 'FALLO: acepto repetido';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK repetido: %', sqlerrm;
end;
$$;
-- Esperado en Messages: Ok repetido: tutorial repetido en el array de orden.


-- Que unicamente el propietario pueda reordenar la coleccion.
do $$
begin
    perform public.fn_coleccion_reordenar(2, 1, array[4, 1, 2]::bigint[]);
    raise exception 'FALL: Julio reordeno';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK dueno: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK dueno: solo el dueno reordena.

select tutorial_id
from public.coleccion_items
where coleccion_id = 1
order by orden;
-- Esperado: siguen en 4, 1, 2.