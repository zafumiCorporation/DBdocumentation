-- fork -> Es una copia idependiente de un tutorial.
-- forks_count -> Cuantas copias (forks) tiene este tutorial?
alter table public.tutoriales
    add column if not exists forks_count int not null default 0
    check (forks_count >= 0);

-- tutorial_fork -> tipo de notificacion , Cuando alguien haga una copia de tu tutorial.
do $$
begin
    alter type public.notificacion_tipo add value if not exists 'tutorial_fork';
exception
    when duplicate_object then null;
end;
$$;


create table if not exists public.tutorial_forks(
    id bigint generated always as identity primary key, -- Id de la nueva copia idependiente del tutorial.
    tutorial_original_id bigint, -- Id del tutorial original , Ejemplo: 10.
    tutorial_copia_id bigint not null, -- Id del Tutorial creado a partir del original. Ejemplo: 25 , No es una copia del numero.
    usuario_fork_id bigint not null, -- Id del usuario que hizo la copia
    created_at timestamptz not null default now(), -- Fecha en que se creo la copia(fork)

    constraint fk_tutorial_forks_tutoriales_tutorial_original_id
        foreign key (tutorial_original_id) references public.tutoriales(id)
        on delete set null,

    constraint fk_tutorial_forks_tutoriales_tutorial_copia_id
        foreign key (tutorial_copia_id) references public.tutoriales(id)
        on delete cascade,

    constraint fk_tutorial_forks_usuarios_usuario_fork_id
        foreign key (usuario_fork_id) references public.usuarios(id)
        on delete cascade,

    constraint uq_fork_copia unique (tutorial_copia_id),
    constraint ck_fork_no_mismo check ( tutorial_copia_id is null or tutorial_original_id <> tutorial_copia_id)
);

