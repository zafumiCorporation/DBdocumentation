-- Bandeja unificada video + comunidad + barra 8h  + purga
create or replace function public.fn_bandeja_menciones(p_yo bigint)
returns table(
    origen text, -- Indica de donde viene la mencion. Aqui siempre sera "video"
    item_id bigint,-- El id de la mencion.
    tutorial_id bigint, -- El tutorial que se esta mencionando
    comentario_id bigint,
    titulo text, -- Titulo del comentario comunidad.
    codigo citext, -- Codigo unico de comunidad.
    actor_id bigint, -- Usuario que hizo la mencion
    created_at timestamptz, -- Cuando se creo la mencion
    expira_at timestamptz, -- Cuando expira la mencion.
    segundos_restantes int, -- Cuantos segundos faltan para que expire.
    progreso numeric(5,4) -- Cuanto tiempo ha pasado desde que se creo.
)
language sql
stable
security definer
as $$
    -- Invitacion para ver un Video.
    -- 'video'::text -> Devuelve la palabra "video" como texto fijo para marcar el origen
    -- m.id -> El id de la mencion. m.tutorial_id -> El tutorial mencionado.
    -- null::tipo de dato -> campos que no aplican aqui (porque no es comunidad). Se devuelve como null
    -- m.actor_id -> Quien menciono, m.created_at -> Cuando se creo, m.expira_at -> Cuando expira.
    select 'video'::text, m.id, m.tutorial_id , null::bigint, null::text, null::citext,
            m.actor_id, m.created_at, m.expira_at,
            -- Calculo cuantos segundos faltan para que expire, y si ya paso, devuelve 0
            -- extrac(epoch from intervalo) -> Convierte un intervalo de tiempo en segundos.
            greatest(0, extract(epoch from (m.expira_at - now())))::int,
            -- Calcula que porcentaje del tiempo de vida ya paso, entre 0 y 1.
            -- Least(1, ...) -> asegura que no pase de 1 (100%)
            least(1, greatest(0,
                -- age(now(), m.created_at) -> cuanto tiempo ha pasado desde que se creo.
                extract(epoch from age(now(), m.created_at))
                -- Division -> segundos transcurridos / duracion total = porcentaje del tiempo que ya paso.
                -- nullif evita dividir entre 0
                -- Duracion total de la mencion (vida util).
                / nullif(extract(epoch from(m.expira_at - m.created_at)),0)
            ))::numeric(5,4) -- Formato numerico con hasta 5 digitos y 4 decimales.
    from public.tutorial_menciones m
    where m.destinatario_id = p_yo -- Solo menciones dirigidas a ti.
    and m.leida_at is null -- Solo las que aun no has leido
    and m.expira_at > now() -- solo las que todavia no han expirado

    union all

    -- Comunidad: unete a esta comunidad - tabla propia con TTL
    -- i.id -> id de la invitacion en la tabla comunidad_invitaciones
    -- c.tutorial_id -> El tutorial donde vive el comentario comunidad
    -- c.id -> El id del comentario raiz de tipo comunidad
    -- i.actor_id -> El usuario que te invito a la comunidad.
    select 'comunidad'::text, i.id, c.tutorial_id, c.id, c.titulo::text , c.codigo, i.actor_id,
           i.created_at, i.expira_at,
           greatest(0, extract(epoch from (i.expira_at - now())))::int,
           least(1, greatest(0,
               extract(epoch from age(now(), i.created_at))
               / nullif(extract(epoch from (i.expira_at - i.created_at)),0)
           ))::numeric(5,4)
    from public.comunidad_invitaciones i
    join public.tutorial_comentarios c
        on c.id = i.comentario_id
    where i.destinatario_id = p_yo -- Solo invitaciones dirigidas a ti (p_yo)
    and i.estado = 'pending' -- Solo las que estan pendientes
    and i.expira_at > now() -- Solo las que todavia no han expirado

    -- Ordena por la columna numero 8 del select -> created_at  , de mas reciente a mas antiguo.
    order by 8 desc;
$$;

-- PRUEBA 1. Bandeja de Angela. Trae el video y la comunidad. Las menciones viejas no salen.
select '--- PRUEBA 1: bandeja con video y comunidad ---' as test;

-- fn_bandeja_menciones(p_yo)
-- 4 = Angela, tabla public.usuarios, columna id.
select origen, item_id, tutorial_id, comentario_id, titulo, codigo, actor_id,
       segundos_restantes, progreso
from public.fn_bandeja_menciones(4);
-- Esperado: dos filas. La comunidad queda primero porque el 12 le renovo created_at
-- origen comunidad. comentario_id 6 = UnrealHQ. titulo "Comunidad Unreal". codigo UnrealHQ
-- tutorial_id 4 = "Create Video Game in Unreal Engine".  actor_id 2 = Julio.
-- segundos_restantes cerca de 28800. progreso cerca de 0.
-- origen video. tutorial_id 5 = "Build Level in Unreal Engine". actor_id 1 = Shiriaru.
-- comentario_id null. titulo null. codigo null.
-- La mencion vieja del seed no esta: ya caduco.

-- PRUEBA 2. Bandeja de Julio. El video caducado no aparece. La invitacion nueva si.
select '--- PRUEBA 2: la barra de 8 horas esconde lo caducado ---' as test;

-- 2 = Julio, usuarios.id.
-- El seed le dejo la mencion del tutorial 9 "Edit Music & Audio Mixes", ya caducada.
select origen, item_id, tutorial_id, comentario_id, titulo, codigo, actor_id, segundos_restantes
from public.fn_bandeja_menciones(2);
-- Esperado: una fila.
-- origen comunidad. comentario_id 7 = WordDudas. codigo WordDudas. titulo "Dudas de Word".
-- tutorial_id 1 = "Create Sheet in Word". actor_id 1 = Shiriaru
-- No aparece el tutorial 9. Esa mencion sigue en la tabla, pero expira_at ya paso.



