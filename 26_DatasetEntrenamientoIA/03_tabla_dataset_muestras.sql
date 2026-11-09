-- Almacena Informacion del lote Ej: Dataset Word Noviembre , Dataset Excel Octubre , Dataset Windows Errores.
-- dataset_muestras : Almacena los ejemplos que aprendera la IA. Ej: Correccion 1, Correcion 2, Guia 1, Tutorail 1.
create table if not exists public.dataset_muestras (
    id bigint generated always as identity primary key, -- Identificador unico de la muestra.
    dataset_id bigint not null, --  Indica a que dataset pertece la muestra.
    fuente public.muestra_fuente not null, -- Indica de donde salio la muestra.
    correccion_id bigint, -- Viene de una correccion real.
    guia_id bigint, --  Viene de una guia de solucion.
    tutorial_id bigint, -- Viene de un tutorial.
    par_sft jsonb not null, -- Contiene el ejemplo entrenamiento que aprendera la IA.
    created_at timestamptz not null default now(), -- Fecha de creacion de la muestra.

    -- Apunta al id del dataset. Si borras el datase se borraran automaticamente sus muestras.
    constraint fk_dataset_muestras_dataset_entrenamiento_dataset_id
        foreign key (dataset_id) references public.dataset_entrenamiento(id)
            on delete cascade,

    -- Apunta al id de una correcion. Si borra la correccion orignal pasa a null.
    constraint fk_dataset_muestras_ia_correcciones_ruta_correccion_id
        foreign key (correccion_id) references public.ia_correciones_ruta(id)
            on delete set null,

    -- Apunta al id de una guia.
    constraint fk_dataset_muestras_guias_guia_id
        foreign key (guia_id) references public.guias(id)
            on delete set null,

    -- Apunta al id de un tutorial.
    constraint fk_dataset_muestras_tutoriales_tutorial_id
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete set null,

    -- Cuenta cuantos valores no son null.
    constraint ck_muestra_fuente check (
        (fuente = 'correccion_ruta' and correccion_id is not null and guia_id is null and tutorial_id is null)
        or (fuente = 'guia_error' and guia_id is not null and correccion_id is null and tutorial_id is null)
        or (fuente = 'tutorial' and tutorial_id is not null and correccion_id is null and guia_id is null)
    ),

    constraint ck_par_sft_obj check ( jsonb_typeof(par_sft) = 'object'),

    -- ?& existen todas estas claves.
    constraint ck_par_sft_claves check ( par_sft ?& Array['prompt', 'completion'])
);