-- 03_FUNCIONES_Y_TRIGGERS
-- 1. fn_normalizar_slug SI UN USUARIO ESCRIBE " #Hoja en Blanco!!" lo convierte en hoja-en-blanco.
create or replace function public.fn_normalizar_slug(p_texto public.citext)
returns varchar(80)
immutable
-- NO CHISMEA DATOS , ES SEGURA
-- leakproof
parallel safe
strict
-- search_path LISTA DE CARPETAS, CANDADO OBLIGA A QUE USES public.unaccent() LA OFICIAL, NO UNA FALSA
set search_path = ''
as $$
declare
    v_slug text;
begin

    perform set_config('search_path', '', true);

    -- regexp_replace() TODO LO QUE NO SEA a-z0-9 LO CONVIERTE EN UN SOLO GUION '-'  EN TODO EL TEXTO
    -- trim() -> trim(BOTH '-_' FROM ...) QUITA GUIONES Y GUIONES BAJOS AL INICIO Y FINAL
    v_slug := trim(BOTH '-_' FROM regexp_replace(
        lower(public.immutable_unaccent(p_texto::TEXT)),
        '[^a-z0-9]+', '-', 'g'
    ));

    -- Guard: SI DESPUES DE LIMPIAR QUEDA VACIO -> "!!!", " " -> NULL
    if v_slug is null or v_slug='' THEN
        return null;
    end if;

    -- LIMIT: TRUNCAMOS DE FORMA SEGURA A 80 CHARS COMO TU VARCHAR(80)
    -- substring cortalo.
    -- from 1 EMPEIZA EN EL CARACTER NUMERO 1
    -- for 80 DAME SOLO 80 CARACTERES.
    return trim(both '-' from substring(v_slug from 1 for 80));

end; $$ language plpgsql;