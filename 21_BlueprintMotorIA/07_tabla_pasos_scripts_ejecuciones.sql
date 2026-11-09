-- Overlay + Script + Play (TODO SE CONCINA DEL LIENZO)
-- No guarda todo el tutorial, sino que guarda un paso especifico del tutorial.
-- Cada fila = un paso.
create table if not exists public.tutorial_pasos(
    id bigint generated always as identity primary key, -- Identificador unico del paso.
    tutorial_id bigint not null, -- Es el tutorial al que pertenece el paso.
    ruta_orden int not null default 1,  -- Es el numero de la ruta. Ejemplo: Ruta 1 = Camino principal , Ruta 2 = Camino alternativo
    orden int not null check(orden > 0) , -- Numero del paso.
    clave varchar(80) not null, -- Identificador tecnico. Ejemplo: abrir-word , click-insertar , pagina-blanco
    titulo_paso text not null, -- Nombre visible del paso
    rectangulo_neon jsonb,-- Guarda la informacion del rectangulo que el overlay dibujara.

    -- Foreign
    constraint fk_tutorial_pasos_tutoriales_tutorial
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete cascade,

    constraint uq_paso_ruta_orden unique (tutorial_id, ruta_orden, orden),
    constraint ck_rect_neon check (rectangulo_neon is null or rectangulo_neon ?& array['x','y','w','h'])
);

create table if not exists public.tutorial_scripts(
    id bigint generated always as identity primary key, -- Identificador unico del script
    tutorial_id bigint not null, -- Es el tutorial al que pertene el script.
    version int not null  default 1 check (version > 0), -- Es la version del script
    cuerpo_script jsonb not null default '[]'::jsonb, -- Contenido del script
    verificado boolean not null default false, -- Este campo indica si el script funciona.
    verificado_en timestamptz, -- Guarda la fecha de verificacion.
    created_at timestamptz not null default now(), -- Fecha en que se creo esa versio.

    -- foreign
    constraint fk_tutorial_scripts_tutoriales_tutorial
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete cascade,

    constraint uq_script_version unique (tutorial_id, version),
    constraint ck_script_verificado check ( verificado = false or verificado_en is not null)
);

do $$
begin
    create type public.ejecucion_estado as enum(
        'iniciado', 'en_progreso', 'completado', 'fallido', 'cancelado'
    );
exception when duplicate_object then null;
end;
$$;

create table if not exists public.tutorial_ejecuciones(
    id bigint generated always as identity primary key, -- Identificador unico de la ejecucion
    tutorial_id bigint not null, -- Tutorial que se esta ejecutando.
    script_version int not null, -- Indica que version del script se utilizo.
    usuario_id bigint not null, -- Es el usuario que esta ejecutando el tutorial.
    estado public.ejecucion_estado not null default 'iniciado', -- Guarda el estado actaul de la ejecucion.
    paso_actual int not null default 1 check (paso_actual > 0), -- Indica en que paso va el usuario.
    error_selector text, -- Guarda informacion sobre el elemento que fallo.
    created_at timestamptz not null default now(), -- Fecha y hora en que comenzo la ejecucion.
    finished_at timestamptz, -- Fecha y hora en que termino.

    -- foreign
    constraint tutorial_ejecuciones_tutoriales_tutorial
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete cascade,

    constraint tutorial_ejecuciones_usuarios_usuario
        foreign key (usuario_id) references public.usuarios(id)
            on delete cascade,

    constraint ck_ejecucion_finished check (
        (estado in ('completado','fallido','cancelado') and finished_at is not null)
        or (estado not in ('completado','fallido','cancelado') and  finished_at is null)
    )

);

-- Sin insert aqui , los pasos nacen al compilar.