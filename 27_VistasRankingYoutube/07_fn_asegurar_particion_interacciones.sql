create or replace function public.fn_asegurar_particion_interacciones(
    p_cuando timestamptz default now()
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_inicio date := date_trunc('month', p_cuando)::date;
    v_fin date := (date_trunc('month', p_cuando) + interval '1 month')::date;
    v_nombre text := format('interacciones_%s', to_char(v_inicio, 'YYYYMM'));
    v_brin text := v_nombre || '_brin_ocurrio';
begin
    if not exists(
        select 1 from pg_class c
        join pg_namespace n
            on n.oid = c.relnamespace
        where n.nspname = 'public'
        and c.relname = v_nombre
    ) then
        execute format(
            'create table if not exists public.%I partition of public.interacciones
            for values from (%L) to (%L)',
            v_nombre, v_inicio, v_fin
        );
        execute format(
            'create index if not exists %I on public.%I using brin (ocurrio_en)',
            v_brin, v_nombre
        );
    end if;
    return v_nombre;
end;
$$;

-- PRUEBA 1: Verificar que fn_asegurar_particion_interacciones()
-- cree automaticame una particion cuando todavia no existe.
-- Estado inicial: No existe la particion interacciones_202701 , No existe el indice BRIN asociado.
-- Accion: Solicitar la particion correspondiente a enero de 2027.
-- Resultado esperado: Se crea interacciones_202701. Se crea el indice interacciones_202701_brin_ocurrio.
-- hasta antes de 2027-02-01. La funcion devuelve interaccioens_202701.

select '--- PRUEBA 1: particion de interacciones ---' as test;

select public.fn_asegurar_particion_interacciones('2026-11-05'::timestamptz) as noviembre;
-- Esperado: interacciones_202611.

select c.relname
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
    and c.relname = 'interacciones_202701';
-- Esperado ahora: cero filas.

select public.fn_asegurar_particion_interacciones('2027-01-15'::timestamptz) as creada;
-- Esperado: interacciones_202701.

select c.relname
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
    and c.relname in ('interacciones_202701', 'interacciones_202701_brin_ocurrio')
order by c.relname;
-- Esperado: dos filas.
