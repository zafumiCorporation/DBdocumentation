-- TABLA tags QUE TAREA EXACTA HACE DENTRO DE ESA APLICACION EJEMPLO Blueprints , Platformer, Resume , Hoja en blanco
-- SI EL USUARIO ESCRIBE blueprints el titulo "CREATE VIDEO GAME" NO CONTIENE ESA PALABRA
-- SI TIENES tags la IA busca en la tabla tags y devuelve todos los tutoriales que tenga el tag Blueprints.
-- TUS DATOS DE ENTRENAMIENTO SE AGRUPA POR TAG : TODOS LOS VIDEO QUE TIENE EL TAG : platformer VAN JUNTOS. AI LA IA ES EXPERA EN CREAR JUEGOS DE PLATAFORMA , NO SOLO EXPERTA EN UNREAL
create table if not exists tags(
    id bigint generated always as identity primary key,
-- citext  EVITA PROBLEMAS DE MAYUSCULAS/MINUSCULAS "Word" y "word" SE CONSIDERAN IGUALES , PERFECTO PARA USAR EN nombre de usuario, tags , correos.
    nombre citext not null unique,
    slug varchar(60) not null unique
        check(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    estado varchar(12) not null default 'pendiente'
-- pendiente: NACIO, UN TAG TIENE 2 USOS NO TIENE TRACCION . No sale en autocomplete
-- activo: supero el umbral (eje: 100 usos). YA SALE EN AUTOCOPLETE.
-- fusionado: FUE ABSORBIDO POR OTRO TAG (eje: 'ue5' -> 'unreal-engine-5')
        check(estado in ('pendiente', 'activo', 'fusionado')),
    usos_count bigint not null default  0 check ( usos_count >=0 ),
    es_entrenable boolean not null default false,
    fusionado_a_id bigint,
    created_at timestamptz not null default now(),
-- FECHA EN QUE EL TAG PASO A "activo"
    promovido_at timestamptz,
-- ULTIMA ACTUALIZACION DEL TAG
    actualizado_at timestamptz not null default now(),

-- RELACION RECURSIVA PERMITE QUE UN TAG APUNTE A OTRO TAG DENTRO DE LA MISMA TABLA, Ejemplo: tag ue5 puede tener fuisonado_a_id apuntando al tag unreal-Engine-5
    constraint fk_tags_fusionado
        foreign key (fusionado_a_id) references tags(id)
        on delete set null
);

alter table public.tags
alter column nombre type public.citext;

alter table public.tags
    alter column nombre set not null;

alter table public.tags
-- uq PARA INDICAR QUE ES UNA CONSTRAINT UNIQUE
    add constraint uq_tags_nombre unique (nombre);

-- TABLA N:M UN TUTORIAL PUEDE TENER MUCHOS TAGS, UN TAG PUEDE TENER MUCHOS TUTORIALES.
-- SOLO GUARDA LAS UNIONES Ej. tutorial 4 tiene tag1 y tag2
create table if not exists tutorial_tags(
-- COLUMNA QUE GUARDA EL ID DEL TUTORIAL Ej: 4= Create Video Game in Unreal Engine.
    tutorial_id bigint not null,
-- ID DEL TAG Ej: 1= beginner , 2 = 3D , 3 = BLueprints.
    tag_id      bigint not null ,
    created_at timestamptz not null default now(),
    created_by bigint not null default 0,           -- APUNTA AL USUARIO System
-- LLAVE COMPUESTA DE 2 COLUMNAS JUNTAS.
    primary key (tutorial_id, tag_id),

-- LLAVE FORANEA PARA tutorial_id
    constraint fk_tutorial_tags_tutorial
        foreign key (tutorial_id) references tutoriales(id)
        on delete cascade
        on update cascade,
-- LLAVE FORANEA PARA tag_id
    constraint fk_tutorial_tags_tags
        foreign key (tag_id) references tags(id)
        on delete cascade
        on update cascade,

-- LLAVE FORANEA PARA create_by
    constraint fk_tutorial_tags_usuario
        foreign key (created_by) references usuarios
        on delete set default
        on update cascade
);