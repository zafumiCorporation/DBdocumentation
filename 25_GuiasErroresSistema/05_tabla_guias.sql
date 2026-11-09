-- Guias de solucion para dichos errores.
create table if not exists public.guias(
    id bigint generated always as identity primary key, -- Identificado unico de la guia.
    tipo_error_id bigint not null, -- Tipo de error que resuelve esta guia.
    tutorial_id bigint, -- Si esta guia salio de algun tutorial toma valor si no salio de un tutorial es null.
    titulo text not null, -- Titulo de la guia.
    pasos jsonb not null default '[]'::jsonb, -- Pasos de como solucionar el tipo de error.
    pasos_count int generated always as (jsonb_array_length(pasos)) stored, -- Numero de pasos.
    ia_generada boolean not null default false, -- Si la IA genero esta guia o no.
    activa boolean not null default true, -- Si aun sirve o funciona.
    created_at timestamptz not null default now(), -- Cuando se creo la guia.
    updated_at timestamptz not null default now(), -- Cuando se actualizo o modifico.

    constraint fk_guias_tipos_error_tipo_error_id
        foreign key (tipo_error_id) references public.tipos_error(id)
            on delete cascade,

    constraint fk_guias_tutoriales_tutorial_id
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete set null,

    constraint uq_guia_por_tipo unique (tipo_error_id),
    constraint ck_guia_pasos_array check ( jsonb_typeof(pasos) = 'array'),
    constraint ck_guia_tiene_camion check (
        tutorial_id is not null or jsonb_array_length(pasos) > 0
    )
);
