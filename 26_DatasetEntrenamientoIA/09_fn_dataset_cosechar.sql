-- Recorre automaticamente las correcciones y guias disponibles y las convierte en muestras de entrenamiento.
-- Busca correciones -> Busca guias -> Las convierte en muestras -> Las guarda en dataset_muestras.
create or replace function public.fn_dataset_cosechar(
    p_dataset_id bigint, -- Id del dataset que recibira las muestras.
    p_limite int default 500 -- Maximo de muestras , el dataset solo puede tener 500 muestras.
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_n int := 0; -- Contandor de muestras agegadas correctamente.
    r record; -- Variable temporal que guardara la fila actual que esta recorriendo el for.
begin
    if p_limite is null or p_limite <= 0 then
        raise exception 'limite invalido: %', p_limite;
    end if;

    -- pg_advisory_xact_lock -> Candado temporal de trasaccion. Evita que dos procesos modifiquen simultaneamente el mismo dataset.
    -- hashtext -> Convierte texto en numero.
    perform pg_advisory_xact_lock(hashtext('dataset-cosecha:' || p_dataset_id::text));

    -- Recorre fila por fila el resultado de una consulta.
    -- Toma primera fila -> Ejecuta loop -> Toma seguna fila -> Ejecuta loop -> Siguiente fila.
    -- r -> fila actual , in -> Indica de donde va a venir la informacion que recorrera el For.
    for r in
        select c.id
        from public.ia_correciones_ruta as c
        -- Solo tomar correcciones que aun no han sido usadas para entrenamiento.
        where c.aplicado_a_modelo = false
            -- an not exists -> Pregunta Esta correccion ya esta dentro de este dataset ?.
            -- Si la correcion ya esta dentro del dataset exists = true. not : false no la agrega.
            -- Si la correcion no esta dentro exists = false, not: true La agrega.
            and not exists(
                select 1 from public.dataset_muestras as m
                where m.correccion_id = c.id and m.dataset_id = p_dataset_id
            )
        order by c.created_at -- Procesar primero las mas antiguas.
        -- for update -> bloquea esas filas para que otro proceso no las tome al mismo tiempo.
        --skip locked -> Si una fila ya esta bloqueada , ignorala y pasa a la siguiente.
        for update of c skip locked
        limit p_limite -- Maximo de registros que devuelve la consulta.

    loop -- Codigo que se ejecuta por cada fila del FOR.
        -- Si devuelve el id , Se inserto la correcion actual.
        if public.fn_dataset_agregar_correccion(p_dataset_id, r.id) is not null then
            v_n := v_n + 1; -- Suma 1 al contador de muestras agregadas.
        end if;
    end loop; -- Termina cuando ya no quedan filas.

    for r in
        select g.id
        from public.guias as g
        where g.activa = true
            and jsonb_array_length(g.pasos) > 0 -- La guia debe tener al menos un paso.
            -- Esta guia ya esta en este dataset ?
            -- Si devuelve true ya esta , not false Entonces no la agrega.
            -- Si devuelve false no esta, not true Entonces la agrega.
            and not exists(
                select 1 from public.dataset_muestras as m
                where m.guia_id = g.id and m.dataset_id = p_dataset_id
            )
        order by g.id
        limit p_limite

    loop
        -- Si devuelve el id , Se inserto la guia.
        if public.fn_dataset_agregar_guia(p_dataset_id, r.id) is not null then
            v_n := v_n + 1; -- Suma 1 al contador de muestras agregadas.
        end if;
    end loop;

    return v_n; -- Devuelve cuantas muestras se agregaron al dataset.
end;
$$;

-- PRUEBA 1 : Rechazar un limite invalido. El limite determina la cantidad maxima de registros
-- que pueden procesar cada consulta de cosecha.
-- Estado inicial: Existe el dataset con ID 1. Se intenta ejecutar la funcion con un limite de 0.
-- Accion: Ejecutar fn_dataset_cosechar(1, 0). Captura la excepcion generada por la funcion.
-- Resultado esperado: La funcion rechaza el limite 0. Se muestra en Messages: "Ok limite: limite invalido: 0".
-- No se inicia el proceso de cosecha.
select '--- PRUEBA 1: limite invalido ---' as test;

do $$
begin
    perform public.fn_dataset_agregar_guia(1,0);
    raise exception 'FALLO: acepto limite 0';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK limite: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK limite: limite invalido: 0. <> Revisar esta tengo OK limite: guia 0 no existe o nactiva.

-- PRUEBA 2 Recopilar automaticame las correciones y guias pendientes
-- Objetivo: Comprobar que la funcion identifica los registros que todavia no estan incorporados al
-- dataset y los convierte en muestras de entranamiento.
-- Estado inicial: Existe el dataset con ID 1: sft-word-noviembre.
-- El dataset esta abierto. La correccion 1 ya esta incorporada. La guia 1 ya esta incorporada.
-- El tutorial 1 ya esta incorporado. La guia 3 de Notepad++ esta activa y todavia no esta incorporada.
-- La guia del reloj no tiene pasos y debe quedar excluida.
-- Accion: consultar las muestras existentes antes de la cosecha.
-- Ejecutar fn_dataset_cosecha(1, 500).
-- 2. Consultar el contador de muestras. 3. Ejecutar nuevamente la cosecha para comprobar que no haya duplicado.
select '--- PRUEBA 2: cosechar el resto ---' as test;

-- 1.  Consultar las guias registradas.
select fuente, count(*) as n
from public.dataset_muestras
where dataset_id = 1
group by fuente
order by fuente;
-- Esperado ahora: correcion_ruta 1, guia_error 1, tutorial 1.

-- 1 = sft-word-noviembre. 500 = techo.
select public.fn_dataset_cosechar(1, 500) as agregadas;
-- Esperado: 1. Solo la guia 3 de Notepad++

select guia_id, par_sft->>'prompt' as prompt
from public.dataset_muestras
where dataset_id = 1
    and fuente = 'guia_error'
order by guia_id;
-- Esperado: guia 1 Hypervisor bloqueado. guia 3 Missing files.

select public.fn_dataset_cosechar(1, 500) as otra_vez;
-- Esperado: 0. No queda nada nuevo.
