create or replace function public.fn_marcar_script_verificado(
    p_tutorial_id bigint,
    p_version int
)
returns void
language plpgsql
set search_path = ''
as $$
begin
    update public.tutorial_scripts
    set verificado = true,
        verificado_en = now()
    where tutorial_id = p_tutorial_id
    and version = p_version;
end;
$$;

-- PRUEBA 1 Aprobar una version compilada del tutorial.
-- Objetivo: Verificar que fn_marcar_script_verificado() marque una
-- version concreta del script como valida para ejecucion.
-- Estado Inicial: Existe una version compilada, verificada = false.
-- Accion: Ejecutar fn_marcar_script_verificado().
-- Resultado esperado: verificado cambia a true. verificado_en recibe fecha y hora.
-- Nota: Un script verificado se considera apto para ser ejecutado
-- por los usuarios finales mendiante el boton play.
select '--- PRUEBA 1: marcar script verificado ---' as test;

-- Dejo la version 1 en falso para que la funcion tenga algo que prender
-- 1 = "Create Sheet in Word", tutoriales.id. version 1 = La que acabo de compilar.
update public.tutorial_scripts
set verificado = false,
    verificado_en = null
where tutorial_id = 1
    and version = 1;

select version, verificado, verificado_en
from public.tutorial_scripts
where tutorial_id = 1
  and version = 1;
-- Esperado ahora: verificado false, verificado_en null.

-- 1 = "Create Sheet in Word", tutoriales.id.
-- 1 = version del script, tutorial_scripts.version.
select public.fn_marcar_script_verificado(1, 1);

-- Linea 36
-- Esperado: verificado true, verificado_en con fecha.

create or replace function public.fn_iniciar_ejecucion(
    p_yo bigint, -- Usuario que queire ejecutar el tutorial.
    p_tutorial_id bigint -- El tutorial a ejecutar
)
returns bigint
language plpgsql
set search_path = ''
as $$
declare
    v_ver int; -- Guarda la version del script que se va a ejecutar
    v_exec bigint; -- Guarda el id de la ejecucion creada.
begin

    -- Busca la ultima version del script.
    select version into v_ver
    from public.tutorial_scripts
    where tutorial_id = p_tutorial_id
    and verificado = true
    order by version desc limit 1;

    -- Verifica que exista un script.
    if v_ver is null then
        raise exception 'No hay script verificado';
    end if;

    -- Crea un registro indicando que alguien comenzo el tutorial.
    insert into public.tutorial_ejecuciones(
        tutorial_id, script_version, usuario_id, estado, paso_actual
    ) values (p_tutorial_id, v_ver, p_yo, 'iniciado', 1)
    returning id into v_exec;

    return v_exec;
end;
$$;

-- PRUEBA 2 Ejecutar un tutorial hasta completarlo correctamente.
-- Objetivo: Verificar que un usuario pueda iniciar una ejecucion y completar todos los pasos del tutorial.
-- Estado inicial: Existe un script verificado, No existen ejeuciones activas.
-- Acccion: Sebastian inicia el tutorial , 2. Completa el paso 1. , 3. Completa el paso 2.
-- Resultado esperado: Se crea una ejecucion nueva. El estado pasa por: iniciado, en_progreso, completado
-- finished at recibe fecha
select '--- PRUEBA 2: play hasta completar ---' as test;

select id, estado
from public.tutorial_ejecuciones
where tutorial_id = 1;
-- Esperado ahora: cero filas.

-- 3 = Sebastian, usuarios.id. El puede ejecutar un tutorial de Shiriraru
-- 1 = "Create Sheet in Word", tutoriales.id.
select public.fn_iniciar_ejecucion(3,1);
-- Esperado: el id nuevo. Con la tabla vacia, es 1.

select id, tutorial_id, script_version, usuario_id, estado, paso_actual, finished_at
from public.tutorial_ejecuciones
where tutorial_id = 1
    and usuario_id = 3
order by id;
-- Esperado: una fila. script_version 1. esta iniciado. paso_actual 1. finished_at null.

-- El subquery es la ejecucion abierta de Sebastian.
-- 3 = Sebastian, usuarios.id
-- true = el paso si se hizo. El cuarto argumento no hace falta
select public.fn_avanzar_paso(
    (select e.id
     from public.tutorial_ejecuciones as e
     where e.usuario_id = 3
       and e.tutorial_id = 1
       and e.estado in ('iniciado', 'en_progreso')
     order by e.id desc
     limit 1),
    3,
    true
);
-- Esperado: 2. Todavia no pasa el total de 2 pasos.

