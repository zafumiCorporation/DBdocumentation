-- Full sidebar con Online , offline y Nunca conectados
-- p_yo id del usuario que esta logueado.
create or replace  function public.fn_lista_amigos_con_estado_completo(p_yo bigint)
returns table(usuario_id bigint, username varchar, handle varchar, bio text, last_seen_at timestamptz, estado text)
language sql
stable
parallel safe
set search_path = ''
as $$
    select f.usuario_id, f.username, f.handle, f.bio, f.last_seen_at, f.estado
    -- subquery una mini-tabla temporal llamada f. el select decide que columnas mostrar de la mini-tabla
    from (
        SELECT u.id as usuario_id,
               u.username, u.handle, u.bio,
               coalesce(u.verified, false) as verified,
               sr.last_seen_at,
               -- Clasifica al usuario
               case
                   -- Si se conecto hace menos de 5 minutos
                   when sr.last_seen_at > now () - INTERVAL '5 minutes' THEN 'online'
                   -- Si nunca se conecto = null
                   when sr.last_seen_at is null then 'nunca_conectado'
                   -- Si se conecto hace mas de 5 minutos
                   ELSE 'offline'
                END AS estado
        from public.amistades as a
        -- Une amistades con usuarios  solo amigos activos.
        inner join public.usuarios as u
          on u.id = a.seguido_id
         and u.activo is not false
        -- LEFT JOIN TODAS LAS FILAS DE LA TABLA IZQUIERDA, Y SI NO HAY COICIDENCIA EN LA DERECHA, RELLENA CON NULL.
        left join public.sesiones_ram as sr
          on sr.usuario_id = u.id
        where a.seguidor_id = p_yo
          and a.estado = 'accepted'
        -- Asegura que la amistad sea mutua u.id = a.seguido_id
          and exists (
            select 1
            from public.amistades as vuelta
            where vuelta.seguidor_id = a.seguido_id
              and vuelta.seguido_id = p_yo
              and vuelta.estado = 'accepted'
          )
    )as f
    order by
        case f.estado
            when 'online' then 0
            when 'offline' then 1
            else 2
        end,
        f.last_seen_at desc nulls last,
        f.username;
$$;

-- Verificacion: debe mostrar a Julio = online , Sebastian = offline , Angela = nunca_conectado
select * from public.fn_lista_amigos_con_estado_completo(1);