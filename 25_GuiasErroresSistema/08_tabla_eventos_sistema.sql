-- Almacena cada error que ocurre. Cada aparicion del error.
create table if not exists public.eventos_sistema(
    id bigint generated always as identity, -- Id del evento o error que ocurrio.
    usuario_id bigint not null, -- Id del usuario que sufrio el error.
    tipo_error_id bigint, -- Id del tipo de error que ocurrio.
    origen public.error_origen not null, -- Id de donde vino el error.
    aplicacion_id bigint, -- El error puede venir de una aplicacion.
    tutorial_id bigint, -- Id del tutorial donde ocurrio el error.
    ejecucion_id bigint, -- Id de ejecucion.
    titulo text, -- Titulo del error.
    cuerpo text, -- Descripcion detallada del error.
    uia_clave text, -- Identificador del control o dialogo UI.
    firma_hash text not null, -- Encripta uia+titulo+cuerpo.
    payload jsonb not null default '{}'::jsonb, -- Informacion extra del error.
    captura_pantalla boolean not null default false, -- Hay capturas asociadas al error? , ahora mismo no se permiten capturas.
    ocurrio_en timestamptz not null default now(), -- Cuando ocurrio el error.

    constraint pk_eventos_sistema primary key (id, ocurrio_en), --

    constraint fk_eventos_sistema_usuarios_usuario_id
        foreign key (usuario_id) references public.usuarios(id)
            on delete cascade,

    constraint fk_eventos_sistema_tipos_error_tipo_error_id
        foreign key (tipo_error_id) references tipos_error(id)
            on delete cascade,

    constraint fk_eventos_sistema_aplicaciones_catalogo_aplicacion_id
        foreign key (aplicacion_id) references public.aplicaciones_catalogo(id)
            on delete set null,

    constraint fk_eventos_sistema_tutoriales_tutorial_id
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete set null,

    constraint ck_eventos_payload_obj check (jsonb_typeof(payload) = 'object'),
    constraint ck_eventos_sin_captura check ( captura_pantalla = false )

-- partition -> Separa fisicamente los datos Ej: 1. Tienes una carpeta enorme llamada Eventos Dentro tienes millones de errores sin particiones 1 tabla gigante
-- 2. Con particiones la tabla se divide Eventos contiene 1.Octubre , 2 Noviembre , 3 Diciembre
-- Visualmente eventos_sistem > octubre , noviembre , diciembre
-- by range -> por rango de fechas , ocurrio_en -> campo usado.
) partition by range (ocurrio_en);

-- Particion octubre
create table if not exists public.eventos_sistema_202610
    partition of public.eventos_sistema -- Tabla hija de la tabla eventos_sistema
    -- Todo octubre > Desde 2026-10-01 hasta 2026-11-01
    for values from ('2026-10-01') to ('2026-11-01');

create table if not exists public.eventos_sistema_202611
    partition of public.eventos_sistema
    for values from ('2026-11-01') to ('2026-12-01');

-- Imagina que manana insertas 2027-02-10 Pero no existe eventos_sistema_202702
-- sin default postgres lanza error. Con default lo guarda aqui: eventos_sistema_default.
create table if not exists public.eventos_sistema_default
    partition of public.eventos_sistema default;

-- Cuando haces : insert into eventos_sistema PostgreSQL decide automaticamente Octubre -> tabla octubre
-- Noviembre -> tabla noviembre.

drop trigger if exists trg_tipos_error_count on public.eventos_sistema;
create trigger trg_tipos_error_count
after insert or delete on public.eventos_sistema
for each row execute function public.fn_tipos_error_count_sync();