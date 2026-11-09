--Tutorial_guardados
create table if not exists public.tutorial_guardados(
    usuario_id bigint not null,
    tutorial_id bigint not null,
    guardado_at timestamptz not null default now(),
    eliminado_at timestamptz,

    -- Foreing key
    constraint tutorial_guardados_usuarios_usario
        foreign key (usuario_id) references public.usuarios (id)
            on delete cascade,

    constraint tutorial_guardados_tutoriales_tutorial
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete cascade,

    estado text generated always as (
        -- Si no hay fecha de eliminacion -> el tutorial guardado esta activo.
        -- Si hay fecha de eliminacion -> el tutorial guardado esta eliminado.
        case when eliminado_at is null then 'activo' else 'eliminado' end
    ) stored,

    primary key (usuario_id, tutorial_id),

    -- or eliminado_at >= Debe ser igual o posterior a la fecha en que se guardo.
    constraint ck_guardados_tiempo check(eliminado_at is null or eliminado_at >= guardado_at)
);

-- Contador denormalizado para tu peril - Pattern de Youtube
alter table public.usuarios
    add column if not exists guardados_count int not null default 0
        check ( guardados_count >= 0);

insert into public.tutorial_guardados (usuario_id, tutorial_id) values
    (2, 1),
    (3, 4),
    (4, 7),
    (1, 4),
    (1, 2);