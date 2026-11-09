-- 04 API QUE LLAMA TU BACKEND
-- LA QUE USA TU ENDPOINT POST / TUTORIALES
-- RECIBE UN ARRAY DE STRINGS ["#Platformer", "ue5" , "Blueprints"]
-- DEVUELVE LOS IDS, CREA LOS QUE NO EXISTEN EN estado 'pendiente'

create or replace function public.fn_obtener_o_crear_tags(p_nombres text[])
returns  setof bigint
language plpgsql
set search_path = ''
AS $$
declare
begin
-- GUARD SI MANDA NULL O ARRAY VACIO {}, SALIMOS SIN HACER NADA
-- array_length DEVUELVE EL TAMAÑO DE UN ARREGLO.
-- 1 PRIMERA DIMENSION = CANTIDAD DE ELEMENTOS EN LA LISTA.
    if p_nombres is null or array_length(p_nombres, 1) is null then
        return;
    end if;

-- return query DEVUELVE EL RESULTADO DE ESTE SELECT COMO RESULTADO DE LA FUNCION.
    return query

-- with PERMITE DEFINIR UNA TABLA TEMPORAL EN MEMORIA CON NOMBRE limpio
    with
    limpio as (
-- 2. EMPIEZA A LEER ESTO DEL select
        select
-- raw CADA VALOR DEL ARRAY ("#Platformer", "ue5", "Blueprints")
-- as nombre_original APODO PARA MOSTRAR EL TEXTO YA LIMPIO
            trim(both from raw) as nombre_original,
--as slug APDO PARA ESA COLUMNA
            public.fn_normalizar_slug(trim(both from raw)::public.citext) as slug,
-- ord NUMERO DE ORDEN ORIGINAL EN EL ARRAY(1,2,3)
            ord as posicion
-- 1. EMPIEZA A LEER ESTO DEL FROM
-- unnest(p_nombres) CONVIERTE EL ARRAY EN FILAS EJEMPLO ["#Platformer", "ue5", "Blueprints"] → 3 filas.
-- with ordinality AGREGA UN NUMERO DE ORDEN (1,2,3)
-- t(raw, ord) CREA 2 COLUMNAS TEMPORALES , raw = VALOR ORIGINAL DEL ARRAY  , ord = POSICION
        from unnest(p_nombres) with ordinality as t(raw, ord)
-- FILTRA LOS VACIOS , SI ALGUIEN MANDA ["", " "] ESAS FILAS SE DESCARTAN
        where trim(both from raw) <> ''
    ),
    validos as(
-- USUARIO MANDA ["#Platformer", "ue5" , "Blueprints"] SI NO HAY DUPLICADOS , PASAN LOS 3.
-- USUARIO MANDA ["ue5", "UE5", " ue5 "]
-- distinct on (slug) POR CADA slug, QUEDATE SOLO CON 1 FILA
        select distinct on (slug)
            nombre_original,
            slug,
            posicion
-- SI ALGUIEN MANDA ["!!!", " "] DEVUELVE NULL , SOLO DEJA SLUGS VALIDOS
        from limpio where slug is not null
-- QUEDATE CON EL QUE APARECIO PRIMERO
        order by slug, posicion
    ),
-- AQUI YA ES DODNE ESCRIBES EN DISCO
    insertados as (
-- estado = 'pendiente' POR DEFAULT DE TU TABLA
        insert into public.tags (nombre, slug, estado)
        select nombre_original, slug, 'pendiente'
        from validos
-- CASO REAL: EN TU TABLA TAGS YA EXISTE slug = 'platformer' con id = 10.
-- USUARIO ["#Platformer", "ue5"]: POSTGRES INTENTA INSERTAR platformer YA EXISTE NO FALLA LO IGNORA CON do nothing
        on conflict (slug) do nothing
-- TE DEVUELVE LO QUE ACABAS DE INSERTAR SIN HACER OTRO SELECT
-- SI DE LOS 3 SOLO ue5 y blueprints ERAN NUEVOS devuelve (id: {11,12} slug:{'ue5', 'blueprints'})
        returning id , slug
    )
    select t.id
    from(
-- 1. PRIMERA LECTURA  TOMA LOS id , slug QUE ACABAS DE INSERTAR EN MEMORIA CON returning
        select id, slug from insertados
-- UNION DE RESULTADOS UNE LO QUE SALIO DE insertados CON LA CONSULTA 2
        union all
-- 2. SEGUNDA LECTURA CONSULTA 2
        select tags.id, tags.slug
        from public.tags
-- QUE ESTE DENTRO DE LA LISTA.
        where slug in (select slug from validos)
        )as t
-- v APODO CORTO PARA validos = v
-- v.posicion
-- v.slug = t.slug . t.slug = 'platformer' BUSCA EN VALIDOS DONDE slug = 'platformer' y ENCUENTRA POSICION 1
-- MIN = minimo
    order by (select MIN(v.posicion) from validos v where v.slug=t.slug);
    return;
end;
$$;