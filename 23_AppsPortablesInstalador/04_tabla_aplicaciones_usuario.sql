-- Inventario real de esta PC / usuario. No es el store.
DO $$
begin
    create type public.app_instalacion_estado as enum(
        'pendiente', 'descargando', 'instalando', 'instalada', 'fallida', 'desinstalada'
    );
exception when duplicate_object then null;
end;
$$;

--aplicaciones_usuario -> Una fila = una app que tiene un usuario.
create table if not exists public.aplicaciones_usuario(
    id bigint generated always as identity primary key, -- Id del registro de la aplicacion en inventario.
    usuario_id bigint not null, -- De quieen es.
    aplicacion_id bigint not null, -- Que app es.
    estado public.app_instalacion_estado not null default 'pendiente', -- En que va la instalacion.
    origen varchar(20) not null default 'tienda' -- Como supimos que la tienes , tienda = la instalo desde tu app, detectada = tu ya la tenias instalada desde antes, tu agente la vio en C:\Program Files . Es la que hace que salga el radio "ya estas usando Player".
        check ( origen in ('tienda', 'detectada')),
    ruta_instalacion text, -- Donde esta instalada ? Ej: C:\Program Files\VMware\
    exe_path text, -- El .exe para ejecutarla. Ej: vmplayer.exe
    rastros jsonb not null default '{}'::jsonb, -- Guarda todo lo que ensucio la app al instalarse para luego podr borrarlo. {"carpeta": "carpeta principal", "accesos_directos": ["escritorio.lnk", "menu inicio.lnk"] , "registro": ["HKCU\\Software\\Notepad++"]}
    error_texto text, -- Si fallo, aqui guardas por que. Ej: sin espacio en disco.
    instalada_en timestamptz, -- Cuando se instalo
    desistalada_en timestamptz, -- Cuando se borro
    ultima_ejecucion timestamptz, -- Cuando se uso por ultima vez.
    created_at timestamptz not null default now(), -- Cuando se creo este registro en la base de datos.
    updated_at timestamptz not null default now(), -- Cuando se actualizo.

    constraint fk_aplicaciones_usuario_usuarios_usuario_id
        foreign key (usuario_id) references public.usuarios(id)
            on delete cascade ,

    constraint fk_aplicaciones_usuario_aplicaciones_catalogo_aplicacion_id
        foreign key (aplicacion_id) references public.aplicaciones_catalogo(id)
            on delete restrict,

    constraint uq_app_por_usuario unique (usuario_id, aplicacion_id),
    constraint ck_rastros_obj check ( jsonb_typeof(rastros) = 'object'),
    constraint ck_instalada_ruta check (
        estado <> 'instalada'
        or ruta_instalacion is not null
        or origen = 'detectada'
    )
);