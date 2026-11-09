-- Workers Youtube -> Procesos o scripts que trabaja en segundo plano.
-- Cada worker toma una tarea(job) de la cola video_transcode_cola. Varios workers puedan trabaja al mismo tiempo
-- Ejemplo: Worker 1 toma el job de convertir un video a 360p, Worker 2 toma el job de convertilo a 480p
create or replace function public.fn_worker_tomar_job()
returns table (cola_id bigint, video_id bigint, resolucion varchar)
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- video_transcode_cola Lista de trabajos pendientes.
    return query
    update public.video_transcode_cola as c
    set tomado_at = now()
    from (
        select q.id
        from public.video_transcode_cola as q
        where q.tomado_at is null-- Solo los que aun no han sido tomados
        order by q.created_at asc -- Busca el trabajo mas viejo
        -- for update -> Bloquea la fila para que otro worker no la tome al mismo tiempo.
        -- skip locked -> Si otro worker ya bloqueo una fila, la salta y busca otra.
        for update skip locked
        limit 1
        -- Resultado: si 10 worker pregunta al mismo tiempo, cada uno recibe un trabajo distinto.
    ) as q
    where c.id = q.id -- Usa el id de la subconsulta para saber cual fila actualizar.
    returning c.id, c.video_id, c.resolucion; -- Devuelve los datos del trabajo tomado.
end;
$$;

-- PRUEBA 1. El worker toma el trabajo libre mas viejo.
select '--- PRUEBA 1: tomar el job mas viejo' as test;

-- Antes. Cola completa, unida al video y al titulo para saber que trabajo es cada fila.
select c.id as cola_id, c.video_id, c.resolucion, c.tomado_at,
       v.tutorial_id, v.tipo, v.estado, t.titulo
from public.video_transcode_cola as c
join public.tutorial_videos as v on v.id = c.video_id
join public.tutoriales as t on t.id = v.tutorial_id
order by c.id;
-- Esperado ahora:
-- cola 1, video_id 2, 1080p, tomado_at null
-- video 2 = "Create Sheet in Word", preview, estado processing.
-- cola 2, video_id 3, 720p, tomado_at null.
-- video 3 = tutorial "Create Sheet in Word", resultado_final, estado pending.
-- cola 3, video_id 6, 360p tomado_at ya lleno.
-- video 6 = tutorial 9 "Edit Music & Audio Mixes", preview, estado pending

-- fn_worker_tomar_job() no recibe argumentos.
-- Toma la fila libre con created_at mas antiguo y le escribe tomado_at
select * from public.fn_worker_tomar_job();
-- Esperado: una fila, cola_id 1, video_id 2, resolucion 1080p.

-- Despues. La cola 1 queda tomada, La 2 sigue libre. La 3 ya estaba tomada.
select id, video_id, resolucion, tomado_at
from public.video_transcode_cola
order by id;
-- Esperado: id 1 con tomado_at de ahora. id 2 con tomado_at null. id 3 con tomado_at viejo.

-- PRUEBA 2. El segundo worker toma el siguiente libre
select '--- PRUEBA 2: tomar el siguiente job ---' as test;

-- Antes confirma cual sigue libre. linea 55
-- Esperado ahora: solo el id 2 tiene tomado_at null

select * from public.fn_worker_tomar_job();
-- Esperado: una fila, cola_id 2 , video_id 3, resolucion 720p
-- video_id 3 = tutorial_videos.id 3, tutorial 1 "Create Sheet in Word", resultado_final

-- Despues. Ya no queda ninguno libre. Linea 55
-- Esperado: Las tres filas con tomado_at lleno.

-- PRUEBA 3. No hay trabajo Libre. La funcion no devuelve fila y no toca la cola.
select '--- PRUEBA 3: cola vacia de trabajos libres ---' as test;

-- linea 55
-- Esperado ahora: 3 filas, ninguna con tomado_at null.

select * from public.fn_worker_tomar_job();
-- Esperado: cero filas.



