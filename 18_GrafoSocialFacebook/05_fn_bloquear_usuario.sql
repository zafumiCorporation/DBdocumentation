-- 4) BLOQUEAR USUARIO - ROMPE EL GRAFO EN AMABAS DIRECCIONES (AMISTAD BIDIRECIONAL)
-- p_emisor_id EL USUARIO LOGUEADO, EL QUE EJECUTA LA ACCION DE BLOQUEAR
-- p_receptor_id EL OTRO USUARIO, EL QUE QUEDA BLOQUEADO
create  or replace function public.fn_bloquear_usuario(p_emisor_id bigint , p_receptor_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if p_emisor_id = p_receptor_id then
        raise exception 'No puedes bloquearte a ti mismo' using errcode = 'P0001';
    end if;

    --Inserta o actualiza el bloqueo (emisor -> receptor)
    insert into public.amistades as a (seguidor_id, seguido_id, estado, blocked_at)
    values (p_emisor_id , p_receptor_id , 'blocked', now())
    on conflict (seguidor_id, seguido_id) do update
        set estado = 'blocked',
            blocked_at = now(),
            accepted_at = null;

    -- BORRA LA SOLICITUD PENDIENTE
    delete from public.amistades as a
    where a.seguidor_id = p_receptor_id
        and a.seguido_id = p_emisor_id
        and a.estado = 'pending';

    update public.amistades as a
    set estado = 'blocked',
        blocked_at = now(),
        accepted_at = null
    where a.seguidor_id = p_receptor_id
        and a.seguido_id = p_emisor_id
        and a.estado = 'accepted';
end;
$$;