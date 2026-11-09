-- Crear tabla tutorial_compartidos
create table if not exists public.tutorial_compartidos(
    id bigint generated always as identity primary key,
    tutorial_id bigint not null,
    creador_id bigint not null,

    -- Shortlink
    codigo citext not null unique
           -- char_length() Es una funcion que devuelve el numero de caracteres de un texto.
           -- between 6 and 12 Obliga a que el codigo tenga entre 6 y 12 caracteres.
           check ( char_length(codigo::TEXT) between 6 and 12),

    acceso_token uuid not null default gen_random_uuid() unique,
    expira_at timestamptz,
    clicks bigint not null default 0 check ( clicks >= 0),
    created_at timestamptz not null default now(),

    constraint ck_codigo_formato check ( codigo::text ~ '^[A-Za-z0-9_-]+$'),
    constraint ck_expira_futuro check ( expira_at is null or expira_at > created_at)
);

-- Datos. Codigo de 6 a 12 caracteres, solo letras , numeros, _ y -
insert into public.tutorial_compartidos (tutorial_id, creador_id, codigo, expira_at, clicks) values
    (1, 1, 'Sheet720', null, 3),
    (4, 2, 'Unreal5x', now() + interval '7 days', 0),
    (7, 3, 'PptDeck', now() + interval '2 days', 1),
    (9, 4, 'MixAudio', null, 0);
