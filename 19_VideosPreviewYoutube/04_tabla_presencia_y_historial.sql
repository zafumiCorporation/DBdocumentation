-- Presencia Activa
create table if not exists public.presencia_activa(
    usuario_id bigint not null ,
    tutorial_id bigint not null,
    paso_actual smallint check (paso_actual > 0),
    estado_actividad text not null default 'viendo'
                     check ( estado_actividad in ('viendo', 'ejecutando', 'pausado', 'completado')),
    -- Fecha y hora de inicio de la activida
    started_at timestamptz not null default now(),
    -- Ultima vez que se detecto actividad del usuario en ese tutorial
    last_seen_at timestamptz not null default now(),
    -- {titulo , preview_url, paso_titulo}
    snapshot jsonb not null default '{}'::jsonb,

    -- Primary key
    constraint pk_presencia_activa_usuarios_usuario
        primary key (usuario_id),

    -- foreing key
    constraint fk_presencia_activa_usuarios_usuario
        foreign key (usuario_id) references public.usuarios(id)
                on delete cascade,

    constraint presencia_activa_usuarios_turoial
        foreign key (tutorial_id) references public.tutoriales(id) on delete set null,

    constraint ck_presence_tiempo check ( last_seen_at >= started_at )
);

-- Datos. Last_seen_at dentro de los ultimos 2 minutos para que el feed de Shiriaru los vea.
insert into public.presencia_activa (
    usuario_id, tutorial_id, paso_actual, estado_actividad, started_at, last_seen_at, snapshot
) values
    (2, 4, 2, 'viendo', now() - interval '5 minutes', now(),
     '{"titulo":"Create Video Game in Unreal Engine","preview":null,"paso":2}'::jsonb),
    (3, 7, 1, 'ejecutando', now() - interval '3 minutes', now(),
     '{"titulo":"Create Presentation in PowerPoint","preview":null,"paso":1}'::jsonb),
    (4, 9, 4, 'pausado', now() - interval '8 minutes', now() - interval '30 seconds',
     '{"titulo":"Edit Music & Audio Mixes","preview":null,"paso":4}'::jsonb);

create table if not exists public.historial_visualizaciones(
    id bigint generated always as identity primary key,
    usuario_id bigint not null,
    tutorial_id bigint not null,
    paso_max_alcanzado smallint default 1 check ( paso_max_alcanzado > 0),
    completado boolean not null default false,
    -- Fecha y hora de la ultima vez que el usuario interactuo con ese tutorial.
    ultima_vez_en timestamptz not null default now(),

    --foreing key
    constraint historial_visualizaciones_usuarios_usuario
        foreign key (usuario_id) references public.usuarios(id)
            on delete cascade,

    constraint historial_visualizaciones_tutoriales_tutorial
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete cascade,

    constraint uq_historial_usuario_tutorial unique (usuario_id, tutorial_id)
);

insert into public.historial_visualizaciones (
    usuario_id, tutorial_id, paso_max_alcanzado, completado, ultima_vez_en
) values
    (1, 1, 3, true, now() - interval '1 day'),
    (1, 4, 1, false, now() - interval '2 hours'),
    (2, 4, 2, false, now()),
    (2, 1, 5, true, now() - interval '3 days'),
    (3, 7, 1, false, now()),
    (4, 9, 4, false, now() - interval '30 seconds');
