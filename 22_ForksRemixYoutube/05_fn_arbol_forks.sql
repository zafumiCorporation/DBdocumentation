-- bajar , original -> hijos -> nietos.
-- fn_arbol_forks(10) , Pregunta Que forks nacieron de este tutorial?
-- Arbol hacia abajo -> Significa Original -> Fork , Fork , Fork .
-- En lugar de buscar los padres, busca los hijos.
-- Objetivo: Dame el tutorial raiz + todos los forks hijos + El nivel de cada uno
-- Tutorial 10 -> Tutorial 20 -> Tutorial 30 -> Tutorial 40.
create or replace function public.fn_arbol_forks(p_raiz_id bigint)
returns table(
    tutorial_id bigint, -- Id del tutorial encontrado , Ejemplo: 10 , 20 , 30 , 40
    padre_id bigint, -- Es el tutorial del que nacio.
    -- id ...............id_del_padre
    -- 10................null
    -- 20 ...............10
    -- 30 ...............20
    -- 40 ...............30
    creador_id bigint, -- Es el usuario dueno de ese tutorial.
    titulo varchar, -- Nombre de cada tutorial. Ejemplo: Word Basico , Remix Word Basico, Remix Remix Word Basico.
    nivel int -- Que tan lejos esta del tutorial raiz.
)
language sql
stable
parallel safe
set search_path = ''
as $$
    with recursive baja as (
        -- Primera vuelta Supongamos , Tutorial raiz = 10  , nivel 1
        select t.id, t.tutorial_padre_id, t.creador_id, t.titulo, 1 as nivel
        -- Resultado.
        -- id...............padre..........nivel
        -- 10...............null...........1
        from public.tutoriales as t
        where t.id = p_raiz_id
        union all -- Une el resultado anterior con las siguientes busquedas.
        -- Segunda vuelta Tutorial 20 , nivel 2
        select c.id, c.tutorial_padre_id, c.creador_id, c.titulo, b.nivel + 1
        from public.tutoriales as c
        -- Pregunta , Quien tiene como padre al tutorial 10?. , Respuesta Tutorial 20
        join baja as b on c.tutorial_padre_id = b.id
        where b.nivel < 20
    )
    select id, tutorial_padre_id, creador_id, titulo, nivel
    from baja
    order by nivel, id;
    -- Tabla temporal "baja"
    -- id..............tutorial_padre_id...........nivel
    -- 10..............null........................1
    -- 20..............10..........................2
    -- 30..............20..........................3
    -- 40..............30..........................4
$$;

-- PRUEBA 1 Consultar todos los forks que nacieron de un tutorial.
-- Objetivo: Verificar que fn_arbol_forks() recorra correctamente
-- la jerarquia de forks descendentes a partir de un tutorial raiz.
-- Estado inicial: Existe un tutorial original creado por Shiriaru.
-- Julio creo un remix del original.
-- Sebastian creo un remix del remix de Julio.
-- Accion: Consultar el arbol de forks comenzado desde el tutorial original.
-- Resultado esperado:
-- Nivel 1: Tutorial original de Shiriaru.
-- Nivel 2: Remix de Julio.
-- Nivel 3: Remix de Sebastian.

-- 1 = "Create Sheet in Word", tabla public.tutoriales, columna id.
select tutorial_id, padre_id, creador_id, titulo, nivel
from public.fn_arbol_forks(1)
order by nivel, tutorial_id;
-- Esperado: tres filas.
-- nivel 1: tutorial_id 1, padre null, creador 1 Shiriaru, "Create Sheet in Word"
-- nivel 2: creador 2 Julio, padre_id 1, "Remix: Create Sheet in Word".
-- nivel 3: creador 3 Sebastian, padre = el id de Julio, "Remix: Remix: Create Sheet in word".

-- Desde el remixde Julio ya no aparece Shiriaru. El arbol baja no sube
select tutorial_id, padre_id, creador_id, titulo, nivel
from public.fn_arbol_forks(
     (select id
               from public.tutoriales
               where creador_id = 2
                 and tutorial_padre_id = 1)
     )
order by nivel;
-- Esperado: dos filas.
-- nivel 1: Julio, "Remix: Create Sheet in Word".
-- nivel 2: Sebastian, "Remix: Remix: Create Sheet in Word"