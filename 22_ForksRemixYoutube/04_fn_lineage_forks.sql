-- Lineage hacia arriba + arbol hacia abajo - nivel < 20 anti-ciclo.
-- Copia -> padre -> original.
-- Muestra el arbol de padres de un tutorial , Muestra de que tutorial viene cada forks hasta llegar al original.
-- Linea hacia arriba -> Herencia , Antecesores
-- Ejemplo: Tutorial Original (ID 10) <- Fork (ID 20) <- Fork (ID 30) <- Fork (ID 40)
-- Si consultas Tutorial 40 La funcion sube: 40 -> 30 -> 20 -> 10
-- Objetivo: Dame el tutorial actual + Todos sus padres + El nivel de cada uno.
-- Si consultas Tutorial 40 , fn_lineage_forks(40) Obtendras:
create or replace function public.fn_lineage_forks(p_tutorial_id bigint)
-- tutorial_id...............padre_id..............nivel
-- 40........................30....................1
-- 30........................20....................2
-- 20........................10....................3
-- 10........................null..................4
returns table(-- Devuelve
    tutorial_id bigint, -- ID del tutorial actual encontrado en cada nivel. Ejemplo 40 , 30 , 20, 10
    padre_id bigint, -- Es el tutorial del que nacio.
-- Id del tutorial ................. Id del tutorial padre.
-- 40 .............................. 30
-- 30 .............................. 20
    creador_id bigint, -- Usuario que creo ese tutorial. Dueno de cada tutorial encontrado.
    titulo varchar, -- Nombre de ese tutorial. Ejemplo Word Basico , Remix Word Basico , Remix Remix Word Basico.
    nivel int -- Indica que tan lejos estas del tutorial inicial.
)
language sql
stable
parallel safe
set search_path = ''
as $$
    with recursive sube as (
        -- Primera vuelta . Tutorial 40 -> Padre 30.
        -- id...............tutorial_padre_id............nivel
        -- 40...............30...........................1
        select t.id, t.tutorial_padre_id, t.creador_id, t.titulo, 1 as nivel
        from public.tutoriales as t
        where t.id = p_tutorial_id -- Id del tutorial = 40
        union all -- Une esa fila con la siguientes que ecuentra la recursion.
        -- Segunda vuelta , Si el tutorial anterior era 40 -> padre 30
        -- Ahora busca Quien es el tutorial 30 ?
        -- id...............tutorial_padre_id..............nivel
        -- 30...............20.............................2
        select p.id, p.tutorial_padre_id, p.creador_id, p.titulo, s.nivel + 1
        from public.tutoriales as p
        -- join Busca el padre del resultado anterior.
        join sube as s on p.id = s.tutorial_padre_id
        where s.nivel < 20 -- No recorrer mas de 20 niveles
    )
    select id, tutorial_padre_id, creador_id, titulo, nivel
    from sube
    order by nivel; -- Muestra los resultados ordenados por nivel.
$$;

-- PRUEBA 1 , Consultar el arbol de procedencia de un tutorial.
-- Objetivo: Verificar que fn_lineage_forks() recorrar correctamente la cadena de forks hasta llegar
-- al tutorial original.

-- Estado inicial: Existe un tutorial original creado por Shiriaru.
-- Julio creo un remix del original.
-- Sebastian creo un remix del remix de Julio.

-- Accion: Consultar el linaje del remix mas reciente creado por sebastian.

-- Resultado esperado:
-- Nivel 1: Tutorial de Sebastian.
-- Nivel 2: Tutorial de Julio.
-- Nivel 3: Tutorial original de Shiriaru.
select '--- PRUEBA1: linaje hacia arriba ---' as test;

-- El subquery es la copia de Sebastian, tutoriales.id.
-- 3 = Sebastian, usuarios.id.
-- Localizar el fork mas profundo
select id, titulo, tutoriales.tutorial_padre_id
from public.tutoriales
where creador_id = 3
order by id desc
limit 1;

select tutorial_id, padre_id, creador_id, titulo, nivel
from public.fn_lineage_forks(13)
order by nivel;
-- Esperado: tres filas.
-- nivel 1: creador 3 Sebastian, titulo "Remix: Remix: Create Sheet in Word",
-- padre_id = el remix de Julio.
-- nivel 2: creador 2 Julio, titulo "Remix: Create Sheet in Word", padre_id 1.
-- nivel 3: tutorial_id 1, creador 1 Shiriaru, titulo "Create Sheet in Word", padre_id null




