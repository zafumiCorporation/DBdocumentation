-- 2) ACEPTAR SOLICITUD - CREA LA AMISTAD BIDIRECCIONAL --------
create or replace function public.fn_aceptar_solicitud(p_amistad_id bigint, p_receptor_id bigint)
returns void
language plpgsql
security DEFINER
set search_path = ''
as $$
declare
    v_emisor_id bigint;
begin
    -- ACEPTA LA SOLICITUD ENTRANTE
    update public.amistades as a
    set estado = 'accepted',
        accepted_at = now()
    -- p_amistad_id SOLICITUD EXACTA
    where a.id = p_amistad_id
    -- p_receptor_id EL QUE ESTA ACEPTANDO , EL USUARIO LOGUEADO
        and a.seguido_id = p_receptor_id
        and a.estado = 'pending'
    -- EL QUE ENVIO LA SOLICITUD
    returning a.seguidor_id into v_emisor_id;

    if not found then
        raise exception
            'Solicitud % no existe para usuario %',
            p_amistad_id,
            p_receptor_id
            using errcode = 'P0002';
    end if;

    -- AMISTAD BIDIRECCIONAL
    insert into public.amistades as a (seguidor_id, seguido_id, estado, accepted_at)
    -- EL SEGUIDOR SE CONVIERTE EN EL SEGUIDO , EL SEGUIDO SE CONVIERTE EN EL SEGUIDOR
    values (p_receptor_id , v_emisor_id, 'accepted', now())
    on conflict (seguidor_id, seguido_id) do update
        set estado = 'accepted',
            accepted_at = now(),
            blocked_at = null;
end;
$$;