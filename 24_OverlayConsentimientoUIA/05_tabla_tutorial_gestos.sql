-- Cursor fantasma: movimiento del mouse puro,  Arrastra handle.
-- Handle: Cuando redimensionas una imagen en Word te aparecen 8 puntitos. Arrastrar el hande es tomar ese puntito y estirarlo. Tu fantasma lo hace para ensenar.
-- vuelve al origen, esena frame de como debe quedar.

-- Domain es un alias con reglas. Ningun gesto de tutorial puede durar mas de 2 minutos.
do $$
begin
    create domain public.ms_positivo as int
        check ( value > 0 and value <= 120000);
exception when duplicate_object then null;
end
$$;

do $$
begin
    create type public.gesto_kind as enum(
        'click', -- El fantasma hace click en origen_x, origen_y
        'arrastre', -- Click sostenido + mover. Ej: seleccionar texto de x = 100 a x = 500. Necesita origen y destino
        'redimension', -- Caso especial de arrastre. Toma el handle de una imagen/ tabla y la estira.
        'tecla' -- No mueve mouse, pulsa tecla. Ej: Ctrl + B para negrita,
    );
end;
$$;

-- Cada paso de tu tutorial tutorial_pasos puede tener 1 gesto fantasma. Es "Que debe hacer el cursor en este paso?"
create table if not exists public.tutorial_gestos(
    id bigint generated always as identity primary key, -- Id de la fila de gesto
    tutorial_id bigint not null, -- A que tutorial pertenece el gesto
    paso_id bigint not null, -- Id del paso que hace le gesto.
    kind public.gesto_kind not null, -- Que tipo de gesto guardas, de los 4 del enum.
    origen_x int not null,-- Donde nace el cursor fantasma.
    origen_y int not null,
    destino_x int, -- Donde termina.
    destino_y int,
    trayectoria jsonb not null default '[]'::jsonb, -- Varias direcciones. No es linea recta.
    puntos_count int generated always as (jsonb_array_length(trayectoria)) stored, -- Si trayectoria tiene 3 puntos, puntos_count = 3
    duracion_ms public.ms_positivo not null default 800, -- Cuanto dura la animacion.
    volver_origen boolean not null default true, -- Estado = true fantasma regresa a origen_x/y , false = se queda en destino.
    frame_resultado public.url_http, -- Frame del resultado.
    uia_clave text, -- Anclar el gesto a un elemento Ej: si arrastras la tabla, uia_clave = 'TableGrid' para decir "Este gesto es sobre la tabla"
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    -- Si borras el tutorial se borran los gestos
    constraint fk_tutorial_gestos_tutoriales_tutorial_id
        foreign key (tutorial_id) references public.tutoriales(id)
        on delete cascade,

    -- Si borras el paso se borra su gesto
    constraint fk_tutorial_gestos_tutorial_pasos_paso_id
        foreign key (paso_id) references public.tutorial_pasos(id)
        on delete cascade,

    -- Un paso solo puede tener 1 gesto fantasma.
    constraint uq_gestos_paso unique (paso_id),
    -- Valida que trayectoria siempre sea un array JSON.
    constraint ck_trayectoria_array check ( jsonb_typeof(trayectoria) = 'array' ),
    constraint ck_drag_tiene_destino check (
        -- Si kind es arrastre o redimension
        kind not in ('arrastre', 'redimension')
        -- not -> entonces destino_x y destino_y no pueden ser null.
        or (destino_x is not null and destino_y is not null)
    )
);