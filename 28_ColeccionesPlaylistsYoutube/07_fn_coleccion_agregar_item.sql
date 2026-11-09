-- fn_coleccion_agregar_item -> Agrega un tutorial a una coleccion (playlist).
create or replace function public.fn_coleccion_agregar_item(
    p_yo bigint, -- Id del usuario que intenta agregar el tutorial a la coleccion.
    p_coleccion_id bigint, -- Id del la coleccion donde se agregara el tutorial.
    p_tutorial_id bigint -- Id del tutorial que se agregara.
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_dueno bigint; -- Guarda el id del dueno de la coleccion.
    v_orden int; --  Almacenara la posicion que tendra el nuevo tutorial dentro de la coleccion.
begin
    -- Obtiene el dueno de la coleccion.
    select dueno_id into v_dueno
    from public.colecciones
    where id = p_coleccion_id;

    if v_dueno is null then
        raise exception 'coleccion % no existe', p_coleccion_id;
    end if;

    -- El usuario que intenta agregar es dueno de la coleccion?
    if v_dueno is distinct from p_yo then
        raise exception 'solo el dueno agrega itemes';
    end if;

    -- If no existe este tutorial.
    if not exists(select 1 from public.tutoriales where id = p_tutorial_id) then
        raise exception 'tutorial % no existe', p_tutorial_id;
    end if;

    select coalesce(max(orden), 0) + 1 into v_orden
    from public.coleccion_items
    where coleccion_id = p_coleccion_id;

    -- Agregar un tutorial a la playlist.
    insert into public.coleccion_items(
        coleccion_id, tutorial_id, orden, agregado_por
    ) values (
        p_coleccion_id, p_tutorial_id, v_orden, p_yo
    )
    -- unique(coleccion_id , tutorial_id)
    on conflict on constraint uq_item_en_coleccion do nothing;

    return (
        select items_count from public.colecciones where id = p_coleccion_id
    );
end;
$$;

-- PRUEBA 1: Agregar varios tutoriales a una coleccion.
-- Objetivo: Comprobar que fn_coleccion_agregar_item permita agregar tutoriales auna coleccion y
-- asigne automaticamente su posicion.
-- Estado inicial: Usuario 1: Shiriaru. Coleccion 1: Word + Excel. La coleccion no contiene tutoriales.
-- items_count comienza en cero.
-- Accion: Agregar el tutorial 1: Create Sheet in Word.
-- Agregar el tutorial 2: Design Resume in Word. Agregar el tutorial 4: Create Video Game in Unreal Engine.
-- Consultar los elementos registrados y su orden.

select '--- PRUEBA 1: alta de items ---' as test;

select items_count
from public.colecciones
where id = 1;
-- Esperado ahora: 0.
-- 1 = playList "Word + Excel".

-- 1 = Shiriaru. 1 = su playlist.
-- 1 = "Create sheet in Word." 2 = "Design Resume in Word".
-- 4 = "Create Video Game in Unreal Engine".
select public.fn_coleccion_agregar_item(1,1,1);
-- Esperado: 1.

select public.fn_coleccion_agregar_item(1,1,2);
-- Esperado: 2.

select public.fn_coleccion_agregar_item(1, 1, 4);
-- Esperado: 3.

select tutorial_id, orden, agregado_por
from public.coleccion_items
where coleccion_id = 1
order by orden;
-- Esperado: (1,1,1) , (2,2,1), (4,3,1).

-- PRUEBA 2: Evitar tutoriales duplicados y rechazar tutoriales inexistentes.
-- Objetivo: Comprobar que una coleccion no permita agregar dos veces el mismo tutorial y que
-- se rechacen los indentificadores inexistentes.
-- Estado inicial: La coleccion 1 contiene tres tutoriales.
-- El tutorial 1 ya esta registrado en la coleccion. Consultar cuantas veces aparece en la coleccion
-- Intentar agregar el tutorial 999, que no existe. Capturar la excepcion generada por la validacion.

select '--- PRUEBA 2: duplciado y ausente ---' as test;

select public.fn_coleccion_agregar_item(1, 1, 1) as otra_vez;
-- Esperado: 3. on conflict do nothing. items_count no sube.

select count(*) as filas
from public.coleccion_items
where coleccion_id = 1
    and tutorial_id = 1;
-- EsperadoL 1.

do $$
begin
    perform public.fn_coleccion_agregar_item(1, 1, 999);
    raise exception 'FALLO: acepto tutorial 999';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK ausente: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK ausente: tutorial 999 no existe.

-- PRUEBA 3: Permitir que unicamente el propietario agregue tutoriales.
-- Objetivo: Comprobar que un usuario no pueda modificar colecciones ajenas,
-- pero si pueda agregar tutoriales a sus propias colecciones.
-- Estado inicial: Usuario 1: Shiriaru. Usuario 2: Julio. La coleccion 1 pertenece a Shiriaru.
-- Julio tiene su propia coleccion de tipo ver_luego.
-- Accion: Intentar que Julio agregue Word a la coleccion de Shiriaru.
-- Capturar la excepcion generada por la validacion del propietario.
-- Agregar Unreal a la coleccion ver_luego de Julio. Consultar el contador de elementos de su coleccion.

select '--- PRUEBA 3: solo el dueno ---' as test;

-- 2 = Julio. 1 = playlist de Shiriaru. 1 = Word.
do $$
begin
    perform public.fn_coleccion_agregar_item(2, 1,1 );
    raise exception 'FALLO: Julio agrego en la de Shiriaru';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK dueno: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK dueno: solo el dueno agrega itemes.

-- Ver luego de Julio.
select public.fn_coleccion_agregar_item(
    2,
    (select id from public.colecciones where dueno_id = 2 and tipo = 'ver_luego'),
    4
);
-- Esperado: .

select items_count
from public.colecciones
where dueno_id = 2
    and tipo = 'ver_luego';
-- Esperado: 1. tutorial 4.
