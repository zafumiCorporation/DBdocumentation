-- fn_abrrir_guia -> Decide cual es la mejor forma de abrir una solucion.
-- Objetivo: determinar la modalidad mas adecuada para resolver un error detectado, evaluando
-- la disponibilidad de una guia, un tutorial publicado, pasos jsonb y la posibilidad de generar
-- una solucion mediante IA , La funcion actua como un selector de rutas de resolucion para la
-- aplicacion de escritorio.
drop function fn_abrrir_guia(bigint,bigint);
create or replace function public.fn_abrrir_guia(
    p_yo bigint, -- Id del usuario que quiere abrir la solucion.
    p_tipo_error_id bigint -- Id del error que queremos resolver.
)
returns table (
    via text, -- Que camino usara para resolver el error? , puede devolver: tutorial o overlay o ia_libre o nada.
    guia_id bigint, -- Id de la guia encontrada.
    tutorial_id bigint, --  Id del tutorial que resuelve el error.
    pasos jsonb, -- Los pasos de resolucion.
    motivo text -- Explica por que eligio ese camino.
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_g public.guias%ROWTYPE; -- Contiene una fila completa de la tabla guias.
    v_pub boolean; -- True , False si el tutorial esta publicado.
    r record; -- Guarda una fila cualquiera.
begin
    select * into v_g -- fila guia.
    from public.guias
    where tipo_error_id = p_tipo_error_id
        and activa = true
    limit 1;

    -- Caso 1 no existe ninguna guia.
    if v_g.id is null then
        -- Guarda el resultado en: r
        select * into r
        from public.fn_abrir_guia_error(p_yo, p_tipo_error_id)
        limit 1;
        -- ia_libre: La IA debe improvisar una solucion.
        return query select 'ia_libre'::text, null::bigint, r.tutorial_id, coalesce(r.pasos, '[]'::jsonb), r.motivo;
        return;
    end if;

    -- Caso 2: Existe guia y tutorial.
    if v_g.tutorial_id is not null then
        select (estado = 'published' and es_publico) into v_pub
        from public.tutoriales
        where id = v_g.tutorial_id;

        -- True tutorial publicado entonces
        if coalesce(v_pub, false) then
            return query select 'tutorial'::text, v_g.id, v_g.tutorial_id, '[]'::jsonb, 'abre Play del tutorial documentado'::text;
            return;
        end if;
    end if;

    -- Caso 3: existe la guia y tiene pasos ?
    if jsonb_array_length(coalesce(v_g.pasos, '[]'::jsonb)) > 0 then
        -- Si no tiene permiso lanza exception
        if not public.fn_consentimiento_vigente(p_yo, 'overlay_neon') then
            raise exception 'concede overlay_neon antes de guia overlay';
        end if;
        return query select 'overlay'::text, v_g.id, v_g.tutorial_id, v_g.pasos, 'pasos UIA; ghost de 24 ensena click'::text;
        return;
    end if;

    -- Casos 4 true la guia fue creada por IA.
    if v_g.ia_generada then
        return query select 'ia_libre'::text, v_g.id, null::bigint, '[]'::jsonb, 'guia sin pasos; worker genera overlay en caliente'::text;
        return;
    end if;

    -- No hay tutorial , No hay pasos , No hay solucion.
    return query select 'nada'::text, v_g.id, null::bigint, '[]'::jsonb, 'guia sin camino'::text;
end;
$$;

-- PRUEBA 1: Error sin guia. usuario: Shiriaru (usuarios.id = 1).
-- Error: overlay-boton-ausente , Estado: No existe una guia activa para este tipo de error.
-- Comportamiento: No encuentra una fila en public.guias, Detecta v_g.id = null
-- consulta fn_abrir_guia_error(), Obtiene el diagnostico de que no existe una solucion registrada.
-- Devuelve via = ia_libre , guia_id = null, tutorial_id = null, pasos = [].
-- Resultado esperado: ia_libre.
select '---PRUEBA 1: sin guia ---' as test;

-- 1 = Shiriaru. overlay-boton-ausente no tiene fila en guias.
select via, guia_id, tutorial_id, motivo
from public.fn_abrrir_guia(
    1,
    (select id from public.tipos_error where slug = 'overlay-boton-ausente')
);
-- Esperado: via ia_libre. guia_id null. tutorial_id null.
-- motivo: no hay guia; La ia debe upsert pasos con fn_guia_upsert.

-- PRUEBA 2: Guia con pasos JSONB y validacion de consentimientos.
-- Error: notepad-missing-files. Usuario Shiriaru (usuarios.id = 1).
-- Estado: Existe una guia activa, tutorial_id = null. La guia contine un paso JSONB.
-- overlay_neon esta vigente.
-- Comportamiento: Encuentra la guia. No encuentra un tutorial asociado. Detecta que existen pasos
-- Comprueba overlay_neon. Devuelve via = overlay. Devuelve la guia y sus pasos.
select '--- PRUEBA 2: overlay de pasos ---' as test;

select via, guia_id is not null as trae_guia, tutorial_id,
       jsonb_array_length(pasos) as pasos, motivo
from public.fn_abrrir_guia(
    1::bigint,
    (select id from public.tipos_error where slug = 'notepad-missing-files')::bigint
);
-- Esperado: via overlay. trae_guia true. tutorial_id null. pasos 1.
-- motivo = pasos uIA; ghost de 24 ensena click.

-- Segundo Escenario: Usuario Julio (usuarios.id = 2).
-- Estado: Utiliza la misma guia. No dispone del consentimiento overlay_neon.
-- Comportamiento: Encuentra la guia. Detecta que contiene pasos. Comprueba overlay_neon.
-- lanza una excepcion por falta de consentimiento.
-- Resultado esperado en Messages: OK julio: concede overlay_neon antes de guia overlay.
do $$
begin
    perform *
    from public.fn_abrrir_guia(
        2,
        (select id from public.tipos_error where slug = 'notepad-missing-files')
    );
    raise exception 'FALLO: Julio abrio el overlay';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK julio: %', sqlerrm;
end;
$$;

-- PRUEBA 3: Guia con tutorial en draft y sin pasos. Error: reloj-sistema.
-- Estado Inicial: Existe una guia activa. Tiene tutorial_id = 4. El tutorial esta en estado drat.
-- es_publico = true. La guia no tiene pasos. ia_generada = false.
-- Comportamiento: Encuentra la guia. Detecta que tiene un tutorial asociado.
-- Comprueba estado = 'publicado' and es_publico.
-- La condicion resulta FALSE porque el tutorial esta en draft. No encuentra pasos JSONB.
-- ia_generada es FALSE. Devuelve via = nada.
-- Resultado esperado: via = nada , trae_guiada = true, guia sin camino.
select '---PRUEBA 3: guia sin camino---' as test;

-- 4 = "Create Video Game in Unreal Engine". estado draft. es_publico true.
select via, guia_id is not null as trae_guia, motivo
from public.fn_abrrir_guia(
    1,
    (select id from public.tipos_error where slug = 'reloj-sistema')
);
-- Esperado: via nada. trae_guia true. motivo = guia sin camino.

-- Segundo escenario : Operacion: Actualizar ia_generada = TRUE para la guia del reloj.
-- Comportamiento: El tutorial sigue en draft. La guia continua sin pasos. ia_generada ahora es true.
-- La funcion selecciona ia_libre.
-- Resultado esperado: via = ia_libre , trae_guia = true , motivo = guia sin pasos; worker genera overlay en caliente.
update public.guias
set ia_generada = true
where tipo_error_id = (select id from public.tipos_error where slug = 'reloj-sistmea');

select via, guia_id is not null as trae_guia, motivo
from public.fn_abrrir_guia(
    1,
    (select id from public.tipos_error where slug = 'reloj-sistema')
);

update public.guias
set ia_generada = false
where tipo_error_id = (select id from public.tipos_error where slug = 'reloj-sistema');

-- PRUEBA 4:  Tutorial publicado y cambio de prioridada , Error: hyperv-hypervisor-bloqueado.
-- Estado Inicial: Existe una guia activa. tutorial_id = 1. El tutorial esta en draft.
-- es_publico = true. La guia contiene dos pasos JSONB.
-- Primer Escenario: Operacion: Consultar el estado del tutorial.
-- Resultado Esperado: estado = draft.
select '---PRUEBA 4: tutorial publicado---' as test;

select estado
from public.tutoriales
where id = 1;
-- Esperado ahora: draft.
-- 1 = "Create Sheet in Word". es_publico ya es true.

update public.tutoriales
set estado = 'published' , es_publico = true
where id = 1;

select via, tutorial_id, motivo
from public.fn_abrrir_guia(
    1,
    (select id from public.tipos_error where slug = 'hyperv-hypervisor-bloqueado')
);
-- Esperado: via tutorial. tutorial_id 1.
-- motivo = abre play del tutorial documentado . SOlucionar esto por que sale pasos UIA; ghost de 24 ensena click.

-- Tercer Escenario: Usuario: Julio (usuarios.id = 2).
-- Comportamiento: Consulta la misma guia. Encuentra el tutorial publicado y publico.
-- Selecciona tutorial.
-- No comprueba overlay_neon ni ejecucion_tutorial en esta ram de la implementacio.
-- Resultado esperado: via = tutorial , tutorial_id = 1.
select via, tutorial_id
from public.fn_abrrir_guia(
    2::bigint,
    (select id from public.tipos_error where slug = 'hyperv-hypervisor-bloqueado')::bigint
);
-- Esperado: via tutorial. tutorial_id 1.

update public.tutoriales
set estado = 'draft'
where id = 1;

select estado
from public.tutoriales
where id = 1;
-- Esperado: draft.

select via
from public.fn_abrrir_guia(
    1,
    (select id from public.tipos_error where slug = 'hyperv-hypervisor-bloqueado')
);
-- Esperado: overlay. El tutorial volvio a draft y la guia ya tiene dos pasos.
