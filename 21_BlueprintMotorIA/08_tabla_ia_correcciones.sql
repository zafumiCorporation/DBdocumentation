-- Guarda cuando la IA propone una ruta y un usuario la corrige para ense;arle cual era el camino correcto.
create table if not exists public.ia_correciones_ruta(
    id bigint generated always as identity primary key, -- Identificador unico de la correccion.
    tutorial_id bigint not null, -- Id del tutorial donde ocurrio la correccion.
    usuario_id bigint not null default 0, -- Id del usuario que realizo la correccion.
    ruta_orden int not null default 1, -- Si un tutorial tiene variso caminos posibles, aqui se indica cual fue corregido.
    clave_origen text, -- Nodo donde ocurrio el problema, Aqui empieza la correccion.
    uia_ia text, -- Guarda lo que eligio la IA , La respuesta equivocada de la IA.
    uia_usuario text, -- Guarda lo que eligio el usuario , La respuesta correcta.
    ruta_ia text, -- Guarda el camino completo que propuso la IA
    ruta_usuario text, -- Ruta completa corregida por el usuario.
    aplicado_a_modelo boolean not null default false, -- Ya fue procesada y agregada al entrenamiento
    created_at timestamptz not null default now(),

    -- foreign
    constraint ia_correciones_ruta_tutoriales_tutorial
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete cascade,

    constraint ia_correciones_ruta_usuarios_usuario
        foreign key (usuario_id) references public.usuarios(id)
            on delete set default
);

comment on table public.ia_correciones_ruta is
    'SFT: IA eligio Formas, usuario Pagina en Blanco. Worker escucha canal ia_correccion.';