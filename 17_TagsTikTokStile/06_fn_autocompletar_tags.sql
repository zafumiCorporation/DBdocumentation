-- API 2: AUTOCOMPLETADO
-- SOLO BUSCA EN 'activo' , ORDENADO POR POPULARIDAD COMO TIK TOK
-- p_q = 'Unreal' LO QUE ESCRIBE EL USUARIO , p_limite CUANTAS SUGERENCIAS MAXIMO
drop function if exists fn_autocompletar_tags(text, int);
create or replace function fn_autocompletar_tags(p_q text, p_limite int default 6)
-- PINTA EL AUTOCOMPLETADO
returns table(id bigint, nombre text, slug varchar, usos_count bigint, es_entrenable boolean)
language sql
-- YO LEO LA PIZARRA, Y MIENTRAS DURE ESTA CONSULTA NO CAMBIA NADA. SI ME LLAMAS DOS VECES EN EL MISMO query, TE DOY EL MSIMO RESULTADO
-- VENTAJAS Optimizacion , Flexibilidad
stable
parallel safe
strict
as $$
    with
    q as (
        select
-- nullif = SI  trim DA '' VACIO LO VUELVE NULL. q.raw = 'Unreal' , q_slug = 'unreal'
            nullif(trim(p_q), '') as raw,
            public.fn_normalizar_slug(p_q::public.citext) as q_slug
    ),
-- prefijo LOS tags CUYO slug EMPIEZA CON LO QUE ESCRIBIO EL SUAURIO 'unreal'
    prefijo AS(
        select
            t.id,                               --IDENTIFICADOR UNICO DEL TAG EN LA TABLA
            t.nombre,                           --NOMBRE ORIGINAL DEL TAG "Unreal Engine"
            t.slug,                             --VERSION NORMALIZADA "unreal-Engine"
            t.usos_count,                       --CUANTAS VECES SE A USADO ESE TAG
            t.es_entrenable,
-- CREAS UNA COLUMMNA NUEVA EN MEMORIA LLAMADA prioridad CON VALOR 1 en TODAS LAS FILAS. PRIORIDAD 1 POR QUE ES MATCH PERFECTO.
            1 AS prioridad,
-- t.usos_count AS rank_popularidad COPIA LA TABLA  t.usos_count a rank_popularidad
            t.usos_count AS rank_popularidad
-- cross join
-- q TU TABLA TEMPORAL CON EL TEXTO BUSCADO (raw, q_slug)
-- public.tags TABLA REAL  de tags, con apodo t.
        from public.tags t, q
        where t.estado = 'activo'
            and q.raw is not null
-- ilike COMPARA CADENAS CON PATRONES PERO ignora las mayusculas/minusculas.
-- q.q_slug || % CONCATENA EL SLUG BUSCADO CON %
-- t.slug ILIKE 'unreal%' BUSCA TODOS LOS slugs QUE EMPIECEN CON "unreal" SIN IMPORTAR SI ESTA EN MAYUSCULAS O MINUSUCLAS
            and t.slug ilike q.q_slug || '%'
        order by t.usos_count desc
        limit p_limite
    ),
    fuzzy as(
        SELECT
            t.id,
            t.nombre::TEXT,
            t.slug,
            t.usos_count,
            t.es_entrenable,
-- prioridad 2 PORQUE ES POR similarity(), NO ES PERFECTO.
            2 as prioridad,
-- CALCULA UN NUMERO DE SIMILITUD ENTRE EL NOMBRE DEL tag Y LO QUE ESCRIBIO EL USUARIO
            public.similarity(t.nombre::TEXT, q.raw) as rank_sim
-- TABLA tags t , q = lo que escribio el usuario
            from public.tags t, q
            where t.estado = 'activo'
                and q.raw is not null
                and q.q_slug is not null
-- t.nombre , % ES PARECIDO A ESTE TEXTO? q.raw
                and t.nombre::TEXT % q.raw
-- select 1 NO IMPORTA EL VALOR SOLO SIRVE PARA COMPROBAR EXISTENCIA, devuelve TRUE SI ENCUENTRA ALGUNA FILA.
-- COMPARA EL id DEL TAG ACTUAL (t.id) CON LOS id QUE YA ESTAN EN prefijo.
                and not exists(select 1 from prefijo p where p.id = t.id)

            order by rank_sim desc, t.usos_count desc
            limit p_limite
    )
    select id, nombre, slug, usos_count, es_entrenable
    from (
        select * from prefijo
        union all
        select * from fuzzy
    ) s
    ORDER BY prioridad ASC , usos_count desc
    limit p_limite;
$$;