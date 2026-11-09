-- Serve de radios, no inventario. Impresion de anuncio.
-- Lista de apps que le recomiendas instalar en ese momento. Le dices cual conviene mas y por que.
create table if not exists public.recomendaciones_instalacion(
    id bigint generated always as identity primary key, -- Id de la recomendacion
    usuario_id bigint not null, -- A que usuario se le muestra. Ej: Shiriaru = 1.
    familia_slug varchar(80) not null, -- De que grupo son las opciones.
    aplicacion_id bigint not null, -- Que aplicacion es esta opcion. Ej: esta fila es VMware Player.
    tutorial_id bigint, -- Si esta recomendacion se genero mientras veia un tutorial, aqui guardas que tutorial era.
    rango int not null check (rango > 0), -- En que orden las muestras. 1 = primera, 2 = segunda.
    motivo text not null, -- El texto que le explicas al usuario de por que esa opcion.
    es_sugerida boolean not null default false, -- Cual opcion viene marcada por defecto como la mejor.
    pasos_overlay jsonb, -- Los pasos de instalacion personalizado para esta recomendacion.
    created_at timestamptz not null default now(), -- Cuando se creo esta recomendacion .

    constraint fk_recomendaciones_instalacion_usuarios_usuario_id
        foreign key (usuario_id) references public.usuarios(id)
            on delete cascade,

    constraint fk_recomendaciones_instalacion_aplicaciones_catalogo_aplicacion
        foreign key (aplicacion_id) references public.aplicaciones_catalogo(id)
            on delete cascade,

    constraint fk_recomendaciones_instalacion_tutoriales_tutorial_id
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete set null,

    constraint uq_reco_lote unique (usuario_id, familia_slug, aplicacion_id),

    constraint ck_overlay_array check (
        pasos_overlay is null or jsonb_typeof(pasos_overlay) = 'array'
    )
);