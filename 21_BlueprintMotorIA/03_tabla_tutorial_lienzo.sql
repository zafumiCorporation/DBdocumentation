-- Lienzo (1 fila = 1 Blueprint del tutorial)
-- Lienzo como el "mapa" o blueprint del tutorial. Guarda todo el tutorial como JSON
create table if not exists public.tutorial_lienzo (
    tutorial_id bigint primary key, -- Id del tutorial
    editor_id bigint not null, -- Id del usuario que esta editando o creando el tutorial.
    nodos jsonb not null default '[]'::jsonb, -- JSON con todos los nodos del tutorial.
    rutas jsonb not null default '[]'::jsonb, -- JSON con todas la rutas (conexiones) entre nodos.
    nodos_count int generated always as (jsonb_array_length(nodos)) stored,
    rutas_count int generated always as (jsonb_array_length(rutas)) stored,
    updated_at timestamptz not null default now(), -- Fecha y hora de la ultima actualizacion del lienzo.

    constraint fk_tutorial_lienzo_tutoriales_tutorial
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete cascade,

    constraint fk_tutorial_lienzo_usuarios_editor
        foreign key (editor_id) references  public.usuarios(id) on delete restrict,

    constraint ck_nodos_array check (
        jsonb_typeof(nodos) = 'array'
    ),

    constraint ck_rutas_array check (
        jsonb_typeof(rutas) = 'array'
    )
);
comment on table public.tutorial_lienzo is
    'Blueprint publicado. 1 JSON de nodos + 1 JSON de rutas por tutorial.';

-- Borrador RAM (tu "antes de apagar guarda") , unlogged opcional
create table if not exists public.lienzo_borrador_ram(
    tutorial_id bigint primary key,
    editor_id bigint not null,
    nodos jsonb not null default '[]'::jsonb,
    rutas jsonb not null default '[]'::jsonb,
    saved_at timestamptz not null default now()
);

comment on table public.lienzo_borrador_ram is
    'UNLOGGED: draft del editor. Se borra al reiniciar Postgres.';
-- Sin seed aqui: lienzo se arma con funciones (archivo 13).