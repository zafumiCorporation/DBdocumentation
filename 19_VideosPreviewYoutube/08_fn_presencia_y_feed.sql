create or replace function public.fn_set_presencia_rica( p_yo bigint , p_tutorial_id bigint,
    p_paso smallint, p_estado text default 'viendo'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_titulo text;
    v_preview text;
begin
    -- 1. Denormaliza titulo/preview  (10k QPS 10mil queries por segundo)
    select t.titulo, t.preview_video_url --Busca el titulo y la URL de preview del tutorial
    into v_titulo, v_preview
    from public.tutoriales as t
    where t.id = p_tutorial_id;

    -- 2. Inserta una fila que dice que esta haciendo el usuario ahora mismo.
    insert into public.presencia_activa(
        usuario_id, tutorial_id, paso_actual, estado_actividad, last_seen_at, snapshot
    ) values (
              p_yo, p_tutorial_id , p_paso, p_estado, now(),
              jsonb_build_object('titulo', v_titulo, 'preview', v_preview , 'paso', p_paso)
    )
    on conflict (usuario_id) do update set
        -- excluded Representa los valores que intentabas insertar
        tutorial_id = excluded.tutorial_id,
        paso_actual = excluded.paso_actual,
        estado_actividad = excluded.estado_actividad,
        last_seen_at = now(),
        snapshot = excluded.snapshot;

    -- 3. Guarda un historial permanente de lo que el usuario ha visto
    insert into public.historial_visualizaciones( usuario_id, tutorial_id, paso_max_alcanzado, ultima_vez_en)
    values (p_yo, p_tutorial_id, p_paso, now())
    on conflict on constraint uq_historial_usuario_tutorial do update set
        paso_max_alcanzado = greatest(
            public.historial_visualizaciones.paso_max_alcanzado,
            excluded.paso_max_alcanzado
        ),
        ultima_vez_en = now();

    -- 4 Push real-time a tus amigos: Listen presencia_cambio(que tutorial estas viendo)
    perform pg_notify(
      'presencia_cambio',
      jsonb_build_object('usuario_id', p_yo, 'tutorial_id', p_tutorial_id)::text
    );
end;
$$;


create or replace function public.fn_clear_presencia(p_yo bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    delete from public.presencia_activa where usuario_id = p_yo;
end;
$$;

create or replace function public.fn_feed_amigos_viendo_ahora(p_yo bigint)
returns table (amigo_id bigint, username varchar, handle varchar, tutorial_id bigint,
               titulo text, preview_url text, paso_actual smallint, estado_actividad text,
               started_at timestamptz, share_codigo citext
)
language sql
stable
parallel safe
set search_path = ''
as $$
    -- Panel derecho "Amigos" de tu Imagen 2
    select u.id , u.username, u.handle,
           pa.tutorial_id, (pa.snapshot->>'titulo')::text, (pa.snapshot->>'preview')::text ,
           pa.paso_actual, pa.estado_actividad, pa.started_at,
           tc.codigo
    from public.amistades as a
    -- Tabla amistades con usuarios
    join public.usuarios as u on u.id = a.seguido_id
    -- Tabla usuarios con presencia_activa
    join public.presencia_activa as pa on pa.usuario_id = u.id
    --Resultado una tabla combinada con amigos + sus datos + su presencia actual
    left join lateral (--Ejecuta la subconsulta para cada fila de la tabla anterior
        select c.codigo
        from public.tutorial_compartidos as c
        where c.creador_id = u.id
          and c.tutorial_id = pa.tutorial_id
        order by c.created_at desc
        limit 1
    )as tc on true
    where a.seguidor_id = p_yo
      and a.estado = 'accepted'
      and pa.last_seen_at > now() - interval '2 minutes'
      and pa.tutorial_id is not null -- Solo si estan viendo un tutorial
    order by pa.last_seen_at desc;
$$;

-- Prueba 1. Julio sigue en el mismo tutorial, pero avanza de paso.
-- Patron Youtube/TikTok: "viendo ahora" se refresca y el historial solo sube , nunca baja.
select '--- PRUEBA 1: refrescar presencia ---' as test;

-- Antes. Presencia de Julio. Tabla public.presencia_activa, una fila por usuario.
-- 2 = Julio, tabla public.usuarios.
select usuario_id, tutorial_id, paso_actual, estado_actividad, started_at, last_seen_at, snapshot
from public.presencia_activa
where usuario_id = 2;
-- Esperado ahora: tutorial_id 4 "Create Video Game In Unreal Engine", paso_actual 2, estado viendo.
-- Last_seen_at es viejo, fuera de los ultimos 2 minutos

-- Antes. Historial de Julio en ese tutorial. Tabla public.historial_visualizaciones
select usuario_id, tutorial_id, paso_max_alcanzado, completado, ultima_vez_en
from public.historial_visualizaciones
where usuario_id = 2
    and tutorial_id = 4;
-- Esperado ahora: paso_max_alcanzado = 2

-- Antes. Feed de Shiriaru. La funcion lista a los amigos que Shiriaru sigue, no a Shiriaru.
-- 1 = Shiriaru, tabla public.usuarios. Amigos aceptados: Julio 2, Sebastian 3, Angela 4.
select * from public.fn_feed_amigos_viendo_ahora(1);
-- Esperado ahora: cero filas. Los tres amigos tienen Last_seen_at viejo.

-- fn_set_presencia_rica(p_yo, p_tutorial_id, p_paso, p_estado)
-- 2 = Julio, tabla public.usuarios.
-- 4 = "Create Video Game in unreal Engine", tabla public.tutoriales. Creador: Julio.
-- 3 = paso al que avanzo
-- 'viendo' = estado_actividad
select public.fn_set_presencia_rica(2::bigint,4::bigint,3::smallint, 'viendo'::text);

-- Despues. La misma fila de presencia, no una fila nueva. linea 106
-- esperado: tutorial_id 4, paso_actual 3, estado viendo, Last_seen_at de ahora
-- started_at no cambiado. snapshot.titulo = "Create Video Game in Unreal Engine"

-- Despues el historial sube de 2 a 3 linea 113
-- Esperado: paso_max_alcanzado = 3

-- Despues Feed de Shiriaru (usuarios.id 1)
select * from public.fn_feed_amigos_viendo_ahora(1);
-- Esperado: una fila.
-- amigo_id 2 = Julio. handle null, porque Julio no tiene handle
-- tutorial_id 4, titulo "Create Video Game in Unreal Engine", paso_actual 3, estado viendo
-- share_codigo = Unreal5x, el link que Julio ya tenia para ese tutorial.

-- PRUEBA 2. Julio cambia de tutorial. Sigue habiendo una sola presencia.
select '--- PRUEBA 2: cambiar de tutorial ---' as test;

-- Antes. Julio sigue en el tutorial 4. linea 106
-- Esperado ahora: tutorial_id 4, paso_actual 3.

-- Antes. Historial de Julio en el tutorial 5. Todavia no existe
-- 5 = "Build Level in Unreal Engine", tabla public.tutoriales
select usuario_id, tutorial_id, paso_max_alcanzado
from public.historial_visualizaciones
where usuario_id = 2
  and tutorial_id = 5;
-- Esperado ahora: cero filas

-- 2 = Julio, tabla public.usuarios.
-- 5 = "Build Level in Unreal Engine", tabla public.tutoriales. Creador: Julio
-- 1 = paso 1. 'ejecutando' = estado_actividad
select public.fn_set_presencia_rica(2::bigint, 5::bigint, 1::smallint, 'ejecutando');

-- Despues Sigue una sola fila, ahora en el otro tutorial linea 106
-- Esperado: tutorial_id 5, paso_actual 1, estado ejecutando
-- snapshot.titulo = "Build Level in Unreal Engine"

-- Despues el historial del tutorial 4 se queda en 3. El del 5 nace en 1.
select usuario_id, tutorial_id, paso_max_alcanzado
from public.historial_visualizaciones
where usuario_id = 2
  and tutorial_id in (4,5)
order by tutorial_id;
-- Esperado: tutorial 4 con paso_max 3, tutorial 5 con paso_max 1

select * from public.fn_feed_amigos_viendo_ahora(1);
-- Esperado: Julio en tutorial 5, paso 1, estado ejecutando

-- PRUEBA 3. Julio sale. El feed lo pierde y el historial se conserva
select '--- PRUEBA 3: limpiar presencia ---' as test;

-- Antes. Julio aparece en el feed de Shiriaru
select * from public.fn_feed_amigos_viendo_ahora(1);

-- fn_clear_presencia(p_yo)
-- 2 = Julio, tabla public.usuarios, columna id.
select public.fn_clear_presencia(2);

-- Despues. Ya no hay precencia de Julio
select usuario_id , tutorial_id, paso_actual
from public.presencia_activa
where usuario_id = 2;
-- Esperado: cero filas.

-- Despues. Feed de Shiriaru (usuarios.id 1)
select * from public.fn_feed_amigos_viendo_ahora(1);
-- Esperado: cero filas.
-- Sebastian (3) y Angela (4) siguen en presencia_activa, con last_seen_at viejo, por eso no salen.

-- Despues el historial de Julio no se borra
select usuario_id, tutorial_id, paso_max_alcanzado
from public.historial_visualizaciones
where usuario_id = 2
order by tutorial_id;
-- Esperado: tutorial 1 paso 5, tutorial 4 paso 3 , tutorial 5 paso 1