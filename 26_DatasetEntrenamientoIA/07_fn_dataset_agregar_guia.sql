-- Convierte un guia en una muestra de entrenamiento para la IA. Ej: Error Hyper-V con pasos Activar Hyper-V > Reiniciar > Crear VM
create or replace function public.fn_dataset_agregar_guia(
    p_dataset_id bigint, -- Id del dataset donde se guardara la muestra.
    p_guia_id bigint --  Id de la guia que aprendera la IA.
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id bigint; -- Id de la nueva muestra creada.
    v_g public.guias%rowtype; -- Crea una variable con todas las columnas de una fila.
    v_titulo_error text; -- Almacenara el nombre del error que resuelve la guia.
    v_estado public.dataset_estado; -- Estado actual del dataset Ej: abierto , exportando , entrenado , fallido
begin
    select estado into v_estado
    from public.dataset_entrenamiento
    where id = p_dataset_id; -- Id del dataset donde se guarda la muestra.

    if v_estado is distinct from 'abierto' then
        raise exception 'dataset % no esta abierto (estado=%)', p_dataset_id, coalesce(v_estado::text, 'null');
    end if;

    select * into v_g -- Guarda una fila con los campos de la tabla guias.
    from public.guias
    where id = p_guia_id
        and activa = true;

    if not found then
        raise exception 'guia % no existe o inactiva', p_guia_id;
    end if;

    -- titulo_patron : Nombre base del error.
    select te.titulo_patron into v_titulo_error
    from public.tipos_error as te
    where te.id = v_g.tipo_error_id;

    insert into public.dataset_muestras( -- Registra la muestra.
        dataset_id, fuente, guia_id, par_sft
    ) values (
        p_dataset_id, -- Dataset donde se guardara.
        'guia_error', -- Origne de la muestra.
        p_guia_id, -- Guia utilizada.
        jsonb_build_object(
            'prompt', coalesce(v_titulo_error, v_g.titulo), -- Entrada que vera la IA.
            'completion', coalesce(v_g.pasos, '[]'::jsonb), -- Respuesta correcta.
            'fuente', 'guia_error', -- Indica que proviene de una guia.
            'tutorial_id', v_g.tutorial_id -- Referencia al tutorial asociado a la guia.
        )
    )
    on conflict (dataset_id, guia_id) where guia_id is not null do nothing
    returning id into v_id;

    return v_id; -- Devuelve el id de la muestra creada.
end;
$$;

create unique index if not exists dataset_muestras_dataset_guia_uniq
on public.dataset_muestras (dataset_id, guia_id)
where guia_id is not null;

-- PRUEBA 1: Registrar una guia activa como muestra de entrenamiento.
-- Objetivo: Comprobar que la funcion puede incorporar una guia existente y activa al dataset.
-- construyendo correctamente el contenido de entrenamiento.
-- Estado inicial: Existe el dataset con ID 1 y su esta es 'abierto'.
-- Existe la guia con ID 1: "Activar Hyper-V". La guia esta activa.
-- El error asociado tiene como titulo_patron: "Hypervisor bloqueado".
-- Accion: Ejecuta fn_dataset_agregar_guia(1,1).
-- muestras_count aumenta a 2.
select '--- PRUEBA 1: alta de guia---' as test;

-- 1  = sft-word-noviembre. 1 = guia "Activar Hyper-V", guias.id.
-- tipo_error hyperv-hypervisor-bloqueado. titulo_patron = Hypervisor bloqueado.
select public.fn_dataset_agregar_guia(1,1);
-- Esperado: el id nuevo. 4, si la correcion ya esta.

select fuente, guia_id,
       par_sft->>'prompt' as prompt,
       par_sft->>'fuente' as fuente_json,
       jsonb_typeof(par_sft->'completion') as tipo_completion
from public.dataset_muestras
where dataset_id = 1
    and guia_id = 1;
-- Esperado: fuente guia_error. prompt = Hypervisor bloqueado.
-- fuente_json = guia_error. tipo_completion = array. son los dos pasos.

select muestras_count
from public.dataset_entrenamiento
where id = 1;
-- Esperado: 2.

-- PRUEBA 2: Rechazar una guia inactiva. Existe una guia con ID 3: "Reinstalar Notepad++ portable"
-- la guia inicialmente esta activa.
-- Accion: Cambiar activa a false. Intentar agregar la guia 3 al dataset 1.
-- Capturar la excepcion generada por la funcion. Restaurar activa a true.
-- Consultar si se registro alguna muestra de esa guia.
-- Resultado esperado: Se muestra mensaje : "OK inactiva: guia 3 no existe o inactiva"
-- La guia vuelve a quedar activa . La consulta final devuelve 0 filas.
select '--- PRUEBA 2: guia inactiva---' as test;

update public.guias
set activa = false
where id = 3;
-- 3 = "Reinstalar Notepad++ portable".

do $$
begin
    perform public.fn_dataset_agregar_guia(1, 3);
    raise exception 'FALLO: acepto guia inactiva';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK inactiva: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK inactiva: guia 3 no existe o inactiva.

update public.guias
set activa = true
where id = 3;

select count(*) as filas
from public.dataset_muestras
where guia_id = 3;
-- Esperado: 0,