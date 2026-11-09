-- Ticket de mencion de video. Vive 8 horas, igual que la invitacion de comunidad.
-- id, tutorial_id, actor_id y destinatario_id los escribe fn_mencionar_tutorial.
-- expira_at, leida_at y created_at los leen la badeja, abrir y purgar
create  table if not exists public.tutorial_menciones(
    id bigint generated always as identity primary key,
    tutorial_id bigint not null,
    actor_id bigint not null,
    destinatario_id bigint not null,
    created_at timestamptz not null default now(),
    expira_at timestamptz not null default now() + make_interval(hours => 8),
    leida_at timestamptz,

    -- foreign key
    constraint fk_tutorial_menciones_tutoriales_tutorial
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete cascade,

    constraint fk_tutorial_menciones_usuarios_actor
        foreign key (actor_id) references public.usuarios (id)
            on delete  cascade,

    constraint fk_tutorial_menciones_usuarios_destinatario
        foreign key (destinatario_id) references public.usuarios(id)
            on delete cascade,

    constraint ck_mencion_no_yo check ( actor_id <> destinatario_id ),
    constraint ck_mencion_ttl check (expira_at > created_at),
    constraint ck_mencion_leida check (leida_at is null or leida_at >= created_at)
);

comment on table public.tutorial_menciones is 'Mencion de un tutorial. Ticket de 8h. Al abrirla, la fila se borra.';

-- Julio (usuarios.id 2) menciona el tutorial 4 "Create Video Game in Unreal Engine" a Shiriaru (usuarios.id 1).
-- Leida_at null y expira_at dentro de 8 horas: La bandeja de Shiriaru La muestra como origen video.
insert into public.tutorial_menciones (tutorial_id, actor_id, destinatario_id)
values (4,2,1);

-- Angela (usuarios.id 4) menciona el tutorial 9 "Edit Music & Audio Mixes" a Julio (usuarios.id 2).
insert into public.tutorial_menciones (tutorial_id, actor_id, destinatario_id)
values (9,4,2);