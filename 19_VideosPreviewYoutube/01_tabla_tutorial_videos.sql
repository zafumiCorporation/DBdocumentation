do $$
begin
   create type public.video_tipo as enum('preview', 'resultado_final');
exception
when duplicate_object then null;
end
$$;

drop type if exists public.video_estado;

do $$
begin
    create type public.video_estado as enum('pending', 'processing', 'ready', 'failed');
exception
when duplicate_object then null ;
end;
$$;

do $$
begin
    -- Es como un alias de un tipo existente, pero con reglas adicionales
    create domain public.url_http as text
        -- value dato que se esta Insertando
        -- ~* significa comparar con una expresion regular
        -- https? Debe empezar con http y opcionalmente la s (por eso el ?)
        -- Acepta http:// o https://
        -- [^\s] Cualquier caracter que no sea espacio
        -- ^ Dentro de los corchetes significa "negacion"
        -- \s Significa "espacio en blanco" (espacios, tabs, saltos de linea)
        check ( VALUE ~* '^https?://[^\s]+$');
exception when duplicate_object then null;
end
$$;

create table if not exists public.tutorial_videos(
    id bigint generated always as identity primary key,
    tutorial_id bigint not null,
    tipo public.video_tipo not null default 'preview',
    estado public.video_estado not null default 'pending',
    resolucion varchar(10) not null default '720p'
               check ( resolucion in ('360p', '480p', '720p', '1080p')),
    --url_cdn Direccion web donde estara disponible el video. (enlace para compartir o reproducir el video)
    url_cdn public.url_http,
    duracion_seg int check ( duracion_seg between 1 and 3600),
    es_principal boolean not null default false,
    -- generated always as(...) Significa que el valor se calcula automaticamente a partir de otra columna(resolucion)
    -- resolucion in('720p', '1080p') Devuelve true o false
    -- stored El resultado calculado se guarda fisicamente en la tabla.
    es_hd boolean generated always as (resolucion in('720p', '1080p')) stored,
    -- uuid Identificador unico universal
    -- default gen_random_uuid() Si no le das un valor , Postgres genera uno automaticamente.
    upload_token uuid not null default gen_random_uuid(),
    token_expires_at timestamptz not null default now() + interval '1 hour',
    created_at timestamptz not null default now(),
    ready_at timestamptz,

    -- Foreing Key
    constraint fk_tutorial_videos_tutoriales_id
            foreign key (tutorial_id) references public.tutoriales(id)
                on delete cascade
                on update cascade,

    constraint ck_ready check (
            -- Si el estado es ready debe existir una url_cdn y una fecha de listo ready_at
            (estado = 'ready' and url_cdn is not null and ready_at is not null)
            -- Si el estado es distinto de ready , entonces ready_at debe estar vacio (null)
            or (estado <> 'ready' and ready_at is null)
    ),
    -- Si un video es marcado como principal entonces debe estar en estado 'ready'
    constraint ck_principal_ready check ( not es_principal or estado = 'ready'),
    -- No puede expirar antes de ser creado.
    constraint ck_token_vigencia check (token_expires_at > created_at),
    -- tutorial_id + tipo + resolucion
    constraint uq_video_calidad unique (tutorial_id, tipo, resolucion),
    constraint uq_video_upload_token unique (upload_token)
);

insert into public.tutorial_videos(
    tutorial_id, tipo, estado, resolucion, url_cdn, duracion_seg,
    es_principal, created_at, ready_at, token_expires_at
) values
    -- Shiriaru, tutorial 1, preview 720p listo y principal (Varias versiones)
    (1, 'preview', 'ready', '720p', 'https://cdn.ejemplo.com/tutoriales/1/preview-720p.mp4', 180,
    true, now() - interval '2days' , now() - interval '2 days' + interval '5 minutes', now() + interval '1 hour'),
    -- Mismo tutorial, preview 1080p todavia en proceso
    (1, 'preview', 'processing', '1080p',
     null, null,
     false, now() - interval '1 hour', null, now() + interval '1 hour'),
    -- Mismo tutorial, resultado final 720p aun en cola
    (1, 'resultado_final', 'pending', '720p',
     null, null,
     false, now() - interval '30 minutes', null, now() + interval '1 hour'),
    -- Julio, tutorial 4, preview 720p listo y principal
    (4, 'preview', 'ready', '720p',
     'https://cdn.ejemplo.com/tutoriales/4/preview-720p.mp4', 540,
     true, now() - interval '5 days', now() - interval '5 days' + interval '10 minutes', now() + interval '1 hour'),
    -- Sebastian, tutorial 7, preview 480p fallido
    (7, 'preview', 'failed', '480p',
     null, null,
     false, now() - interval '3 hours', null, now() + interval '1 hour'),
    -- Angela, tutorial 9, preview 360p pendiente
    (9, 'preview', 'pending', '360p',
     null, 90,
     false, now() - interval '20 minutes', null, now() + interval '1 hour');
