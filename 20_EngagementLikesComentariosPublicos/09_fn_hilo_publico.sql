-- Cualquiera ve el arbol. No necesita ser amigo.
create  or replace function public.fn_hilo_publico(p_raiz_id bigint)
returns table (
    id bigint,
    padre_id bigint,
    autor_id bigint, -- Quien escribio ese comentario
    clase public.comentario_clase,
    titulo varchar,
    codigo citext,
    cuerpo_texto text,
    audio_url text,
    miembros_count int,
    -- Es un numero inventado por ti en la consulta para saber que tan profundo esta un comentario en el arbol.
    -- Nivel 1 -> comentario raiz , Nivel 2 -> Respuesta a la raiz , Nivel 3 -> Respuesta a una respuesta.
    nivel int,
    created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
    -- recursive -> Sirve para recorrer estructuras en forma de arbol. Desde la raiz hacia abajo.
    with recursive arbol as(
        select c.id, c.padre_id, c.autor_id, c.clase, c.titulo, c.codigo,
               c.cuerpo_texto, c.audio_url::text, c.miembros_count,
               -- 1 as nivel Inventas un numero para marcar la profundidad.
               1 as nivel, c.created_at
        from public.tutorial_comentarios as c
        -- Filtra para que solo traiga el comentario raiz.
        where c.id = p_raiz_id
        and c.padre_id is null

        union all

        -- Recursivo: hijos de nivel anterior, max 20 niveles  (evita loop infinito)
        select h.id , h.padre_id, h.autor_id, h.clase, h.titulo, h.codigo,
               h.cuerpo_texto, h.audio_url::text, h.miembros_count,
               -- a -> comentario padre Si el padre era nivel 1 (raiz), el hijo sera el nivel 2.
               a.nivel + 1, h.created_at
        from public.tutorial_comentarios as h
        -- Une cada hijo con su padre.  "Conecto cada respuesta con el comentario al que responde"
        join arbol as a
        on h.padre_id = a.id
        where a.nivel < 20 -- Limita la profundida maxima a 20 niveles.
    )
    select * from arbol order by created_at;
$$;

-- PRUEBA 1. Hilo de un comentario normal. Cualquiera lo lee, sin ser amigo.
select '--- PRUEBA 1: hilo normal ---' as test;

-- fn_hilo_publico(p_raiz_id)
-- 1 = comentario raiz de Shiriaru, tabla public.tutorial_comentarios.
-- Texto: "Este es el comentario raiz del tutorial." Tutorial 1 "Create Sheet in Word".
select id, padre_id, autor_id, clase, cuerpo_texto, nivel
from public.fn_hilo_publico(1)
order by nivel, id;
-- Esperado: tres filas.
-- id 1, padre null, autor 1 Shiriaru, clase normal, nivel 1.
-- id 4, padre 1, autor 3 Sebastian, "Yo tambien, en el paso 2.", nivel 2.
-- la respuesta nueva de la prueba 4 del archivo 08, padre 1, autor 3, "Lo anoto para el paso 3.", nivel

-- PRUEBA 2. Hilo de una comunidad. La raiz trae titulo, codigo y miembros.
select '--- PRUEBA 2: hilo comunidad ---' as test;

-- 6 = UnrealHQ, tutorial_comentarios.id. Autor Julio. Tutorial 4 "Create Video Game in Unreal Engine"
select id, padre_id, autor_id, clase, titulo, codigo, cuerpo_texto, miembros_count, nivel
from public.fn_hilo_publico(6)
order by nivel, id;
-- Esperado: dos filas.
-- id 6, padre null, autor 2 Julio, clase comunidad, titulo "Comunidad Unreal",
-- codigo UnrealHQ, miembros_count 2, nivel 1.
-- id 8, padre 6, autor 3 Seebastian, "Me uno para el nivel 2.", nivel 2.
-- Shiriaru no entro: La prueba 5 no dejo respuesta.

-- 4 = respuesta de Sebastian al comentario 1. padre_id = 1, no es raiz.
select '--- PRUEBA 3: id que no es raiz ---' as test;
select id, padre_id, nivel
from public.fn_hilo_publico(4);
