-- fn_asegurar_particion_vistas -> Verifica si existe la particion del mes. Si existe: no hace nada. Si no existe: La crea automaticamente.
create or replace function public.fn_asegurar_particion_vistas(
    p_cuando timestamptz default now() -- Fecha para determinar que particion debe de existir. Ej: 2026-11-15
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_inicio date := date_trunc('month', p_cuando)::date; -- Primer dia del mes Ej: 2026-11-01
    v_fin date := (date_trunc('month', p_cuando) + interval '1 month')::date; -- Primer dia del siguiente mes.
    v_nombre text := format('tutorial_vistas_%s', to_char(v_inicio, 'YYYYMM')); -- Nombre de la particion Ej: tutorial_vistas_202611
    v_brin text := v_nombre || '_brin_visto';
begin
    if not exists(
        select 1
        -- pg_class -> catalogo interno de PostgreSQL Ej: Tablas , Indices, Particiones , Vistas.
        from pg_class as c
        -- pg_namespace -> catalogo de esquemas Ej: public, auth, storage.
        join pg_namespace as n on n.oid = c.relnamespace
        where n.nspname = 'public'
            and c.relname = v_nombre
    ) then
        execute format(
            'create table if not exists public.%I partition of public.tutorial_vistas
            for values from (%L) to (%L)',
            v_nombre, v_inicio, v_fin
        );

        -- Brin guarda informacion resumida por bloques. Bloque 1. Fechas noviembre, Bloque 2 Fechas diciembre.
        execute format(
            'create index if not exists %I on public.%I using brin (visto_en)',
            v_brin, v_nombre
        );
    end if;

    return v_nombre; -- Devuelve el nombre de la particion encontrada o creada.
end;
$$;

-- PRUEBA 1: Noviembre 2026 ya existe. Solo devuelve el nombre.
-- Estado inicial: Existe la particion tutorial_vistas_202611.
-- La particion pertenece al esquema public.
-- Accion: Solicitar la particion correspondiente a noviembre de 2026.
-- Resultado esperado: No se crea una segunda particion. No se ejecuta la creacion del indice BRIN.
-- La funcion devuelve tutorial_vistas_202611.

select '--- PRUEBA 1: particion de noviembre ---' as test;

select public.fn_asegurar_particion_vistas('2026-11-05'::timestamptz) as particion;
-- Esperado: tutorial_vistas_202611

-- PRUEBA 2. Enero 2027 no existe. La funcion la crea y deja el BRIN.
-- Estado inicial: No existe la particion tutorial_vistas_202701.
-- No existe el indice BRIN asociado.
-- Accion: Solicitar la particion correspondiente a enero de 2027.
-- Resultado esperado: Se crea tutorial_vistas_202701.
-- Se crea el indice tutorial_vistas_202701_brin_visto.
-- La particion almacena registros desde 2027-01-01 hasta antes de 2027-02-01.
-- La funcion devuelve tutorial_vistas_202701.
select '--- PRUEBA 2: particion de enero ---' as test;

select c.relname
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
    and c.relname = 'tutorial_vistas_202701';
-- Esperado ahora: cero filas.

select public.fn_asegurar_particion_vistas('2027-01-15'::timestamptz) as creada;
-- Esperado: tutorial_vistas_202701.

select c.relname
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
    and c.relname in ('tutorial_vistas_202701', 'tutorial_vistas_202701_brin_visto')
order by c.relname;
-- Esperado: dos filas. La tabla y el indice brin.



