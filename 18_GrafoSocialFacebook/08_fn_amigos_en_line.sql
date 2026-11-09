-- SOLO ONLINE - PARA SUGERENCIAS DE TUTORIALES
-- APARECEN LOS QUE ESTAN EN LINEA AHORA Y LOS QUE SE DESCONECTARON HACE HASTA 4 MINUTOS
create or replace function public.fn_amigos_en_linea(p_yo bigint)
returns table(usuario_id bigint, username varchar, handle varchar, bio text, last_seen_at timestamptz)
language sql
stable
parallel safe
set search_path = ''
as $$
    -- JOIN LATERAL TAMBIEN UNE DOS TABLAS POR CADA FILA DE A , CORRE ESTA SUBCONSULTA EN B
    -- QUE CAMPOS QUIERO MOSTRAR EN EL RESULTADO
    select u.id, u.username, u.handle, u.bio, s.last_seen_at
    from public.amistades as a
    -- INNER JOIN DEVUELVE SOLO LAS FILAS DONDE HAY COICIDENCIAS EN AMBAS TABLAS
    inner join public.usuarios as u on u.id = a.seguido_id
    join lateral(
        select sr.last_seen_at
        from public.sesiones_ram as sr
        -- LA TABLA A TIENE SU PRIMARY KEY Y LA TABLA B SU FOREING KEY UN CAMPO EN COMUN QUE LAS ENLAZA
        where sr.usuario_id = u.id
        order by sr.last_seen_at desc
        limit 1
    ) s on true
    where a.seguidor_id = p_yo
        and a.estado = 'accepted'
        and s.last_seen_at > now() - interval '5 minutes'
    order by s.last_seen_at desc;
$$;

-- DATOS DE PRUEBA: 3 estados de presencia distintos
-- REQUIRE: haber corrido ya el seed de amistades (archivo 01)
-- Julio (2): ONLINE ahora mismo
insert into public.sesiones_ram (usuario_id, last_seen_at)
values (2, now())
on conflict (usuario_id) do update set last_seen_at = excluded.last_seen_at;

-- Sebastian (3): sesion de hace 30 minutos -> cuenta como OFFLINE (umbral es 5 min)
insert into public.sesiones_ram (usuario_id, last_seen_at)
values (3, now() - interval '30 minutes')
on conflict (usuario_id)
    -- Crea una fila virtual  llamada excluded Contiene los valores que intentabas insertar y que fueron rechazados por el conflicto.
do update set last_seen_at = excluded.last_seen_at;

-- Angela (4): a proposito SIN fila -> queda como NUNCA_CONECTADO

select *
from sesiones_ram;

select * from public.amistades;
-- Verificacion: debe mostrar solo a Julio (el unico dentro de los 5 minutos)
select * from public.fn_amigos_en_linea(1);

