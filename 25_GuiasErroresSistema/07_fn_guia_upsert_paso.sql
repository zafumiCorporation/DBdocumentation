-- Objetivo: Validar la creacion y actualizacion de pasos individuales dentro de ua guia mendiante public.fn_guia_upsert_paso().
-- La funcion permite: Agregar un paso cuando su uia_clave todavia no existe.
-- Actualizar un paso cuando su uia_clave ya esta regitrada.
-- Evitar duplicar instrucciones al actualizar una clave existente.
-- Mantener actualizado updated_at.
-- Devolver la cantidad total de pasos despues de cada operacion.
create or replace function public.fn_guia_upsert_paso(
    p_guia_id bigint, -- Id de la guia a modificar.
    p_orden int, -- Orden logico del paso Ej: Paso 1, Paso 2 , Paso 3.
    p_fase text, -- Etapa o fase del proceso . Diagnostico , Preparacion , Reparacion , Verificacion.
    p_etiqueta text, -- Nombre visible del paso.
    p_uia_clave text, -- Clave unica del paso.
    p_selector text default null, -- Selector especifio Ej: AutomationId, XPath , CSS Selector, UIPath.
    p_por_que text default null, -- Explicacion del paso.
    p_action text default 'click' -- La accion que debe ejecutarse.
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_idx int; --
    v_paso jsonb;
begin
    if btrim(coalesce(p_etiqueta, '')) = '' then
        raise exception 'etiqueta vacia para guia_id=%', p_guia_id;
    end if;

    if btrim(coalesce(p_uia_clave, '')) = '' then
        raise exception 'uia_clave vacia para guia_id=%', p_guia_id;
    end if;

    -- Construye un JSON completo del paso.
    v_paso := jsonb_build_object(
        'orden', p_orden,
        'fase', p_fase,
        'etiqueta', btrim(p_etiqueta),
        'uia_clave', p_uia_clave,
        'selector_uia', p_selector,
        'por_que', p_por_que,
        'action', coalesce(p_action, 'click')
    );

    -- Buscar paso existente.
    select ord -1 into v_idx -- Id del paso existente.
    from public.guias as g
    cross join lateral jsonb_array_elements(g.pasos) with ordinality as x(elem, ord)
    where g.id = p_guia_id -- Guia que estamos buscando.
        and lower(elem->>'uia_clave') = lower(p_uia_clave);

    if v_idx is not null then -- Si encontro paso
        update public.guias
        -- Reemplaza paso , false No crea posiciones nuevas.
        set pasos = jsonb_set(pasos, array[v_idx::text], v_paso, false),
            updated_at = now()
        where id = p_guia_id;
    else
        update public.guias
        set pasos = pasos || jsonb_build_array(v_paso),
            updated_at = now()
        where id = p_guia_id;
    end if;

    return (select pasos_count from public.guias where id = p_guia_id); -- Devuelve numero de paso.
end;
$$;

-- PRUEBA 1: Agregar el primer paso de HYPER-V
select '--- PRUEBA 1: agregar paso ---' as test;

-- Se consulta la cantidad inicial de pasos de la guia.
-- La guia debe haber sido creada previamente mediante fn_guia_upsert().
-- Esperado: pasos_count = 0.
select g.pasos_count
from public.guias g
join public.tipos_error t on t.id = g.tipo_error_id
where t.slug = 'hyperv-hypervisor-bloqueado';

-- Se agrga la primera instruccion de reparacion.
-- p_guia_id: Obtiene el ID de la guia asociada con hyperv-hypervisor-bloqueado.
-- p_orden = 1: Identificador logico de la posicion del paso.
-- p_fase = 'Reparacion': Clasifica la instruccion dentro de la fase de reparacion.
-- p_etiqueta = Nombre que se mostrara al usuario.
-- p_uia_clave: Identificador logico utilizado para localizar y actualizar el paso.
-- p_selecto: Selector utilizado para identificar el control mediante UI Automation.
-- p_por_que: Explicacion de la necesidad de ejecutar la instruccion.
-- p_action: Accion que debera interpretar posteriormente el agente.
select public.fn_guia_upsert_paso(
    (select g.id
     from public.guias g
     join public.tipos_error t on t.id = g.tipo_error_id
     where t.slug = 'hyperv-hypervisor-bloqueado'),
    1,
    'Reparacion',
    'Activar Hyper-V',
    'HyperV.Enable',
    'AutomationId:EnableHyperV'
    'Sin el hypervisor la VM no arranca',
    'click'
);
-- Esperado: devuelve 1, cantidad total de pasos.

select pasos_count, pasos->0->>'uia_clave' as uia, pasos->0->>'etiqueta' as etiqueta
from public.guias g
join public.tipos_error t on t.id = g.tipo_error_id
where t.slug = 'hyperv-hypervisor-bloqueado';
-- Esperado: pasos_count = 1. uia = HyperV.Enable. etiqueta = "Activar Hyper-V".

-- PRUEBA 2: Actualizar un paso existente sin duplicarlo.
-- Se vuelve a ejecutar la funcion utilizando la mismsa uia_clave: HyperV.Enable.
-- La etiqueta cambia de: "Activar Hyper-V" a "Activar la plataforma Hyper-V".
select '--- PRUEBA 2: pisar el paso ---' as test;

select public.fn_guia_upsert_paso(
    (select g.id
     from public.guias g
     join public.tipos_error t on t.id = g.tipo_error_id
     where t.slug = 'hyperv-hypervisor-bloqueado'),
    1,
    'Reparacion',
    'Activar la plataforma Hyper-V',
    'HyperV.Enable',
    'Sin el hypervisor la VM no arranca',
    'click'
);
-- Esperado: Devuelve 1. No se agrega un segundo paso.

select pasos_count, pasos->0->>'etiqueta' as etiqueta
from public.guias g
join public.tipos_error t on t.id = g.tipo_error_id
where t.slug = 'hyperv-hypervisor-bloqueado';
-- Esperado: pasos_count 1. etiqueta "Activar la plataforma Hyper-V".

-- PRUEBA 3: Agrgar un segundo paso y Rechazar etiquetas vacias
-- Se agrega una nueva instruccion utilizando una uia_clave diferente: HyperV.Reboot.
-- Como esta clave todavia no existe, la funcion utiliza el operado || para agregar un nuevo objeto JSONB al final del arreglo.
-- p_orden - 2: Identifica logicamente la segunda instruccion.
-- p_fase = 'Verificacion': Clasifica la instruccion dentro de la fase de verificacion.
-- p_selector = NULL: El selector es opcional y puede quedar sin especificar.
-- Esperado: devuelve 2.
select public.fn_guia_upsert_paso(
    (select g.id
     from public.guias g
     join public.tipos_error t
        on t.id = g.tipo_error_id
     where t.slug = 'hyperv-hypervisor-bloqueado'),
    2,
    'Verificacion',
    'Reiniciar Windows',
    'HyperV.Reboot',
    null,
    'Hyper-V toma el hypervisor al arrancar',
    'clcik'
);

select pasos_count,
       pasos->0->>'uia_clave' as primero,
       pasos->1->>'uia_clave' as segundo
from public.guias g
join public.tipos_error t on t.id = g.tipo_error_id
where t.slug = 'hyperv-hypervisor-bloqueado';
-- Esperado: pasos_count 2. primero HyperV.Enable. segundo HyperV.Reboot.

do $$
begin
    perform public.fn_guia_upsert_paso(
        (select g.id
         from public.guias g
         join public.tipos_error t on t.id = g.tipo_error_id
         where t.slug = 'hyperv-hypervisor-bloqueado'),
        3, 'Reparacion', ' ', 'HyperV.Vacio'
    );
    raise exception 'FALLO: acepto etiqueta vacia';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK etiqueta: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK etiqueta: etiqueta vacia para guia_id=1.

select pasos_count
from public.guias g
join public.tipos_error t on t.id = g.tipo_error_id
where t.slug = 'hyperv-hypervisor-bloqueado';
-- Esperado 2.
