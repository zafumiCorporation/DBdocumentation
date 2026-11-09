do $$
begin
    -- coleccion_visibilidad: Indica quien puede acceder o ver una coleccion.
    create type public.coleccion_visibilidad as enum (
        'privada', -- Solo el dueno puede verla. Ej: Playlist: "Mis pruebas Word". Solo Yonatan puede abrirla.
        'no_listada', -- No aparece en busquedas ni listados publicos. Solo la ve quien tenga el enlace o conozco el id.
        'publica' -- Cualquier usuario puede verla. Puede aparecer en busquedas, perfiles y listados.
    );
exception when duplicate_object then null;
end;
$$;

do $$
begin
    -- public.coleccion_tipo : Indica que clase de coleccion es.
    create type public.coleccion_tipo as enum(
        'usuario', -- Playlist creada manualmente por un usuario. Ej: "Word + Excel" , "Cursos DevOps" , "Tutoriales favoritos"
        'ver_luego' -- Cola especial del sistema. Similar al boton: "Watch Later" de Youtube.
    );
exception when duplicate_object then null;
end;
$$;

-- public.colecciones: Almacena playlists de tutoriales.
create table if not exists public.colecciones(
    id bigint generated always as identity primary key, -- Id de la coleccion.
    dueno_id bigint not null, -- Usuario propietario de la coleccion.
    titulo varchar(120) not null, -- Nombre visible de la coleccion.
    slug varchar(80) not null, -- Identificador amigable para URL.
    visibilidad public.coleccion_visibilidad not null default 'privada', -- Indica quien puede verla.
    tipo public.coleccion_tipo not null default 'usuario', -- Indica que tipo de coleccion es.
    descripcion text, -- Resumen de la coleccion.
    items_count int not null default 0 check (items_count >= 0), -- Contador de tutoriales dentro de la coleccion.
    created_at timestamptz not null default now(), -- Fecha de la creacion.
    updated_at timestamptz not null default now(), -- Ultima modificacion.

    constraint fk_colecciones_usuarios_dueno_id
        foreign key (dueno_id) references public.usuarios(id)
        on delete cascade,

    -- La combinacion debe ser unica.
    constraint uq_coleccion_slug_dueno unique (dueno_id, slug),

    constraint ck_slug_coleccion check ( slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$')
);

create unique index if not exists uq_coleccion_ver_luego
    on public.colecciones (dueno_id)
    where tipo = 'ver_luego';

