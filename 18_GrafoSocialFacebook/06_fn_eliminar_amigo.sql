-- 5) ELIMINAR AMIGO - ROMPE LA AMISTAD BIDIRECCIONAL
-- p_emisor_id USUARIO LOGUEADO EL QUE ELIMINA LA AMISTAD
-- P_receptor_id EL OTRO USUARIO, EL QUE ESTABA EN LA RELACION
create or replace function public.fn_eliminar_amigo(p_emisor_id bigint, p_receptor_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- VALIDACION NO SE PUEDE ELIMINAR A SI MISMO
    if p_emisor_id = p_receptor_id then
        raise exception 'No puedes elinarte a ti mismo como amigo'
            using errcode = 'P0003';
    end if;

    --BORRAR LA RELACION EN AMBAS DIRECCIONES SI ESTABA ACEPTADA
    delete from public.amistades as a
    where ((a.seguidor_id = p_emisor_id and a.seguido_id = p_receptor_id)
        OR (a.seguidor_id = p_receptor_id and a.seguido_id = p_emisor_id))
    and a.estado = 'accepted';

    --SI NO SE ENCONTRO NINGUNA AMISTAD ACEPTADA , LANZA ERROR
    if not found then
        raise exception 'No existe amistad aceptada entre % y %',
            p_emisor_id, p_receptor_id
            using errcode = 'P0004';
    end if;
end;
$$;