create or replace function public.fn_recalcular_contadores(p_usuario_id bigint)
returns void
language plpgsql
set search_path = ''
as $$
declare
    -- v_lock_key BLOQUEA TODO LO QUE TENGA QUE VER CON ESTE USUARIO MIENTRAS RECALCULO SUS CONTADORES
    -- hashtext() RECIBE UN TEXTO Y DEVUELVE UN NUMERO ENTERO
    -- 'public.usuarios:'TEXTO FIJO NOMBRE DE LA TABLA , p_usuario_id CONVIERTE EL ID DEL USUARIO A TEXTO
    v_lock_key bigint := hashtext('public.usuarios:' || p_usuario_id::text)::bigint;
begin
    -- pg_advisory_xact_lock(v_lock_key); BLOQUEA AL USUARIO X PARA QUE NADIE PUEDA MODIFICAR SUS DATOS AL MISMO TIEMPO
    -- MSIMO USUARIO-> UNO ESPERA AL OTRO , USUARIOS DIFERENTES -> CADA UNO HACE CALCULO TRANQUILO EN PARALELO
    perform pg_advisory_xact_lock(v_lock_key);

    update public.usuarios as u set
        -- A CUANTOS SIGO YO
        following_count = (                                                     -- SE NECISTAN MAS CAMPOS
            select count(*)::int from public.amistades a
            where a.seguidor_id = p_usuario_id and a.estado in ('pending', 'accepted')
        ),
        -- CUANTOS ME SIGUEN
        seguidores_count = (
            select count(*)::int from public.amistades as a
            where a.seguido_id = p_usuario_id and a.estado = 'accepted'
        ),
        solicitudes_pendientes_count = (
            select count(*)::int from public.amistades as a
            where a.seguido_id = p_usuario_id and a.estado = 'pending'
        ),
        amigos_count = (
            select count(*)::int from public.amistades as a1
            where a1.seguidor_id = p_usuario_id
                and a1.estado = 'accepted'
                and exists(
                    select 1 from public.amistades as a2
                    where a2.seguidor_id = a1.seguido_id
                      and a2.seguido_id = p_usuario_id
                      and a2.estado = 'accepted'
            )
        )
    where u.id = p_usuario_id;
end;
$$;

drop function public.fn_amistades_after_change();
create or replace function public.fn_amistades_after_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_op = 'DELETE' then
        perform public.fn_recalcular_contadores(old.seguidor_id);
        perform public.fn_recalcular_contadores(old.seguido_id);
        return null;
    end if;

    if tg_op = 'UPDATE' and old.estado is not distinct from new.estado then
        return null;
    end if;

    perform public.fn_recalcular_contadores(new.seguidor_id);
    perform public.fn_recalcular_contadores(new.seguido_id);
    return null;
end;
$$;

drop trigger if exists trg_amistades_contadores on public.amistades;

create trigger trg_amistades_contadores
after insert or update or delete on public.amistades
for each row execute function public.fn_amistades_after_change();