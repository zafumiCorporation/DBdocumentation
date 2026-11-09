-- Decision engine para la IA del tray - Que boton mostrar
create or replace function public.fn_resumen_relaciones(p_yo bigint, p_otro bigint)
returns table(es_amigo boolean, yo_lo_sigo boolean, el_me_sigue boolean,
              solicitud_pendiente boolean, yo_lo_bloquee boolean, el_me_bloqueo boolean
)
language sql
stable
parallel safe
set search_path = ''
AS $$
    select
        --AMISTAD REAL
        exists(select 1 from public.amistades as a
            where a.seguidor_id = p_yo
            and a.seguido_id = p_otro
            and a.estado = 'accepted'
        )
        and EXISTS(select 1 from public.amistades as a
            where a.seguidor_id = p_otro
            and a.seguido_id = p_yo
            and a.estado = 'accepted'
        ) as es_amigo,

        -- YO LO SIGO SI MI FILA ESTA PENDING O ACCEPTED
        exists(select 1 from public.amistades as a
            where a.seguidor_id = p_yo
              and a.seguido_id  = p_otro
              and a.estado in ('pending', 'accepted')
        ) as yo_lo_sigo,
        exists(select 1 from public.amistades as a
            where a.seguidor_id = p_otro
            and a.seguido_id = p_yo
            and a.estado in ('pending', 'accepted')
        ) as el_me_sigue,

        -- SOLICITUD ENVIADA , ESTADO PENDING
        exists(select 1 from  public.amistades as a
            where a.seguidor_id = p_yo
            and seguido_id = p_otro
            and  a.estado = 'pending'
        )as solicitud_pendiente,

        --BLOQUEO DIRECCIONAL
        exists(select  1 from  public.amistades as a
            where a.seguidor_id = p_yo
            and a.seguido_id = p_otro
            and a.estado = 'blocked'
        ) as yo_lo_bloquee,
        exists(select 1 from public.amistades as a
            where a.seguidor_id = p_otro
            and a.seguido_id = p_yo
            and a.estado = 'blocked'
        ) as el_me_bloqueo;
$$;


select * from public.notificaciones;
select * from public.amistades;
-- Shiriaru (1) y Julio (2)
select * from public.fn_resumen_relaciones(1,2);
-- Deberia mostrar yo_lo_bloquee = true
select * from public.fn_resumen_relaciones(4, 3);
