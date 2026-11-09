-- create index if not exists Prefijo obligatorio
-- Nombre : idx_ + nombre_tabla + columna(s) + apodo (tabla y columnas que cubre).
-- on TablaSobreLaQueSeCrea SE TOMA DEL FROM DE TU CONSULTA.
-- (seguidor_id, accepted_at desc) Columnas del indice aparecen en tu where y order by.
-- amistades.estado = 'accepted' Filtro Indice parcial Si la consulta siempre filtra por una condicion fija.
create index if not exists idx_amistades_seguidor_accepted_recientes on public.amistades (seguidor_id, accepted_at desc)
where amistades.estado = 'accepted';

-- Feed de amigos recientes - Para tu panel derecho (Imagen 2)
create or replace function public.fn_ranking_amigos_recientes(p_yo bigint, p_limite int default 20)
returns table(usuario_id bigint, username varchar, handle varchar, ranking bigint, accepted_at timestamptz)
language sql
stable
parallel safe
set search_path = ''
as $$
    select
        a.seguido_id,
        u.username,
        u.handle,
        -- row_number() over() Genera un numero consecutivo(1,2,3,...) Para cada fila.
        -- EL NUMERO SE ASIGNA SEGUN EL ORDEN DE LA FECHA DE ACEPTACION, MAS RECIENTE PRIMERO
        row_number() over (order by a.accepted_at desc) as ranking,
        a.accepted_at
    from public.amistades as a
    join public.usuarios as u on u.id =  a.seguido_id
    where a.seguidor_id = p_yo
        and a.estado = 'accepted'
    order by a.accepted_at desc
    -- leas(x,y) DEVUELVE EL MENOR DE DOS VALORES
    limit least(p_limite, 100)
$$;

-- Verificacion
select * from public.fn_ranking_amigos_recientes(1 , 10);
