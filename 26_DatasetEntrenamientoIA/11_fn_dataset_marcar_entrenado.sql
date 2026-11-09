-- Finaliza el ciclo del dataset .
-- 1. Bloque el dataset. 2. Marca el dataset como entrenado. 3. Marca correcciones como usadas por el modelo.
-- 4. Actualiza estadisticas de tutoriales. 5. Envia una notificacion. 6. Devuelve cuantas correcciones fueron marcadas.
create or replace function public.fn_dataset_marcar_entrenado(
    p_dataset_id bigint -- Id del dataset que contiene las muestras.
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_n int; -- Almacenara la cantidad de correciones que fueron marcadas como aplicado_a_modelo = true.
begin
    perform pg_advisory_xact_lock(hashtext('dataset-train:' || p_dataset_id::text));

    -- Marcar dataset entrenado
    update public.dataset_entrenamiento
    set estado = 'entrenado', -- Indica este dataset ya fue consumido por el entrenamiento.
        entrenado_en = now(), -- Fecha y hora del entrenamiento.
        updated_at = now()
    where id = p_dataset_id -- Solo actualiza ese dataset.
        and estado in ('abierto', 'exportando'); -- Solo puede marcarse como entrenado si estaba 'abierto' o 'exportando'

    if not found then
        raise exception 'dataset % no se puede marcar entrenado (no existe o ya entrenado/fallido)', p_dataset_id;
    end if;

    -- Marcar correciones usadas por el modelo.
    update public.ia_correciones_ruta as c
    set aplicado_a_modelo = true -- Indica esta correccion ya fue utilizada para entrenamiento.
    from public.dataset_muestras as m
    where m.dataset_id = p_dataset_id -- Solo toma muestras de este dataset.
        and m.correccion_id = c.id -- Relaciona la muestra con la correcion.
        and c.aplicado_a_modelo = false; -- Solo marca las que todavia no estaban marcadas.

    -- Cantidad de filas afectadas por el Update Ej: 25 correciones actualizadas.
    get diagnostics v_n = row_count;

    update public.tutoriales as t
    -- muestras_entrenamiento : Contador de cuantas muestras provenientes de ese tutorial han sido usadas para entrenar.
    set muestras_entrenamiento = t.muestras_entrenamiento + s.n,
        -- Indica que ese tutorial ya forma parte de algun dataset de entrenamiento.
        es_based_dataset = true
    from (
        select x.tutorial_id, count(*)::int as n -- Cuantas veces aparecio un tutorial.
        from (
            -- Tutorial asociado a una correcion.  Ej: correcion 100 > Tutorial 15
            select c.tutorial_id
            from public.dataset_muestras as m
            join public.ia_correciones_ruta as c
                on c.id = m.correccion_id
            where m.dataset_id = p_dataset_id

            union all

            -- Tutorial asociado a una guia. Ej: Guia Hyper-V > Tutorial Hyper-V
            select g.tutorial_id
            from public.dataset_muestras as m
            join public.guias as g
                on g.id = m.guia_id
            where m.dataset_id = p_dataset_id
                and g.tutorial_id is not null

            union all

            -- Tutorial que fue agregado directamente
            select m.tutorial_id
            from public.dataset_muestras as m
            where m.dataset_id = p_dataset_id
                and m.tutorial_id is not null
        -- x Consulta temporal
        -- Estructura: tutorial_id. Ej: Primera consulta : 15 , 20 , 30
        ) as x
        where x.tutorial_id is not null
        group by x.tutorial_id -- Agrupa registros del mismo tutorial.
    -- s Consulta temporal
    -- Estructura : tutorial_id :
    -- n : Cuantas muestras estan asociadas a ese tutorial. Ej: tutorial 10 aparece 5 veces , n = 5
    ) as s
    -- t : tabla tutoriales ,
    where t.id = s.tutorial_id;

    insert into public.notificaciones (usuario_id, actor_id, tipo, payload)
    -- creador_id es solo el usuario que creo el dataset.
    -- actor_id sistema
    -- tipo notificacion que indica que el dataset termino su proceso.
    select d.creador_id, 0, 'dataset_listo',
        jsonb_build_object('dataset_id', d.id, 'muestras', d.muestras_count)
    from public.dataset_entrenamiento as d
    where d.id = p_dataset_id
        and d.creador_id <> 0;

    return v_n; -- Total de correcciones marcadas por el modelo .
end;
$$;

-- PRUEBA 1. El lote se cierra y se actualiza los registros relacionados.
-- Estado inicial: Dataset 1: estado exportando. Correcion 1: aplicado_a_modelo = false.
-- Tutorial 1: es_based_dataset = false, muestras_entranamiento = 0.
-- Tutorial 4: no esta incluido en el dataset. Dataset 1: tiene 4 muestras y creador_id = 1.
-- Accion: ejecutar fn_dataset_marcar_entrenado(1).
-- Resultado esperado: La funcion devuelve 1. El dataset queda en estado entrenado.
-- entrenado_en contiene una fecha. La correcion 1 queda con aplicado_a_modelo = true.
-- El tutorial 1 queda con es_based_dataset = true y muestras_entranamiento = 3.
-- El tutorial 4 permanece sin modificaciones.
-- Se genera una notificacion dataset_listo para el usuario 1.

select '--- PRUEBA 1: marcar entrenado ---' as test;

select aplicado_a_modelo
from public.ia_correciones_ruta
where id = 1;
-- Esperado ahora: false.

select es_based_dataset, muestras_entrenamiento
from public.tutoriales
where id = 1;
-- Esperado ahora: false, 0.

-- 1 = sft-word-noviembre. creador_id 1, asi que hay notificacion.
select public.fn_dataset_marcar_entrenado(1) as correciones_marcadas;
-- Esperado: 1. Solo habia una correcion en el lote.

select estado, entrenado_en is not null as tiene_fecha
from public.dataset_entrenamiento
where id = 1;
-- Esperado: entrenado. tiene_fecha true.

-- Linea 111
-- Esperado: true.

select es_based_dataset, muestras_entrenamiento
from public.tutoriales
where id = 1;
-- Esperado: es_based_dataset true. muestras_entrenamiento 3.
-- 1 de la correcion, 1 de la guia Hyper-V, 1 del tutorial directo.

select es_based_dataset, muestras_entrenamiento
from public.tutoriales
where id = 4;
-- Esperado: false, 0. EL Unreal no estaba en el lote.

select tipo::text, actor_id, payload
from public.notificaciones
where usuario_id = 1
    and tipo = 'dataset_listo'
order by id desc
limit 1;
-- Esperado: dataset_listo. actor_id 0. payload dataset_id 1, muestras 4.

-- PRUEBA 2. Un dataset que ya esta entrenado no puede volver a finalizarse.
-- Comprobar que la funcion rechaza un dataset cuyo estado ya es entrenado.
-- Comprobar que se genera la excepcion correpondiente.
-- Comprobar que el bloque DO captura el error esperado.
-- Estado inicial: Dataset 1: estado entrenado.
-- El dataset ya fue procesado mediante la prueba 1.
-- Accion: Ejecutar nuevamente fn_dataset_marcar_entrenado(1).
-- Resultado esperado: El update del dataset no modifica ninguna fila.
-- Found queda en false. La funcion genera una excepcion y muestra un mensaje NOTICE.
-- No se vuelve a ejcutar la actualizacion de correciones, tutoriales ni la insercion de notificaciones.
select '--- PRUEBA 2: ya entrenado ---' as test;

do $$
begin
    perform public.fn_dataset_marcar_entrenado(1);
    raise exception 'FALLO:  reentreno el lote';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK ya cerrado: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK ya cerrado: dataset 1 no se puede marcar entrenado (no existe o ya entrenado/fallido)