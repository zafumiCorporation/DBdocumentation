-- Inbox management - Pattern: RAISE NOTICE + GET DIAGNOSTICS + ANTI JOIN
--1) MARCAR UNA SOLO NOTIFICACION COMO LEIDA
create or replace function public.fn_marcar_notificacion_leida(p_notif_id bigint, p_yo bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
        update public.notificaciones as n
        set leida = true,
            leida_at = now()
        where n.id = p_notif_id
          and n.usuario_id = p_yo
          -- Garantiza la idempotencia.
          and n.leida = false;

        -- Nunca tumbamos la transaccion por idepotencia.
        -- transaccion es el conjunto de operaciones que se ejecutan juntas en la base de datos.
        -- idempotencia Significa que si ejecutas la misma accion varias veces, el resultado final es el mismo.
        -- Ejemplo: marcar como leida dos veces -> sigue estando leida , no pasa nada malo
        -- Si ya esta leida, es un no-op no un error. Es lo que hace instagram
        -- no-op no operation quiere decir que no hace nada.
        if not found then
        -- Muestra un mensaje informativo en la consola.
            raise notice 'Notificacion % ya leida o no es tuya', p_notif_id;
        end if;
end;
$$;

-- 2) Marcar todas como leida - Bulk update
create or replace function public.fn_marcar_todas_leidas(p_yo bigint)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_afectadas int;
begin
    update public.notificaciones as n
    set leida = true,
        leida_at = now()
    where n.usuario_id = p_yo
      and n.leida = false;

    -- GET DIAGNOSTICS ROW_COUNT : Devuelve cuantas filas toco el UPDATE anterior
    -- get diagnostics comando especial PL/pgSQL que obtiene informacion de la ultima operacion.
    -- row_count numero de filas que toco el ultimo update
    get diagnostics v_afectadas = row_count;
    return v_afectadas;

end;
$$;

-- 3) Contador para la campana - Usa el indice parcial where leida = false
create or replace function public.fn_contar_no_leidas(p_yo bigint)
returns bigint
language sql
stable
parallel safe
set search_path = ''
as $$
    select count(*)::bigint
    from public.notificaciones as n
    where n.usuario_id = p_yo
        and n.leida = false;
$$;

select * from notificaciones;

--Prueba 4: Notificaciones no leidas para usuario 3 , Resultado = 2
select public.fn_contar_no_leidas(3);
