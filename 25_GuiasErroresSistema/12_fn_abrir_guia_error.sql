-- fn_abrir_guia_error -> Intenta abrir una solucion para un error. Interara responder:
-- Existe una guia?  , Tiene tutoriales ? , Tiene pasos IA? , Puede ejecutarse ?
-- Faltan permisos ?
create or replace function public.fn_abrir_guia_error(
    p_yo bigint, -- Id del usuario que quiere abrir la solucion.
    p_tipo_error_id bigint -- Id del error que queremos resolver.
)
returns table (
    ok boolean, -- Puede abrir la solucion ?
    tutorial_id bigint, -- Id del tutorial que resuelve el error.
    pasos jsonb, -- Pasos para resolver el error.
    motivo text -- Por que respondio lo que respondio.
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tut bigint; -- Id del tutorial que resuelve el problema
    v_pasos jsonb; -- Los pasos de la guia.
    v_activa boolean; -- true o false si la guia esta activa.
begin
    -- Trae la guia del error.
    select g.tutorial_id, g.pasos, g.activa
    into v_tut, v_pasos, v_activa
    from public.guias as g
    where g.tipo_error_id = p_tipo_error_id
      and g.activa = true
    limit 1;

    if not FOUND then -- Si no encontro filas.
        return query select
            -- ok: false -> No existe solucion registrada.
            false, null::bigint, null::jsonb,
            'no hay guia; la iA debe upsert pasos con fn_guia_upsert'::text;
        return;
    end if;

    -- Caso 2: Existe tutorial. La guia tiene tutorial.
    if v_tut is not null then
        -- Tiene permisos para overlay_neon o puede ejecutar_tutoriales. Si falta alguno.
        if not public.fn_consentimiento_vigente(p_yo, 'overlay_neon')
            or not public.fn_consentimiento_vigente(p_yo, 'ejecucion_tutorial') then
             return query select
                -- ok -> false No puede abrir la guia por que faltan permisos.
                 false, v_tut, v_pasos,
                 'concede overlay_neon y ejecucion_tutorial antes de Play'::text;
        end if;

        -- Se agrego esto para que la prueba 2 funcionara verificar.
        begin
            -- Si tiene permisos crea el estado (sesion activa) en overlay_sesion_ram. Ya inicio el tutorial.
            perform public.fn_overlay_iniciar(p_yo, v_tut, null, null, null);
        exception when others then
            return query select
                false, v_tut, v_pasos,
                sqlerrm::text;
            return;
        end;

        return query select
            -- true puede abrir la guia
            true, v_tut, v_pasos,
            'play tutorial de la guia'::text;
        return;
    end if;

    -- Caso 3 No hay tutorial
    if not public.fn_consentimiento_vigente(p_yo , 'overlay_neon') then
        return query select
            -- false no puede abrir la guia faltan permisos y tutorial.
            false, null::bigint, v_pasos,
            'concede overlay_neon para pasos IA'::text;
        return;
    end if;

    -- Caso 4 No hay tutorial pero si permisos.
    return query select
        -- true puede abrir la guia.
        true, null::bigint, v_pasos,
        'overlay pasos de guia'::text;
end;
$$;

-- PRUEBA 1: Error sin guia registrada.
-- Usuario: Shiriaru, usuarios.id = 1, Error: overlay_boton_ausente
-- Operacion: Ejecutar fn_abrir_guia_error() utilizando el ID obtenido mediante una subconsulta
-- sobre public.tipos_error.
-- Comportamiento Esperado: No encuentra una guia activa. Found queda false.
-- Devuelve ok = false , tutorial_id = null , pasos = null. Indica que debe registrarse una solucion.

select *
from public.fn_abrir_guia_error(
    1,
    (select id from public.tipos_error where slug = 'overlay-boton-ausente')
);

-- PRUEBA 2: Guia con tutorial y usuario sin permisos
-- 1 = Shiriaru, usuarios.id , Error: hyperv-hypervisor-bloqueado
-- Estado: Existe una guia activa. La guia tiene tutorial_id = 1. La guia contiene dos pasos JSONB.
-- Comportamiento esprado: Encuentra la guia. identifica que existe un tutorial.
-- Comprueba overlay_neon y ejecucion_tutorial. Detecta que falta autorizacion.
-- Devuelve ok = false. Conserva tutorial_id = 1. Devuelve dos pasos. No ejecuta fn_overlay_iniciar().
select '--- PRUEBA 2: sin permiso ---' as test;

select ok, tutorial_id, jsonb_array_length(pasos) as pasos, motivo
from public.fn_abrir_guia_error(
    2,
    (select id from public.tipos_error where slug = 'hyperv-hypervisor-bloqueado')
);
-- Esperado: ok false. tutorial_id 1. pasos 2.
-- motivo: concede overlay_neon y ejecucion_tutorial antes de play.

select usuario_id
from public.overlay_sesion_ram
where usuario_id = 2;
-- Esperado cero filas.

-- PRUEBA 3: Conceder permiso e iniciar tutorial.
-- Usuario: Shiriaru (usuarios.id = 1). Error: hyperv-hypervisor-bloqueado.
-- Estado inicial de consentimiento: - overlay_neon = false. - ejecucion_tutorial = true.
-- Operacion: Conceder nuevamente overlay_neon durante 90 dias mediante fn_conceder_consentimiento().
-- Comportamiento esperado: - overlay_neon pasa a True. ejecucion_tutorial permanece true.
-- La funcion encuentra la guia de Hyper-V. Comprueba que ambos consentimientos esta vigentes.
-- Ejecuta fn_overlay_iniciar(). Devuelve ok = true. - Devuelve tutorial_id = 1.
-- Motivo: play tutorial de la guia.
select '--- PRUEBA 3: play de la guia---' as tesst;

select public.fn_consentimiento_vigente(1, 'overlay_neon') as neon,
       public.fn_consentimiento_vigente(1, 'ejecucion_tutorial') as play;
-- Esperado ahora: neon false. play true.
-- 1 = Shiriaru. overlay_neon quedo revocado en la carpeta 24.

-- 1 = Shiriaru. overlay_neon 90 dias. politica 1.
select public.fn_conceder_consentimiento(1,'overlay_neon', 90, 1);

select ok , tutorial_id , motivo
from public.fn_abrir_guia_error(
    1,
    (select id from public.tipos_error where slug = 'hyperv-hypervisor-bloqueado')
);
-- Esperado: ok true. tutorial_id 1. motivo = play tutorial de la guia.

select usuario_id, tutorial_id, aplicacion_id, paso_id
from overlay_sesion_ram
where usuario_id = 1;
-- Esperado: una fila. tutorial_id 1. aplicacion_id null. paso_id null.

-- PRUEBA 4 . Notepad no tiene tutorial. Son pasos de overlay.
-- Error; notepad-missing-files. Caracteristicas: existe una guia activa. tutorial_id = null
-- La guia contiene un paso JSONB.
select '--- PRUEBA 4: pasos de la guia---' as test;

-- Primer escenario: Usuario Julio (usuarios.id = 2) , Estado: No dispone de overlay_neon
-- no tiene tutorial_id.
select ok, tutorial_id, motivo
from public.fn_abrir_guia_error(
    2,
    (select id from public.tipos_error where slug = 'notepad-missing-files')
);
-- Esperado ok false. tutorial_id null. motivo = concede overlay_neon para pasos IA.

-- Segundo escenario: usuario Shiriaru . usuarios.id = 1. Estado: Ya concedio overlay_neon durante la prueba 3.
-- Resultado esperado: Encuentra la misma guia. Detecta que no existe un tutorial.
-- Comprueba que overlay_neon esta vigente. Devuelve ok = true. tutorial_id = null
-- Devuelve un paso JSONB. Motivo: overlay pasos de guia.
-- 1 = Shiriaru. Ya concedio overlay_neon en la prueba 3.
select ok, tutorial_id, jsonb_array_length(pasos) as pasos, motivo
from public.fn_abrir_guia_error(
    1,
    (select id from public.tipos_error where slug = 'notepad-missing-files')
);
-- Esperado: ok true. tutorial_id null. pasos 1.
-- motivo = overlay pasos de guia.

