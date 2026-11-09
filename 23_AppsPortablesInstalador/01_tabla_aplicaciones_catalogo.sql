-- Tabla aplicaciones catalogo 1 fila = 1 aplicacion instalable.
-- Define los tipos validos de aplicacion.
-- portable -> No requiere instalacion , instalada -> Tiene instalador , runtime -> Componente del sistema.
do $$
begin
    create type public.app_tipo_paquete as enum ('portable', 'instalada', 'runtime');
exception when duplicate_object then null;
end;
$$;

create table if not exists public.aplicaciones_catalogo(
    id bigint generated always as identity primary key, -- Identificador unico de la aplicacion 1 -> VMware , 2 -> VirtualBox, 3 -> Launch4j
    slug varchar(80) not null, -- Identificador unico amigable, Ejemplo: vmware-workstation-player  , Se usa para URLs , busquedas y referencias internas.
    nombre varchar(120) not null, -- Nombre visible VMware Workstation Player.
    publisher varchar(120), -- Empresa o autor que publica el software, Ejemplo: Microsoft , Oracle, Broadcom , JetBrains, Adobe.
    version_paquete varchar(40) not null default '1', -- Es la version de la aplicacion, Ejemplo: 17, 8.6
    tipo public.app_tipo_paquete not null, -- Tipo de instalcion , Ejemplo: portable, instalda, runtime
    familia_slug varchar(80) not null, -- Familia Virtualizacion: VMware , VirtuaLBox, Hyper-V
    categoria_id bigint,
    url_descarga public.url_http,-- URL oficial de descarga.
    exe_relativo text, -- Nombre del ejecutable principal, Ejemplo: vmplayer.exe , VirtualBox.exe . Sirve para que agente sepa que programa ejecutar.
    silent_args text, -- Parametros para instalcion silenciosa, Ejemplo: /s, /silent , /verysilent , Permite instalar sin mostrar ventanas.
    ruta_plantilla text not null default '{localappdata}\AIAssistant\Portables\{handle}\{slug}\{version}', -- Es una plantilla.
    peso_recomendacion int not null default 100 check (peso_recomendacion > 0), -- Prioridad de recomendacion Ejemplo: VMWare = 10 , VirtualBox = 40 , Hyper-v = 80
    pasos_wizard jsonb not null default '[]'::jsonb, -- Guarda los pasos del asistente de instalcion. Ejemplo [{"orden":1, "etiqueta":Next}, {"orden": 2, "etiqueta": "Install"}]
    pasos_count int generated always as (jsonb_array_length(pasos_wizard)) stored, -- Cuenta automaticamente los pasos de pasos_wizard
    activa boolean not null default true, -- La aplicacion sigue disponible en el catalogo ? , true Se puede recomendar , false fu deshabilitada.
    created_at timestamptz not null default now(), -- Cuando se creo el registro Ejemplo : fecha en que se registro launch4j.
    updated_at timestamptz not null default now(), -- Cuando se modifico por ultima vez .

    constraint fk_aplicaciones_catalogo_categorias_categoria_id
        foreign key (categoria_id) references public.categorias(id)
        on update cascade on delete set null,

    constraint uq_app_catalogo_slug unique (slug),
    constraint ck_slug_app check ( slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    constraint ck_pasos_wizard_array check (jsonb_typeof(pasos_wizard) = 'array'),
    -- Si no es portable: no importa la plantilla. Si es portabla : la plantilla debe tener texto.
    constraint ck_portable_plantilla check ( tipo <> 'portable' or length(btrim(ruta_plantilla))>0)
);

insert into public.aplicaciones_catalogo(
    slug, nombre, publisher, version_paquete, tipo, familia_slug,
    categoria_id, url_descarga, exe_relativo, silent_args, peso_recomendacion
)values
     -- Si silent_args tiene /s, tu agente no necesita pintar overlay ni hacer clicks UIA. Solo ejecuta el exe con ese parametro.
     ('vmware-player', 'VMware Workstation Player', 'Broadcom', '17', 'instalada', 'virtualizacion',
     6, 'https://cdn.ejemplo.com/vmware-player.exe', 'vmplayer.exe', '/s', 10),
     -- Si --silent con dos guiones lo usan instaladores mas nuevos que vienen de linux o multiplataforma.
     ('virtualbox', 'VirtualBox', 'Oracle', '7.0', 'instalada', 'virtualizacion',
     6, null, 'VirtualBox.exe', '--silent', 40),
     -- Componente del sistema de Windows. runtime no tiene rastros.
     ('hyper-v', 'Hyper-V', 'Microsoft', '1', 'runtime', 'virtualizacion',
     6, null, null, null, 80),
     ('vmware-esxi', 'VMware ESXi', 'Broadcom', '8', 'instalada', 'virtualizacion',
     6, null, null, null, 90),
     ('notepadpp-portable', 'Notepad++', 'Don Ho', '8.6', 'portable', 'editores',
     6, 'https://cdn.ejemplo.com/notepadpp.zip', 'notepad++.exe', null, 100);