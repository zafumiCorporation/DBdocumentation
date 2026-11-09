-- Registra que un usuario vio un tutorial.
-- 1. Verifica que exista la particion del mes. 2. Determina si la vista cuenta como unica.
-- 3. Guarda la vista. 4. Actualiza el historial del usuario.
-- 5. Devuelve el id de la vista registrada.
create or replace function public.fn_registrar_vista(
    p_yo bigint, -- Id del usuario que vio el tutorial.
    p_tutorial_id bigint, -- Id del tutorial visualizado.
    p_origen public.vista_origen default 'feed', -- Indica desde donde llego el usuario al tutorial.
    p_paso smallint default 1 -- Paso maximo alcanzado por el usuario dentro del tutorial.
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id bigint; -- Id de la vista recien registrada.
    v_unica boolean; -- Indica si esta vista cuenta como vista unica. True: vistas_count aumenta. False: vistas_count No aumenta.
    v_desde timestamptz; -- Inicio de la ventana de 30 minutos que se utilizara para validar vistas unicas.
begin
    -- Verifica si existe la particion correspondiente al mes actual.
    perform public.fn_asegurar_particion_vistas(now());

    -- date_bin -> Agrupa fechas en bloques de tiempo. Recibe: (tamano_bloque, fecha, fecha_base)
    -- tamano del bloque: Cada bloque dura 30 minutos.
    v_desde := date_bin('30 minutes', now(), timestamptz '2000-01-01');

    -- Determina si la vista es unica dentro de la ventana de 30 minutos
    -- v_unica = false , no aumenta el contador. v_unica = true , Si aumenta el contador.
    v_unica := not exists(
        select 1
        from public.tutorial_vistas as v
        where v.usuario_id = p_yo
            and v.tutorial_id = p_tutorial_id
            and v.cuenta_unica = true
            and v.visto_en >= v_desde
            and v.visto_en < v_desde + interval '30 minutes'
    );

    -- Registra la vista
    insert into public.tutorial_vistas(
        usuario_id, tutorial_id, origen, cuenta_unica, visto_en
    ) values (
        -- Usuario que visualizo , tutorial visualizado, origen de la vista, fecha y hora de la vista.
        p_yo, p_tutorial_id, p_origen, v_unica, now()
    )
    returning id into v_id; -- Guarda el id generado de la vista.

    -- Guarda el progreso del usuario dentro del tutorial.
    INSERT INTO public.historial_visualizaciones (
        usuario_id, tutorial_id, paso_max_alcanzado, ultima_vez_en
    ) values (
        p_yo, p_tutorial_id, greatest(p_paso, 1::smallint), now()
    )
    on conflict on constraint uq_historial_usuario_tutorial do update set
        paso_max_alcanzado = greatest(
            public.historial_visualizaciones.paso_max_alcanzado,
            excluded.paso_max_alcanzado
        ),
        ultima_vez_en = now();

    return v_id; -- Id de la nueva vista registrada.
end;
$$;

-- PRUEBA 1: registrar la primera vista unica. Cuando Shiriaru abre el tutorial Word desde el feed
-- La visualizacion cuenta como unica. Aumenta el contador vistas_count del tutorial.
-- Se actualiza el progreso de Shiriaru del paso 3 al paso 4. Se conserva completado = true.
-- Accion: Registrar una vista desde el feed, indicando que Shiriaru alcanzo el paso 4.
-- Resultado esperado: Se registra una nueva fila en tutorial_vistas. cuentra_unica = true.
-- origen = feed. Se devuelve el id de la nueva visualizacion.
-- La vista se almacena en tutorial_vistas_202611. vistas_count aumenta a 1.
-- paso_max_alcanzado cambia a 4. completado permanece en true.

select '--- PRUEBA 1: primera vista unica ---' as test;

select vistas_count
from public.tutoriales
where id = 1;
-- Esperado ahora: 0.
-- 1 = "Create Sheet in Word", tutoriales.id.

select paso_max_alcanzado, completado
from public.historial_visualizaciones
where usuario_id = 1
    and tutorial_id = 1;
-- Esperado ahora: paso 3, completado true.
-- 1 = Shiriaru, usuarios.id.

-- 1 = Shiriaru. 1 = Word. feed = vista_origen. 4 = paso.
select public.fn_registrar_vista(1,1, 'feed', 4::smallint);
-- Esperado: el id nuevo. Con la tabla vacia, es 1.

select usuario_id, tutorial_id, origen, cuenta_unica
from public.tutorial_vistas
where id = 1;
-- Esperado: usuario 1, tutorial 1, origen feed, cuenta_unica true.

select c.relname as particion
from public.tutorial_vistas v
join pg_class c on c.oid = v.tableoid
where v.id = 1;
-- Esperado: tutorial_vistas_202611

select vistas_count
from public.tutoriales
where id = 1;
-- Esperado: 1.

select paso_max_alcanzado, completado
from public.historial_visualizaciones
where usuario_id = 1
    and tutorial_id = 1;
-- Esperado: paso 4. completado sigue true. on conflict no lo apaga.

-- PRUEBA 2: Evitar contar visualizaciones repetidas en el mismo intervalo.
-- Objetivo: Verificar que fn_registrar_vista(). Registre nuevas visualizaciones sin contabilizarlas.
-- nuevamente como vistas unicas dentro del mismo bloque.
-- Estado inicial: Shiriaru ya tiene una vista unica del tutorial Word.
-- Accion: Registrar nuevamente el tutorial Word desde overlay, indicando el paso 1.
-- Resultado esperado: Se registra una segunda fila en tutorial_vistas.
-- Se devuelve un nuevo id de visualizacion. origen = overlay. cuenta_unica = false.
-- vistas_count permanece en 1. paso_max_alcanzado permanece en 4.
select '--- PRUEBA 2: segunda vista en el mismo cubo ---' as test;

-- 1 = Shiriaru. 1 = Word. overlay = el play interactivo. 1 no puede bajar el paso.
select public.fn_registrar_vista(1, 1, 'overlay', 1::smallint);
-- Esperado: id 2.

select id , origen, cuenta_unica
from public.tutorial_vistas
where usuario_id = 1
    and tutorial_id = 1
order by id;
-- Esperado: id 1 feed true. id 2 overlay false.

select vistas_count
from public.tutoriales
where id = 1;
-- Esperado: 1. La segunda no suma. Verificar bien esta por que si sumo me dio 2.

select paso_max_alcanzado
from public.historial_visualizaciones
where usuario_id = 1
    and tutorial_id = 1;
-- Esperado: 4. greates(4, 1) se queda.

-- PRUEBA 3. Sebastian no tenia historial. Su vista es unica y crea la fila.
-- Accion: Registrar una visualizacion desde busqueda, indicando que Sebastian alcanzo el paso 2.
-- Resultado: Se registra un nueva fila en tutorial_vistas. cuenta_unica = true.
-- origen = busqueda. Se crea una nueva fila en historial_visualizaciones. paso_max_alcanzado = 2.
-- completado = false. vistas_count aumenta a 2.

select '--- PRUEBA 3: primer watch de Sebastian ---' as test;

select id
from public.historial_visualizaciones
where usuario_id = 3
    and tutorial_id = 1;
-- Esperado ahora: cero filas.

-- 3 = Sebastian. 1 = Word. busqueda. paso 2.
select public.fn_registrar_vista(3,1, 'busqueda', 2::smallint);

select cuenta_unica, origen
from public.tutorial_vistas
where usuario_id = 3
    and tutorial_id = 1;
-- Esperado: cuenta_unica true. origen busqueda.

select vistas_count
from public.tutoriales
where id =1;
-- Esperado: 2.

select paso_max_alcanzado, completado
from public.historial_visualizaciones
where usuario_id = 3
    and tutorial_id = 1;
-- Esperado: paso 2. completado false. Es alta, no upsert.