select estado, paso_actual, finished_at, error_selector
from public.tutorial_ejecuciones
where usuario_id = 3
    and tutorial_id = 1
    and estado in ('iniciado', 'en_progreso');
-- Esperado: estado en_progreso, paso_actual 2, finished_at null, error_selector null.

-- Segundo avance. 3 = Sebastian. true = el utlimo paso tambien salio. Linea 112
-- Esperado: 3. La funcion suma 1 y, como 3 ya es mayor que los 2 pasos, cierra la ejecucion.

select estado, paso_actual, finished_at is not null as termino
from public.tutorial_ejecuciones
where usuario_id = 3
    and tutorial_id = 1
order by id;
-- Esperado: estado completado, paso_actul 3, termino true.

create or replace function public.fn_avanzar_paso(
    p_exec_id bigint, -- Id de la ejecucion actual.
    p_yo bigint, -- Id del usuario que esta ejecutando el tutorial.
    p_exito boolean, -- Indica si el paso se completo correctamente.
    p_error_selector text default null -- Es un mensaje error.
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_next int;
    v_total int; -- v_total -> La cantidad de pasos del tutorial.
begin
    update public.tutorial_ejecuciones -- Actualizar la ejecucion.
    set estado = 'en_progreso',
    -- Si p_exito es true , suma 1. si p_exito = false , suma 0
    paso_actual = paso_actual + case when p_exito then 1 else 0 end,
    -- Si p_exito es false , Guarda el error.
    error_selector = case when not p_exito then p_error_selector else null end
    where id = p_exec_id -- Busca la ejecucion
        and usuario_id = p_yo
        and estado in ('iniciado', 'en_progreso')
    returning paso_actual into v_next;

    -- No encontro ninguna fila.
    if not found then
        raise exception 'Ejecucion no encontrada o ya terminada';
    end if;


    select jsonb_array_length(ts.cuerpo_script) into v_total
    from public.tutorial_scripts ts
    join public.tutorial_ejecuciones as te
        on te.tutorial_id = ts.tutorial_id
        and te.script_version = ts.version
    where te.id = p_exec_id;

    if p_exito and v_next > v_total then
        update public.tutorial_ejecuciones
        set estado = 'completado',
            finished_at = now()
            where id = p_exec_id;
    elsif not p_exito then
        update public.tutorial_ejecuciones
        set estado = 'fallido',
            finished_at = now()
        where id = p_exec_id;
    end if;

    return v_next;
end;
$$;

-- PRUEBA 3 Finalizar una ejecucion por error
-- Objetivo: Verificar que el sistema registre correctamente , Cuando un usuario no puede completar un paso.
-- Estado inicial : Existe un script verificado, Se inicia una nueva ejecucion.
-- Accion: El primer paso falla por que el control esperado no puede localizarse.
-- Resultado esperado: El paso actual no avanza. Se guarda el selector que produjo el error.
-- El estado cambia a fallido. finished_at rechice fecha
-- Nota: esta prueba simula un tutorial real desde la interfaz.
select '--- PRUEBA 3: play fallido ---' as test;

-- 3 = Sebastina, usuarios.id 1 = "Create Sheet in Word", tutoriales.id.
select public.fn_iniciar_ejecucion(3,1);
-- Esperado: el id nuevo. Si la prueba 2 uso el 1 este es el 2.

select id, estado, paso_actual
from public.tutorial_ejecuciones
where usuario_id = 3
    and tutorial_id = 1
    and estado = 'iniciado';
-- Esperado ahora: una fila, estao iniciado, paso_actual 1

-- 3 = Sebastian. false = el paso no se pudo hacer.
-- 'BlanckPage' = el selector que fallo. Queda en error_selecto.
select public.fn_avanzar_paso(
    (select e.id
     from public.tutorial_ejecuciones as e
     where e.usuario_id = 3
       and e.tutorial_id = 1
       and e.estado = 'iniciado'
     order by e.id desc
     limit 1),
     3,
     false,
     'BlankPage'
);
-- EsperaoL 1. Un fallo no suma el paso.

select id, estado, paso_actual, error_selector, finished_at is not null as termino
from public.tutorial_ejecuciones
where usuario_id = 3
  and tutorial_id = 1
order by id;
-- Esperado: dos filas.
-- La primera sigue completado, paso_actual 3.
-- La segunda: esta fallido, paso_actual 1, error_selector BlankPage, termino true.