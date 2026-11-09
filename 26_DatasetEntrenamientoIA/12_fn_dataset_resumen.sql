-- Devuelve un resume estadistico de un dataset.
-- Solo consulta informacion.
create or replace function public.fn_dataset_resumen(
    p_dataset_id bigint -- Id del dataset del que quieres obtener el resumen.
)
returns table (
    total int, -- Cantidad total de muestras que existen en el dataset.
    de_ruta int, -- Cantidad de muestras provenientes de correcioens.
    de_guia int, -- Cantidad de muestras provenientes de guias.
    de_tutorial int, -- Cantidad de muestras provenientes de tutoriales.
    estado public.dataset_estado -- Estado actual del dataset. abierto , exportando , entrenado, fallido.
)
language plpgsql
stable
parallel safe
set search_path = ''
as $$
begin
    return query
    select
        count(*)::int, -- Cuenta todas la filas encontradas.
        count(*) filter ( where m.fuente = 'correccion_ruta' )::int, --
        count(*) filter ( where m.fuente = 'guia_error' )::int,
        count(*) filter ( where m.fuente = 'tutorial' )::int,
        d.estado -- Estado actual del dataset.
    from public.dataset_entrenamiento as d
    left join public.dataset_muestras as m -- Une dos tablas manteniendo siempre la izquierda.
        on m.dataset_id = d.id -- Relaciona dataset_muestras con dataset_entrenamiento.
    where d.id = p_dataset_id
    group by d.estado;
end;
$$;

-- PRUEBA 1 Obtener el resume estadistico de un dataset.
-- Objetivo: Comprobar que la funcion devuvle el total de muestras.
-- Comprobar que clasifica correctamente las muestras por fuente.
-- Comprobar que devuelve el estado actual del dataset.
-- Estado inicial: Dataset 1: sft-word-noviembre.
-- El dataset contiene 4 muestras.
-- 1 muestra proviene de una correcion.
-- 2 muestras provienen de guias.
-- 1 muestra proviene de un tutorial.
-- Estado entrenado.
select '---PRUEBA 1: resumen---' as test;

-- 1 = sft-word-noviembre
select *
from public.fn_dataset_resumen(1);
-- Esperado: total 4. de_ruta q. de guia 2. de tutorial 1. estado entrenado.

select *
from public.fn_dataset_resumen(99);
-- Esperado: cero filas no hay lote 99.

