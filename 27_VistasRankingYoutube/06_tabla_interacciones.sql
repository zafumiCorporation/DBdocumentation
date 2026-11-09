do $$
begin
    -- interaccion_kind -> Indica que accion realizo el suaurio sobre el tutorial.
    create type public.interaccion_kind as enum(
        'impresion', -- El tutorial aparecio en pantalla. Ej: El usuario abrio el feed. El tutorial se mostro.
        'hover_preview', -- El usuario coloco el mouse encima de la tarjeta o abrio una vista previa. Mostro intere. Pero todavia no abrio el tutorial.
        'click_card', -- El usuario hizo click en la tarjeta, Feed -> Click -> abrio tutorial
        'click_play', -- El usuario presiono reproducir -> Ejemplo: Play de video , Play de tutorial interactivo.
        'click_fork' -- El usuario hizo click o copia del tutorial. Ej: Tutorial original -> Fork -> Se crea una copia Propia.
    );
exception when duplicate_object then null;
end;
$$;


-- Almacena las acciones realizadas por los usuarios. Se registran acciones : Impresion , Hover, Click , Play , Fork.
create table if not exists public.interacciones(
    id bigint generated always as identity, -- Id de la interaccionn.
    usuario_id bigint not null, -- Usuario que realizo la interacion.
    tutorial_id bigint not null, -- Tutorial sobre el cual ocurrio la interaccion.
    kind public.interaccion_kind not null, -- Tipo de interaccion.
    payload jsonb not null default '{}'::jsonb, -- Datos adicionales de la interaccion.
    ocurrio_en timestamptz not null default now(), -- Fecha y hora de la interaccion.

    constraint pk_interacciones primary key (id, ocurrio_en),

    constraint fk_interacciones_usuarios_usuario_id
        foreign key (usuario_id) references public.usuarios(id)
            on delete cascade,

    constraint fk_interacciones_tutoriales_tutorial_id
        foreign key (tutorial_id) references public.tutoriales(id)
        on delete cascade,

    constraint ck_interaccion_payload check (jsonb_typeof(payload) = 'object')

) partition by range (ocurrio_en); -- Dividir interacciones por fecha.

-- Almacena interacciones de noviembre.
create table if not exists public.interacciones_202611
    partition of public.interacciones
    for values from ('2026-11-01') to ('2026-12-01');

-- Almacena interacciones de diciembre.
create table if not exists public.interacciones_202612
    partition of public.interacciones
    for values from ('2026-12-01') to ('2027-01-01');

-- Almacena registros cuyas fechas no tienen particion especifica.
create table if not exists public.interacciones_default
    partition of public.interacciones default;
