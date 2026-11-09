-- Coleccion_items: Guarda los tutoriales que pertenecen a una coleccion.
-- Es la tabla que relaciona coleccion <-> Tutorial
create table if not exists public.coleccion_items(
    id bigint generated always as identity primary key, -- Id de la relacion coleccion-tutorial
    coleccion_id bigint not null, -- Coleccion donde esta guardado el tutorial.
    tutorial_id bigint not null, -- Tutorial que pertenece a la coleccion.
    orden int not null check (orden > 0), -- Indica la posicion del tutorial dentro de la coleccion.
    agregado_por bigint not null, -- Usuario que agrego el tutorial a la coleccion.
    created_at timestamptz not null default now(), -- Fecha en que ese tutorial fue agregado a la coleccion.

    constraint fk_coleccion_items_colecciones_coleccion_id
        foreign key (coleccion_id) references public.colecciones(id)
            on delete cascade,

    constraint fk_coleccion_items_tutoriale_tutorial_id
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete cascade,

    constraint fk_coleccion_items_usuarios_agregado_por
        foreign key (agregado_por) references public.usuarios(id)
            on delete cascade,

    constraint uq_item_en_coleccion unique (coleccion_id, tutorial_id),

    -- Dentro de una coleccion solo puede existir un orden.
    -- deferrable indica Esta restriccion puede esperar.
    -- initially deferred Significa No revises el unique inmediatamente. Revisa al final de la transaccion.
    constraint uq_orden_en_coleccion unique (coleccion_id, orden)
        deferrable initially deferred
);