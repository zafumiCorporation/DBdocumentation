do $$
begin
    create type public.error_origen as enum (
        'overlay_tutorial', -- Error causado por tu tutorial interactivo. Ej: Ha click en "Insertar" > Pero el boton ya no existe.
        'overlay_instalador', -- Error de tu wizard de instalacion. Ej: Haz click en Siguiente > pero el boton Siguiente ya no aparece.
        'aplicacion',-- Error que lanzado por software externo. Ej: Fall Guys, Word, Photoshop > Mensaje : Missing files.
        'sistema' -- Error de Windows o Sistema Operativo. BSOD, Hypervisor bloqueado , Hora incorrecta, Error de drivers.
    );
exception when duplicate_object then null;
end;
$$;

do $$
begin
    create type public.error_gravedad as enum (
        'info', -- Informatiov. "Hyper-V ya esta instalado". No bloquea nada. Azul.
        'warning', -- Hay un problema pequeno. El reloj del sistema esta mal. Todavia funciona Pero podria causar problemas. Amarillo.
        'error', -- Ya hay una falla real. Fall Guys no inicia o La VM de Hyper-V no arranca. Aqui ya no puedes continuar. Rojo
        'critico' -- El sistema esta muy danado. BSOD o Windows no arranca o Hypervisor totalmente bloqueado. gris.
    );
exception when duplicate_object then null;
end;
$$;

-- Objetivo: Crear el catalogo central de tipos de errores conocidos por la plataforma.
-- Este catalogo permite clasificar y reconocer errores procedentes de:
-- 1. El motor de tutoriales interactivos, 2. El asistente de instalacion. 3. Aplicaciones externas.
-- 4. Windows y el sistema operativo.
create table if not exists public.tipos_error(
    id bigint generated always as identity primary key, -- Id del tipo de error.
    slug varchar (80) not null, -- Nombre unico del error.
    origen public.error_origen not null, -- De donde viene el error.
    gravedad public.error_gravedad not null default 'error', -- Que tan grave es el error.
    aplicacion_id bigint, -- Id de la aplicacion a la que pertenece el error.
    titulo_patron text not null, -- El titulo esperado del error. Ej: Misisng Files
    cuerpo_patron text, -- Texto interno dle mensaje. Ej: "Faltan archvios necesarios...".
    uia_clave text, -- Identificador UIA del dialogo. Ej: HyperV.ErrorDialog, FallGuys.MissingFIles.
    firma_hash text, -- Huella unica del error.
    veces_visto int not null default 0 check (veces_visto >= 0), -- Contador. cuantas veces se ha visto este error en todos los usuarios.
    activa boolean not null default true, -- Indica si el error sigue siendo valido.
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint fk_tipos_error_aplicaciones_catalogo_aplicacion_id
        foreign key (aplicacion_id) references aplicaciones_catalogo(id)
            on delete set null,

    constraint uq_tipos_error_slug unique (slug),
    constraint ck_slug_error check ( slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$')
);

do $$
begin
    alter type public.notificacion_tipo add value if not exists 'error_sistema';
exception
    when duplicate_object then null;
    when undefined_object then null;
end;
$$;

-- Prueba 1 Comprobar el catalogo vacio.
-- Objetivo: Comprobar cuantos tipos de error existen antes de cargar los registros.
select '--- Prueba 1 Catalogo vacio ---' as test;

select count(*) as tipos
from public.tipos_error;
-- Esperado ahora: 0.

-- Carga Inicial: Cuatro errores conocidos.
-- Objetivo: Registrar cuatro patrones iniciales para probar la clasificacion y el reconocimiento de errores.

insert into public.tipos_error(
    slug, origen, gravedad, aplicacion_id,
    titulo_patron, cuerpo_patron, uia_clave, firma_hash
)
select
    v.slug,
    v.origen::public.error_origen,
    v.gravedad::public.error_gravedad,
    v.aplicacion_id,
    v.titulo,
    v.cuerpo,
    v.uia,
    encode(
        public.digest(
            convert_to(
                lower(public.immutable_unaccent(
                    coalesce(v.uia, '') || '|' ||
                    coalesce(v.titulo, '') || '|' ||
                    coalesce(v.cuerpo, '')
                )),
                'UTF8'
            ),
            'sha256'
        ),
        'hex'
    )
from (
    values (
                'hyperv-hypervisor-bloqueado',
                'sistema',
                'critico',
                (select id from public.aplicaciones_catalogo where slug = 'hyper-v'),
                'Hypervisor bloqueado',
                'No se pudo iniciar Hyper-V',
                'HyperV.ErrorDialog'
           ),
            (
                'notepad-missing-files',
                'aplicacion',
                'error',
                (select id from public.aplicaciones_catalogo where slug = 'notepadpp-portable'),
                'Missing files',
                'Faltan archivos necesarios',
                'Notepad.MissingFiles'
            ),
            (
                'reloj-sistema',
                'sistema',
                'warning',
                null::bigint,
                'Reloj del sistema incorrecto',
                'La hora de Windows no coincide',
                'Windows.Clock'
           ),
           (
                'overlay-boton-ausente',
                'overlay_tutorial',
                'error',
                null::bigint,
                'El boton Insertar ya no existe',
                'El control Insertar no esta en la cinta',
                'Word.Insertar'
           )
) as v(slug, origen, gravedad, aplicacion_id, titulo, cuerpo, uia);

select slug, origen, gravedad, veces_visto, activa, length(firma_hash) as firma
from public.tipos_error
order by slug;
-- Esperado: cuatro filas. veces_visto 0. activa true. firma 64.
-- hyperv-hypervisor-bloqueado, sistema, critico, aplicacion hyper-v.
-- notepad-missing-files, aplicacion, error, aplicacion notepadpp-portable.
-- reloj-sistema, sistema, warning, sin aplicacion.
-- overlay-boton-ausente, overlay_tutorial, error, sin aplicacion. Este se queda sin guia.