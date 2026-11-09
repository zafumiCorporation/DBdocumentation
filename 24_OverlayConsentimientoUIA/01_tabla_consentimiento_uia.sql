-- Grant por alcance, no boolean suelto, Nunca famebuffer.
-- No pides un permiso gigante de "Puedo controlar tu PC? SI/NO"
-- Pides permisos pequenos y separados: 1. Te dejo mostrar el neon encima de Word?
-- 2. Te dejo mover el cursor fantasma ? , 3. Te dejo ejecutar el tutorial?
-- Nunca framebuffer: Tu app nunca graba la pantalla, nunca lee el framebuffer.
do $$
begin
    create type public.uia_alcance as enum (
        'overlay_neon', -- Permiso para dibujar tu rectangulo brillante encima de Word.
        'cursor_fantasma', -- Permiso para mostrar un cursor falso que tu dibujas.
        'instalador_wizard', -- Permiso para que el wizard guie la instalacion es el "Siguiente > Siguiente > Instalar"
        'ejecucion_tutorial' -- Permite que tu app realmente mueva el mouse y haga clic siguiendo el blueprint que creaste con fn_agregar_nodo.
    );
exception when duplicate_object then null;
end;
$$;

-- Es la hoja de permisos firmada por cada usuario : Usuario : Shiriaru , overlay_neon: SI , cursor_fantasma: SI , ejecucion_tutorial: NO
create table if not exists public.consentimiento_uia(
    usuario_id bigint not null , -- Id de que usuario son los permisos.
    alcance public.uia_alcance not null, -- Hasta donde llega el permiso
    concedido boolean not null default false,-- Si , dio permiso o no ? , Por defecto no.
    politica_version int not null default 1 check ( politica_version > 0 ), --
    captura_pantalla boolean not null default false, -- Confirmacion nunca grabas pantalla para ese alcance.
    concedido_en timestamptz, -- Cuando dijo que si ? o Acepto el permiso.
    caduca_en timestamptz, -- Cuando caduca ? Ej: "Te dejo 30 dias" . Si es null, no caduca.
    revocado_en timestamptz, -- Cuando dijo ya no te dejo ?
    created_at timestamptz not null default now(), -- Cuando se creo la fila (Permiso).
    updated_at timestamptz not null default now(), -- Cuando se modifico la fila (Permiso).

    -- Un usuario no puede tener 2 permisos iguales.
    constraint pk_consentimiento_uia_usuario_id_alcance primary key (usuario_id, alcance),

    -- Si borrar un usuario, se borran todos sus permisos.
    constraint fk_consentimiento_uia_usuarios_usuario_id
        foreign key (usuario_id) references public.usuarios(id)
            on delete cascade,

    constraint ck_consentimiento_fechas check (
        (concedido = true and concedido_en is not null and revocado_en is null)
        or (concedido = false and (revocado_en is not null or concedido_en is null))
    )
);