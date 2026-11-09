do $$
begin
    -- public.dataset_estado : Sera usado para guardar el estado de un dataset.
    create type public.dataset_estado as enum(
        'abierto', -- El dataset existe pero todavia se esta llenando con muestras. Ej: Dataset Word Noviembre : correcion 1. correccion 2. Guia 1. Todavia puedes agregar mas datos.
        'exportando', -- El dataset se esta convirtiendo al formato que necesita la IA. Estoy preparando los datos para entrenamiento.
        'entrenado', -- Este dataset ya fue consumido por el modelo.
        'fallido' -- Ocurrio un error y el proceso no termino. El dataset no pudo completarse correctamente.
    );
exception when duplicate_object then null;
end;
$$;

do $$
begin
    -- public.muestra_fuente : Indica de donde salio una muestra de entrenamiento.
    create type public.muestra_fuente as enum(
        'correccion_ruta', -- La muestra proviene de una correccion realizada por un usuario. Ej: La IA propuso: Abrir Word > Archivo . El usuario corrigio. Abrir Word > Archivo > Guardar como.
        'guia_error', -- La muestra proviene de una guia de solucion de errores. Ej: Error Hyper-V , Pasos: 1. Activar Hyper-V , 2. Reiniciar , 3. Crear maquina virtual. Fuente: guia_error.
        'tutorial' -- La muestra proviene de un tutorial. Ej: Como instalar Word , Fuente: tutorial.
    );
exception when duplicate_object then null;
end;
$$;

do $$
begin
    -- stf_par : Guarda varios campos juntos. entrada/salida que aprendera la IA.
    create type public.stf_par as (
        prompt text, -- Entrada que recibira la IA , Ej: Como activar Hyper-V?
        completion text  -- Respuesta correcta que debe aprender la IA.
    );
exception when duplicate_object then null;
end;
$$;

do $$
begin
    alter type public.notificacion_tipo add value if not exists 'dataset_listo';
exception
    when duplicate_object then null;
    when duplicate_object then null;
end;
$$;

-- dataset_entrenamiento : Informacion del lote de entrenamiento. Ej: Dataset Word Noviembre > 50 correcciones > 20 guias > 30 tutoriales.
create table if not exists public.dataset_entrenamiento(
    id bigint generated always as identity primary key, -- Id del dataset.
    slug varchar(80) not null, -- Nombre tecnico y unico del dataset.
    titulo text not null, -- Nombre visible para humanos. Ej: SFT Word Noviembre.
    estado public.dataset_estado not null default 'abierto', -- Indica la fase actual del dataset.
    creador_id bigint not null default 0, -- Usuario que creo el dataset.
    muestras_count int not null default 0 check ( muestras_count >= 0 ), -- Cantidad de muestras dentro del dataset. Ej: 10 correcciones, 5 guias , 3 tutoriales. Resultado: 18 muestras.
    notas text, -- Comentarios internos sobre el dataset. Ej: Dataset para Word 2026, Solo errores de instalcion.
    exportado_en timestamptz, -- Fecha cuando se genero el archivo de entrenamiento.
    entrenado_en timestamptz, -- Fecha cuando el modelo termino de usar el dataset.
    created_at timestamptz not null default now(), -- Fecha de creacion del registro.
    updated_at timestamptz not null default now(), -- Fecha de ultima modificacion.

    constraint fk_dataset_entrenamiento_usuarios_creador_id
        foreign key (creador_id) references public.usuarios(id)
        on delete set default,

    constraint uq_dataset_slug unique (slug),
    constraint ck_slug_dataset check ( slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    constraint ck_dataset_entrenado check (
        -- Dataset ya termino de entrenarse debe existir una fecha de entrenamiento.
        (estado = 'entrenado' and entrenado_en is not null)
        -- Todavia no termino de entrenarse la fecha debe estar vacia.
        or (estado <> 'entrenado' and entrenado_en is null)
    )
);