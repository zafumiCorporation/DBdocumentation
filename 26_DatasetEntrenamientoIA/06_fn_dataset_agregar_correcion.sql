-- Agrega una correccion como muestra de entrenamiento. Ej: IA propone: Word , Archivo . Usuario corrige : Word > Archivo > Guardar como
drop function fn_dataset_agregar_correccion(bigint, bigint);
create or replace function public.fn_dataset_agregar_correccion(
    p_dataset_id bigint, -- Id del dataset donde se guardara la muestra.
    p_correccion_id bigint -- Id de la correccion a convertir en muestra.
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id bigint; -- Guardara el id de la muestra creada.
    v_c public.ia_correciones_ruta%ROWTYPE; -- Crea una variable con exactamente las mismas columnas de una tabla.
    v_estado public.dataset_estado; -- Estado actual del dataset: abierto, exportando , entrenado, fallido.
begin
    select estado into v_estado -- Obtiene el estado.
    from public.dataset_entrenamiento
    where id = p_dataset_id;

    if v_estado is null then
        raise exception 'dataset % no existe', p_dataset_id;
    end if;

    -- abierto unico estado que permite abrir muestras.
    if v_estado <> 'abierto' then
        raise exception 'dataset % no esta abierto (estado=%)', p_dataset_id, v_estado;
    end if;

    -- Una fila con todos las columnas
    select * into v_c
    from public.ia_correciones_ruta
    where id = p_correccion_id; -- Segun el id de la correccion.

    if not found then
        raise exception 'correccion % no existe', p_correccion_id;
    end if;

    insert into public.dataset_muestras(
        dataset_id, fuente, correccion_id, par_sft
    ) values (
        p_dataset_id,
        'correccion_ruta',
        p_correccion_id,
        jsonb_build_object(
            -- prompt: entrada para la IA , ruta_ia: solucion propuesta por la IA
            'prompt', coalesce(v_c.ruta_ia, v_c.uia_ia, ''),
            -- completion: respuesta correcta -> correccion realizada por el usuario.
            'completion', coalesce(v_c.ruta_usuario, v_c.uia_usuario, ''),
            'fuente', 'correccion_ruta',
            'tutorial_id', v_c.tutorial_id
        )
    )

    on conflict (dataset_id, correccion_id) where correccion_id is not null do nothing
    returning  id into v_id;

    return v_id;
end;
$$;

-- Necesario para prueba 2.
create unique index on public.dataset_muestras (dataset_id, correccion_id);

-- PRUEBA 1: el dataset se ecuentra en estado abierto. Existe la correcion 1 en ia_correciones_ruta.
-- El datase todavia no contiene muestras.
-- Accion: Agregar la correcion 1 al dataset 1.
-- Resultado esperado: Se crea una fila en dataset_muestras, correccion_id = 1.
-- prompt = insertar -> pagina-en-blanco.
-- completion = pagina-en-blanco -> insertar.
-- muestras_count aumenta a 1.
select '--- PRUEBA 1: alta de correccion ---' as test;

select id
from public.dataset_muestras
where dataset_id = 1;
-- Esperado ahora: cero filas.

-- 1 = sft-word-noviembre, dataset_entrenamiento.id.
-- 1 = ia_correciones_ruta.id. tutorial_id 1, usuario_id 1 Shiriaru.
-- ruta_ia = insertar -> pagina-en-blanco. ruta_usuario = pagina-en-blanco -> insertar.
select public.fn_dataset_agregar_correccion(1,1);
-- Esperado: el id nuevo. con muestras vacias, es 2. -- Verficar por que dio id 2.

select fuente, correccion_id, guia_id, tutorial_id,
        par_sft->>'prompt' as prompt,
        par_sft->>'completion' as completion
from public.dataset_muestras
where id = 2;
-- Esperado: fuente correcion_ruta. correccion_id 1. guia_id null. tutorial_id null.
-- prompt = insertar -> pagina-en-blanco.
-- completion = pagina-en-blanco -> insertar.

select muestras_count
from public.dataset_entrenamiento
where id = 1;
-- Esperado: 1.

-- PRUEBA 2. Impedir correciones duplicadas y rechazar correciones inexistentes.
-- La misma correcion no duplica. un id que no existe no se cae.
-- Accion: 1. Intentar agregar nuevamente la correcion 1.
-- 2. Intantar agregar la correccion inexistente 999.
select '--- PRUEBA 2: duplicada y ausente ---' as test ;

select public.fn_dataset_agregar_correccion(1,1) as otra_vez;
-- Esperado: null. on conflict do nothing.

select count(*) as filas
from public.dataset_muestras
where dataset_id = 1
    and correccion_id = 1;
-- Esperado: 1.

do $$
begin
    perform public.fn_dataset_agregar_correccion(1, 999);
    raise exception 'FALLO: acepto correccion 999';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK ausente: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK ausente: correccion 999 no existe.

-- PRUEBA 3: Impedir agregar muestras a datasets inexistentes.
-- Estado Inicial : Existe el dataset 1.
-- No existe el dataset 99.
-- La correcion 1 existe.
-- Accion: Intentar agregar la correcion 1 al dataset 99.
-- Resultado esperado: Se lanza la excepcion: 'dataset 99 no existe'.
-- No se crea ninguna muestra. El dataset original permanece intacto.
select '--- PRUEBA 3: dataset inexistente ---' as test;

do $$
begin
    perform public.fn_dataset_agregar_correccion(99, 1);
    raise exception 'FALLO: acepto dataset 99';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK dataset: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK dataset: dataset 99 no existe.