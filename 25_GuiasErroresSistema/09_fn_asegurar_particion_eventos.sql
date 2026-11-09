-- Tu tienes esta tabla particionada: eventos_sistema
-- Sus hijos: eventos_sistema_202610 , eventos_sistema_202611 , eventos_sistema_default
-- fn_asegurar_particion_eventos -> Existe para decir "Antes de guardar un evento ,
-- asegurate de que exista la particion del mes correspondiente."
-- La funcion calcula Mes = Diciembre 2026 > Busca eventos_sistema_202612 > Si existe: no hace nada , Si no existe: la crea.
DROP FUNCTION public.fn_asegurar_particion_eventos(timestamptz);
create or replace function public.fn_asegurar_particion_eventos(
    p_cuando timestamptz default now() -- Fecha de la particion a buscar o crear.
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    -- date_trunc -> Corta la fecha al inicio del mes Ej: 2026-12-15 18:30:20 , Resultado: 2026-12-01 00:00:00
    v_inicio date := date_trunc('month', p_cuando)::date; -- Primer dia del mes
    -- 2026-12-01 -> interval '1 month' 2027-01-01
    v_fin date := (date_trunc('month', p_cuando) + interval '1 month')::date; -- Primer dia del siguiente mes.
    -- to_char -> convierte una fecha a texto. Ej: fecha : 2026-12-01 > Formato: 'YYYYMM' Resultado: 202612
    -- format -> Resultado: eventos_sistema_202612
    v_nombre text := format('eventos_sistema_%s', to_char(v_inicio, 'YYYYMM'));
    -- Concatena eventos_sistema_202612 con _brin_ocurrio , Resultado: eventos_sistema_202612_brin_ocurrio
    v_brin text := v_nombre || '_brin_ocurrio';
begin
    -- Existe una tabla llamada eventos_sistema_202612 en el esquema public?
    if not exists( -- Si es false = True.
        -- pg_class -> Guarda informacion de Tablas, indices , vistas, secuencias.
        select 1 from pg_class c
        -- pg_namespace -> Guarda esquemas , public, pg_catalog.
        join pg_namespace n on n.oid = c.relnamespace
        -- nspname -> nombre del esquema.  relname -> Nombre de la tabla
        where n.nspname = 'public' and c.relname = v_nombre
    ) then
        -- execute format -> Construye SQL dinamicamente y luego ejecutalo
        execute format(
            -- %I -> Identificador SQL . Valor de objetos, Ej: v_nombre , Resultado: eventos_sistemas_202612 , Se usa para: Tablas , Columnas , Indices
            -- $L -> Significa SQL. Valor literal.
            'create table if not exists public.%I partition of public.eventos_sistema
             for values from (%L) to (%L)',
            v_nombre , v_inicio, v_fin

        );

        execute format(
            -- Brin es un tipo de indice se usa para Fechas, Logs , Eventos , Millones de registros.
            'create index if not exists %I on public.%I using brin (ocurrio_en)',
                v_brin, v_nombre
        );
    end if;

    return v_nombre; -- Devuelve nombre de la particion.
end;
$$;

-- fn_eventos_asegurar_particion -> Una funcion que llama a otra.
create or replace function public.fn_eventos_asegurar_particion(
    p_ts timestamptz default now() -- Fecha de la particion a buscar o crear.
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
    return public.fn_asegurar_particion_eventos(p_ts);
end;
$$;

-- PRUEBA 1: Identificar una particion existente.
-- Escenario: Noviembre de 2026 ya dispone de una particion mensual.
-- Objetivo: Comprobar que la funcion calcula correctamente el nombre de la particion correspondiente a una fecha de noviembre.
-- Entrada: 2026-11-02
-- Proceso Esperado: 1. Calcula el inicio del mes: 2026-11-01 , 2. Calcula el inico del siguiente mes. 2026-12-91
-- 3. Construye el nombre: eventos_sistema_202611, 4. Comprueba que la particion ya existe.

select '---PRUEBA 1: particion de noviembre ---' as test;

select public.fn_eventos_asegurar_particion('2026-11-02'::timestamptz) as particion;
-- Resultado esperado: eventos_sistema_202611

-- PRUEBA 2: Crear una particion mensual inexistente
-- Escenario: Diciembre de 2026 todavia no tiene una particion mensual.
-- Objetivo: Comprobar que la funcion principal pueda crear la particion de diciembre,
select '--- PRUEBA 2: particion de diciembre ---' as test;

select c.relname
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
    and c.relname = 'eventos_sistema_202612';
-- Esperado ahora: cero filas.

select public.fn_eventos_asegurar_particion('2026-12-15'::timestamptz) as creada;
-- Esperado: eventos_sistema_202612.

select c.relname
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
    and c.relname in ('eventos_sistema_202612', 'eventos_sistema_202612_brin_ocurrio')
order by c.relname;
-- Esperado: dos filas. la tabla y el indice brin.
