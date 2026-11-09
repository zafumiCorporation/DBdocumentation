-- Convierte un tutorial en una muestra de entrenamiento
create or replace function public.fn_dataset_agregar_tutorial(
    p_dataset_id bigint, -- Id del dataset donde se guardara la muestra.
    p_tutorial_id bigint -- Id del tutorial que aprendera la IA.
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id bigint; -- Guarda el id de la nueva muestra creada.
    v_titulo text; -- Almacenara el titulo del tutorial.
    v_desc text; --  Almacenara la descripcion del tutorial.
    v_estado public.dataset_estado; -- Almacenara el estado del dataset : abierto , exportando , entrenado, fallido.
begin
    select estado into v_estado
    from public.dataset_entrenamiento
    where id = p_dataset_id;

    if v_estado is distinct from 'abierto' then
        raise exception 'dataset % no esta abierto (estado=%)', p_dataset_id, coalesce(v_estado::text, 'null');
    end if;

    -- titulo: nombre dle tutorial , descripcin : descripcion del tutorial.
    select titulo, descripcion into v_titulo, v_desc
    from public.tutoriales
    where id = p_tutorial_id;

    if v_titulo is null then
        raise exception 'tutorial % no existe', p_tutorial_id;
    end if;

    insert into public.dataset_muestras( -- Crear muestra.
        dataset_id, fuente, tutorial_id, par_sft
    ) values (
        p_dataset_id, -- Dataset destino.
        'tutorial', -- Origen de la muestra.
        p_tutorial_id, -- Tutorial utilizado.
        jsonb_build_object(
            'prompt', v_titulo, -- Entrada para la IA.
            'completion', coalesce(v_desc, v_titulo), -- Respuesta correcta.
            'fuente', 'tutorial', -- Indica que la muestra viene de un tutorial.
            'tutorial_id', p_tutorial_id -- Id del tutorial original.
        )
    )
    on conflict (dataset_id, tutorial_id) where tutorial_id is not null do nothing
    returning id into v_id;

    return v_id; -- Devuelve el id de la muestra creada.
end;
$$;

create unique index if not exists dataset_muestras_tutorial_uniq
on public.dataset_muestras (dataset_id, tutorial_id)
where tutorial_id is not null;

-- PRUEBA 1. Alta de tutorial , El tutorial no tiene descripcion (descripcion = NULL).
-- El tutorial todavia no esta registrado en el dataset.
-- Accion: Ejecutar fn_dataset_agregar_tutorial(1, 1). Consultar la muestra creada.
-- Consultar el contador de muestras del dataset.
-- Resultado esperado: La funcion devuelve el id de la nueva muestra.
-- fuente = 'tutorial'. tutorial_id = 1. prompt = "Create Sheet in Word".
-- completion = "create Sheet in Word", porque la descripcion es null.
-- muestras_count = 3.
select '--- PRUEBA 1: alta de tutorial ---' as test;

-- 1 = sft-word-noviembre. 1 = "Create Sheet in Word", tutoriales.id.
select public.fn_dataset_agregar_tutorial(1,1);
-- Esperado: el id nuevo 6.

select fuente, tutorial_id ,
        par_sft->>'prompt' as prompt,
        par_sft->>'completion' as completion
from public.dataset_muestras
where dataset_id = 1
    and fuente = 'tutorial';
-- Esperado: tutorial_id 1. prompt y completion = Create Sheet in Word.

select muestras_count
from public.dataset_entrenamiento
where id = 1;
-- Esperado: 3.

-- PRUEBA 2: Rechazar tutorial inexistente y evitar duplicados.
-- Existe el dataset con ID 1 y esta abierto. El tutorial con ID 1 ya fue incorporado al dataset.
-- No existe ningun tutorial con ID 999.
-- Accion: Intentar agregar nuevamente el tutorial 1
-- Intentar agregar el tutorial inexistente 999.
-- Resultado esperado: La segunda insercion del tutorial 1 devuelve null.
-- No se crea una segunda muestra del mismo tutorial.
-- El tutorial 999 genera la excepcion: "tutorial 999 no existe". Se muestra en Messages: "OK ausente: tutorial 999 no existe".
select '--- PRUEBA 2: ausente y duplicado ---' as test;

select public.fn_dataset_agregar_tutorial(1,1) as otra_vez;
-- Esperado null.

do $$
begin
    perform public.fn_dataset_agregar_tutorial(1,999);
    raise exception 'FALLO: acepto tutorial 999';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK ausente: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK ausente: tutorial 999 no existe.