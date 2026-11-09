-- 3) RECHAZAR SOLICITUD
create or replace function public.fn_rechazar_solicitud(p_amistad_id bigint, p_receptor_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.amistades as a
    set estado = 'declined'
    where a.id = p_amistad_id
        and a.seguido_id = p_receptor_id
        and a.estado = 'pending';

    if not found then
        raise exception 'Solicitud % no encontrada', p_amistad_id using errcode = 'P0002';
    end if;
end;
$$;