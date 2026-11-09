-- UNLOGGED: si Postgres se apaga, el neon muere. No WAL, no fsync.
-- Representa la sesion activa del usuario mientras ejecuta un tutorial.
-- Guarda que tutorial esta viendo, que paso tiene activo.
-- La ultima vez que el agente informo que sigue funcionando.
-- Tabla estado vivo . 1 fila = estado actual de 1 usuario.
create unlogged table if not exists public.overlay_sesion_ram(
    -- Un usuario solo puede tener una sesion activa de overlay. No puede esta ejecutando dos tutoriales interactivos al mismo tiempo.
    usuario_id bigint primary key,
    tutorial_id bigint, -- Id del tutorial que esta ejecutando ahora , aplicacion_id = null.
    aplicacion_id bigint, -- Id de la aplicacion a instalar , tutorial_id = null .
    ejecucion_id bigint, -- Id del numero de ejecucion .
    paso_id bigint, -- Id del paso actual del tutorial. Cambia conforme el usuario avanza.
    gesto_id bigint, -- Id del Gesto visual activo dentro del paso actual. Puede ser null si el paso no necesita gesto.
    started_at timestamptz not null default now(), -- Fecha de inicio del tutorial.
    last_seen_at timestamptz not null default now(), -- Ultima vez que el agente dijo sigo vivo. hearbeat cuando dejo de marcar un paso(pintar overlay neon).

    -- Si borras al usuario se borra su sesion RAM
    constraint fk_overlay_sesion_ram_usuarios_usuario_id
        foreign key (usuario_id) references public.usuarios(id)
        on delete cascade,

    -- Modo A: tutorial_id = 1 , aplicacion_id = null. Estoy viendo el tutorial "Create Sheet in word". Donde se dibuja no lo guardas aqui.
    -- Modo B: tutorial_id = null , aplicacion_id = 5 Estoy en el instalador de tu app. Estoy pintando el overlay del wizard de instalacion.
    constraint ck_overlay_un_objetivo check (
        -- Solo uno de los dos campos puede tener valor.
        num_nonnulls(tutorial_id, aplicacion_id) = 1
    )
);