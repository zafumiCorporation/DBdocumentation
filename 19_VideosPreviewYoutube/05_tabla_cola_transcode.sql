-- Tabla de lista de trabajos pendientes (tareas que dicen convierte este video a tal calidad) , no son copias
-- Los workers procesan esas tareas y generarn los archivos finales.
create table if not exists public.video_transcode_cola(
    id bigint generated always as identity primary key,
    video_id bigint not null,-- Que video hay que procesar
    resolucion varchar(10) not null,-- A que calidad debe convertirse (360p, 480p, 720p, etc.)
    tomado_at timestamptz,          -- Cuando un worker tomo ese trabajo
    created_at timestamptz not null default now(),-- Cuando se agrego a la cola.

    -- foreign key
    constraint video_transcode_cola_tutorial_videos_video
        foreign key (video_id) references public.tutorial_videos(id)
                on delete cascade
);

-- Datos. Dos trabajos libres (tomado_at null) y uno ya tomado
-- fn_worker_tomar_job solo devuelve los que tienen tomado_at null.
insert into public.video_transcode_cola (video_id, resolucion)
select v.id, '1080p'
from public.tutorial_videos as v
where v.tutorial_id = 1 and v.tipo = 'preview' and v.resolucion = '1080p';

insert into public.video_transcode_cola (video_id, resolucion)
select v.id, '720p'
from public.tutorial_videos as v
where v.tutorial_id = 1 and v.tipo = 'resultado_final' and v.resolucion = '720p';

insert into public.video_transcode_cola (video_id, resolucion, tomado_at)
select v.id, '360p', now() - interval '10 minutes'
from public.tutorial_videos as v
where v.tutorial_id = 9 and v.tipo = 'preview' and v.resolucion = '360p';


