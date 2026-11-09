do $$
begin
    create type public.notificacion_tipo as enum(
        'solicitud_amistad',
        'amistad_aceptada',
        'amistad_bloqueada',
        'amistad_rechazada'
    );
exception
    when duplicate_object then null;
end;
$$;

create table if not exists public.notificaciones(
    id bigint generated always as identity primary key,
-- usuario que recibe la notificacion
    usuario_id bigint not null,
-- Persona que provoca la accion (ejemplo: quien envia la solicitud)
    actor_id bigint not null default 0 ,
    tipo public.notificacion_tipo not null,
-- payload -> datos extra en formato JSON , payload JSONB tipo de dato en Postgres para guardar informacion en formato JSON
-- default '{}'::jsonb si no mandas nada guarda un objeto vacio {} convertio a JSONB
    payload JSONB not null default '{}'::jsonb,
    leida boolean not null default false,
    leida_at timestamptz,
    created_at timestamptz not null default now(),

    -- Reglas foreing key
    constraint fk_notificaciones_usuarios_usuario
        foreign key (usuario_id) references public.usuarios(id)
            on delete cascade,

    constraint fk_notificaciones_usuarios_actor
        foreign key (actor_id) references public.usuarios(id)
            on delete set default ,

    -- Reglas constraint
    constraint ck_notif_leida_at check (
        (leida = true and leida_at is not null) or
        (leida = false and leida_at is null)
    )
);

select * from usuarios;
select * from amistades
-- DATOS DE PRUEBA - notificaciones
-- Idempotente: si ya existe la msima notificacion, no la duplica.
insert into public.notificaciones (usuario_id, actor_id, tipo, payload, leida, leida_at, created_at)
-- SELECT PARA TOMAR LOS DATOS DE OTRA FUENTE.
select v.usuario_id , v.actor_id , v.tipo::public.notificacion_tipo, v.payload, v.leida, v.leida_at, v.created_at
-- Conjunto de filas de prueba con values.
from (values
    -- 1 <-> 2 : (1) Shiriaru envio , (2)Julio acepto
    (2, 1, 'solicitud_amistad', jsonb_build_object('amistad_id', 1), true, now() - interval '2 days 22 hours', now() - interval '3 days'),
    (1, 2, 'amistad_aceptada', jsonb_build_object('amistad_id', 1), true, now() - interval '2 days 20 hours ', now() - interval '2 days 23 hours'),
    -- 1 <-> 3 : Shiriaru envio, Sebastian acepto (ambas SIN leer)
    (3, 1, 'solicitud_amistad', jsonb_build_object('amistad_id', 3), false, null::timestamptz,                  now() - interval '2 days 12 hours'),
    (1, 3, 'amistad_aceptada',  jsonb_build_object('amistad_id', 3), false, null::timestamptz,                  now() - interval '2 days'),
    -- 1 <-> 4 : Shiriaru envio, Angela acepto
    (4, 1, 'solicitud_amistad', jsonb_build_object('amistad_id', 5), true,  now() - interval '1 day 22 hours',  now() - interval '2 days'),
    (1, 4, 'amistad_aceptada',  jsonb_build_object('amistad_id', 5), false, null::timestamptz,                  now() - interval '1 day 23 hours'),
    -- 2 -> 4 : Julio a Angela, sigue PENDING (badge de Angela)
    (4, 2, 'solicitud_amistad', jsonb_build_object('amistad_id', 7), false, null::timestamptz,                  now() - interval '6 hours'),
    -- 3 -> 2 : Sebastian a Julio, Julio la rechazo
    (2, 3, 'solicitud_amistad', jsonb_build_object('amistad_id', 8), true,  now() - interval '22 hours',        now() - interval '1 day'),
    (3, 2, 'amistad_rechazada', jsonb_build_object('amistad_id', 8), false, null::timestamptz,                  now() - interval '23 hours')
-- v (tabla temporal) y nombras las columnas ()
) as v(usuario_id, actor_id, tipo, payload, leida, leida_at, created_at)
-- Verificas que no eista ya una fila igual en notificaciones.
where not exists(
  -- Subconsulta Comparas cada fila de v contra las filas de n.
  select 1 from public.notificaciones as n
  where n.usuario_id = v.usuario_id
    and n.actor_id = v.actor_id
    and n.tipo = v.tipo::public.notificacion_tipo
    and n.payload = v.payload
);

-- Verificamos debe salir 9 filas
select n.id, n.usuario_id, n.actor_id , n.tipo , n.payload, n.leida , n.created_at
from public.notificaciones as n
order by n.usuario_id, n.created_at desc ;

-- Alter tabla Menciones 20_EngagementLikesComentariosPublicos
DO $$
begin
    alter type public.notificacion_tipo add value if not exists 'mencion_tutorial';
exception when others then null;
end;
$$;
