-- Genera el ranking del feed
-- fn_raking_feed: 1. Cuenta vistas de los ultimos 7 dias. 2. Cuenta clicks  de los ultimos 7 dias.
-- 3. Lee likes. 4. Calcula un score. 5. Ordena los tutoriales. 6 Devuelve los mejores.
create or replace function public.fn_ranking_feed(
    p_limite int default 20 -- Cantidad maxima de tutoriales a devolver.
)
returns table (
    id bigint,
    titulo text,
    vistas_7d int,
    clicks_7d int,
    score numeric,
    decil int
)
language plpgsql
stable
parallel safe
set search_path = ''
as $$
begin
    return query
    with v as( -- Tabla temporal de vistas Contiene tutorial_id , vistas_7d
        select
            tv.tutorial_id, -- Tutorial al que pertenecen las vistas.
            count(*) filter ( where tv.cuenta_unica)::int as vistas_7d -- Cantidad de vistas unicas durante los ultimos 7 dias.
        from public.tutorial_vistas as tv
        where tv.visto_en >= now() - interval '7 days' -- Tomar datos desde hace 7 dias hasta ahora.
        group by tv.tutorial_id -- Agrupa por tutorial.
    ),
    c as ( -- Tabla temporal de clics.
        select
            i.tutorial_id,
            count(*) filter ( where i.kind in ('click_card', 'click_play'))::int as clicks_7d
        from public.interacciones as i
        where i.ocurrio_en >= now() - interval '7 days'
        group by i.tutorial_id
    ),
    base as ( -- Tabla temporal final donde se unen tutoriales, vistas y clics.
        select
            t.id,
            t.titulo,
            coalesce(v.vistas_7d, 0) as vistas_7d, -- Vistas obtenidas desde la tabla temporal v.
            coalesce(c.clicks_7d, 0) as clicks_7d, -- Clics obtenidos desde la tabla temporal C.
            (coalesce(v.vistas_7d, 0) * 1.0)
            + (coalesce(c.clicks_7d, 0) * 3.0)
            + (coalesce(t.likes_count, 0) * 0.5) as score -- Puntuacion que determina que tan relevante es un tutorial.
        from public.tutoriales as t
        left join v on v.tutorial_id = t.id -- Une tutoriales con vistas.
        left join c on c.tutorial_id = t.id -- Une tutoriales con clics
        where coalesce(t.es_publico, false) = true -- Solo mostrar tutoriales publicos
    )
    select
        b.id,
        b.titulo::text,
        b.vistas_7d,
        b.clicks_7d,
        b.score,
        -- ntile -> Divide los resultados en 10 grupos. Ej: 100 tutoriales. 1-10 decil 1 , 11-20 decil 2
        -- over -> indica a ntile como ordenar los datos antes de dividirlos.
        ntile(10) over (order by b.score desc )::int
    from base as b
    order by b.score desc
    limit greatest(p_limite, 1); -- Numero maximo de tutoriales a devolver.
end;
$$;

-- PRUEBA 1 Generar el ranking inicial del feed.
-- Objetivo: Comprobar que fn_ranking_feed calcule y ordene los tutoriales publicos y privados.
-- Los tutoriales tienen diferentes cantidades de likes. Word ya tiene dos vistas unicas y dos
-- clicks registrados.
-- Accion: Solicitar los cinco tutoriales mejor posicionados.
-- Comprobar que los tutoriales privados no aparezcan.
-- Solicitar los primero veinte y verificar que los remix privados 11, 12 y 13 esten excluidos.
-- Solicitar unicamente los tres primero resultados.

select '--- PRUEBA 1: ranking en frio ---' as test;

-- 4 Unreal 501 -> 250.5. 5 Build Level 320 -> 160. 6 UE5 250 -> 125.
-- 7 PowerPoint 180 -> 90. 1 Word 152 -> 76.
-- El remix 11 es_publico false.

select id, titulo, vistas_7d, clicks_7d, score, decil
from public.fn_ranking_feed(5);
-- 4 Create Video Game... vistas 0 clicks 0 score 250.5
-- 5 Build Level... 160
-- 6 Create new project... 125
-- 7 Create Presentation... 90
-- 1 Create Sheet in Word, vistas_7d 2, clicks_7d 2, score 84

select id
from public.fn_ranking_feed(20 )
where id in (11, 12, 13);
-- Esperado: cero filas. Los remix privados no entran.

select count(*) as filas
from public.fn_ranking_feed(3);
-- Esperado: 3. 4, 5 y 6

-- PRUEBA 2 : Registrar un Play en el tutorial lider.
-- Estado inicial: Unreal (tutorial 4) ocupa el primer lugar con 250.5 puntos.
-- Unreal tiene 0 vistas uncias y 0 clics. Julio corresponde al usuario 2.
-- Accion: Registrar una vista de Julio sobre Unreal mendiante fn_registrar_vista().
-- Registrar un click_play mediante fn_registrar_interaccion().
-- Consultar nuevamente los tres primero tutoriales del ranking.
-- Resultado esperado: Unreal registra una vista unica y un clic adicional.
-- Su puntuacion aumenta de 250.5 a 254.5 . Unreal conserva el primer lugar.
-- Build level y UE5 permanecen en segundo y tercer lugar.
-- Word conserva sus 84 puntos y queda fuera del top 3.

select '--- PRUEBA 2: play en el lider ---' as test;

-- 2 = Julio, usuarios.id 4 = "Create Video Game in Unreal Engine".
select public.fn_registrar_vista(2, 4, 'feed', 1::smallint);
select public.fn_registrar_interaccion(2, 4, 'click_play', '{}'::jsonb);

select id, titulo, vistas_7d, clicks_7d, score
from public.fn_ranking_feed(3);
-- Esperado:
-- 4 Unreal, vistas 1, clicks 1, score 1 + 3 + 250.5 = 254.5
-- 5 Build Level 160
-- 6 UE5 125
