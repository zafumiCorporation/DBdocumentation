do $$
begin
    -- vista_origen : Indica desde donde llego la vista.
    create type public.vista_origen as enum(
        'feed', -- La vista proviene del feed principal. Ej: El usuario abre la aplicacion > ve una tarjeta en el feed > hace clic.
        'perfil', -- La vista proviene de un perfil de un usuario. Ej: Entrar al perfil de julio > Abrir uno de sus tutoriales.
        'overlay', -- La vista proviene de un tutorial interactivo.
        'busqueda', -- La vista proviene del buscador.
        'compartido' --  La vista proviene de un enlace compartido.
    );
exception when duplicate_object then null;
end;
$$;

-- tutorial_vistas -> Almacena cada vista recibida por un tutorial. Ej: Yonatan abrio Word -> 1 fila. Yonatan refresco -> otra fila. Julio abrio Word -> otra fila.
-- Funciona como historial de vistas.
create table if not exists public.tutorial_vistas (
    id bigint generated always as identity, -- Id unico de la vista.
    usuario_id bigint not null, -- Usuario que realizo la vista. Ej: Usuario que vio el tutorial.
    tutorial_id bigint not null, -- Id del tutorial que fue visualizado.
    origen public.vista_origen not null default 'feed', -- Desde donde llego la vista. Ej: feed , perfil, busqueda, overlya, compartido.
    cuenta_unica boolean not null default false, -- True = esta vista aumenta el contador , False = Esta vista no aumenta el contador.
    visto_en timestamptz not null default now(), -- Fecha y hora de la vista.

    constraint pk_tutorial_vistas primary key (id, visto_en),

    constraint fk_tutorial_vistas_usuarios_usuario_id
        foreign key (usuario_id) references public.usuarios(id)
            on delete cascade,

    constraint fk_tutorial_vistas_tutoriales_tutorial_id
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete cascade

) partition by range (visto_en); -- Divide fisicamente la tabla por rangos.

-- Contiene unicamente vistas de noviembre.
create table if not exists public.tutorial_vistas_202611
    partition of public.tutorial_vistas
    for values from ('2026-11-01') to ('2026-12-01');

-- Contiene unicamente vistas de Diciembre.
create table if not exists public.tutorial_vistas_202612
    partition of public.tutorial_vistas
    for values from ('2026-12-01') to ('2027-01-01');

-- Fechas que no tiene una particion definida terminan almacenandose aqui.
create table if not exists public.tutorial_vistas_default
    partition of public.tutorial_vistas default;
