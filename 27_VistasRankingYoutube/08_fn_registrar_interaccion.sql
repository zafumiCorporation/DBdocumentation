-- Registra una interaccion realizada por un usuario sobre un tutorial.
create or replace function public.fn_registrar_interaccion(
    p_yo bigint, -- Id del usuario que realizo la interaccion.
    p_tutorial_id bigint, -- Id del tutorial donde ocurrio la interaccion.
    p_kind public.interaccion_kind,-- Tipo de interaccion realizada.
    p_payload jsonb default '{}'::jsonb -- Informacion adicional sobre la interaccion.
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id bigint; -- Guarda el id de la interaccion recien creada.
    v_payload jsonb := coalesce(p_payload, '{}'::jsonb); --
begin
    if jsonb_typeof(v_payload) is distinct from 'object' then
        raise exception 'payload debe ser objeto JSON, no %', jsonb_typeof(v_payload);
    end if;

    -- Verifica que exista la particion correspondiente al mes actual.
    perform public.fn_asegurar_particion_interacciones(now());

    -- Registra una nueva interaccion.
    insert into public.interacciones (
        usuario_id, tutorial_id, kind, payload, ocurrio_en
    ) values (
        p_yo, p_tutorial_id, p_kind, v_payload, now()
    )
    returning id into v_id;

    return v_id; -- Devuelve el id de la interaccion creada.
end;
$$;

-- PRUEBA 1: Registrar diferentes tipos de interaccion
-- Estado Inicial: La tabla interacciones no contiene registros. Usuario 1: Shiriaru. Tutorial 1: Word
-- Accion: Registrar una impresion (impresion). Registrar una vista previa (hover_preview).
-- Registrar un click en la tarjeta (click_card). Registrar la reproduccion (click_play).
-- Resultado esperado: Se generan cuatro registros en interacciones. Cada registro conserva su
-- tipo de interaccion y payload. Los registros se almacenan en la particion del mes actual.
-- cada llamada devuelve el ID de la interaccion creada.

select '--- PRUEBA 1: impresion hover click play ---' as test;

select count(*) as n
from public.interacciones;
-- Esperado ahora: 0.

-- 1 = Shiriaru. 1 = Word.
select public.fn_registrar_interaccion(1,1, 'impresion', '{"pos":1}'::jsonb);
select public.fn_registrar_interaccion(1,1, 'hover_preview', '{}'::jsonb);
select public.fn_registrar_interaccion(1, 1, 'click_card', '{"from":"feed"}'::jsonb);
select public.fn_registrar_interaccion(1, 1, 'click_play', '{"origen":"overlay"}'::jsonb);

select kind::text, payload
from public.interacciones
where tutorial_id = 1
order by id;
-- Esperado: cuatro filas. impresion, hover_preview, click_card, click_play.

select c.relname as particion
from public.interacciones i
join pg_class c on c.oid = i.tableoid
limit 1;
-- Esperado: interacciones_202611

-- PRUEBA 2 Rechazar un payload que no se objeto JSON.
-- Estado inicial: Existen cuatro interacciones registradas en la prueba anterior.
-- La funcion recibe un payload de tipo array: [].
-- Accion: Intentar registrar una interaccion click_fork con un payload array.
-- Capturar la excepcion generada por la validacion.
-- Resultado esperado: La funcion rechazada el payload antes de insertar la interaccion.
-- Se muestra el mensaje: payload dee ser objeto JSON, no array. El total de interacciones permanece en cuatro registros.

select '--- PRUEBA 2: payload array ---'as test;

do $$
begin
    perform public.fn_registrar_interaccion(1,1,'click_fork', '[]'::jsonb);
    raise exception 'FALLO: acepto payload array';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK payload: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK payload: payload debe ser objeto JSON, no array.

select count(*) as n
from public.interacciones;
-- Esperado: 4.


