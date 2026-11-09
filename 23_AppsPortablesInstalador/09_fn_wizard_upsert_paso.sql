-- Esta funcion agrega o corrige un solo paso del wizard sin borrar los demas. Es cirugia no reemplazo completo.
create or replace function public.fn_wizard_upsert_paso(
    p_aplicacion_id bigint, -- ID de la app. Ej: Lauch4j.
    p_orden int, -- Numero del paso. 1, 2, 3. El orden de ejecucion.
    p_fase text, -- En que ventana esta ese paso Ej: asistente , descarga , config
    p_etiqueta text, -- Texto que ve el usuario en el boton. Ej: Siguiente
    p_uia_clave text,-- Clave unica de ese boton dentro del wizard. Ej: Next.
    p_selector text default null, -- Direccion tecnica para encontrar el boton en Windows. Ej: UIA.Next.
    p_por_que text default null, -- Explicacion de por que hay que hacer click ahi .
    p_action text default 'click' -- Que debe hacer: click, focus, Si no le pasas nada, por defecto click.
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_idx int; -- Aqui guarda la posicion del paso que encontro. Ej: 0, 1, 2.
    v_paso jsonb; -- Aqui guarda el nuevo paso que vas a crear como objeto JSON.
begin
    v_paso := jsonb_build_object( -- Crea un objeto JSON con todos los datos que le pasaste.
        'orden', p_orden,
        'fase', p_fase,
        'etiqueta', btrim(p_etiqueta),
        'uia_clave', p_uia_clave,
        'selector_uia',p_selector,
        'por_que', p_por_que,
        'action', coalesce(p_action, 'click')
    );

    -- Busca si ya existe el JSON , 0-base Significa que JSON cuenta desde 0.
    select ord - 1 into v_idx -- Si encuentra dicho  boton , guarda su posicion en v_idx.
    from public.aplicaciones_catalogo as a
    cross join lateral jsonb_array_elements(a.pasos_wizard)
        with ordinality as x(elem, ord)
    where a.id = p_aplicacion_id
      and lower(elem->>'uia_clave') = lower(p_uia_clave);

    if v_idx is not null then -- Si existe, lo reemplaza.
        -- Cirugia: pisa solo ese paso, no borra wizard completo
        update public.aplicaciones_catalogo
        set pasos_wizard = jsonb_set(pasos_wizard, ARRAY[v_idx::text], v_paso, false)
        where id = p_aplicacion_id;
    else -- Si no , lo agrega.
        -- Agrega paso nuevo al final.
        update public.aplicaciones_catalogo
        set pasos_wizard = pasos_wizard || jsonb_build_array(v_paso)
        where id = p_aplicacion_id;
    end if;

    return ( -- Devuelve cuantos pasos hay.
        select pasos_count
        from public.aplicaciones_catalogo
        where id = p_aplicacion_id
    );
end;
$$;

-- PRUEBA 1 Agregar el primer paso de un Wizard (Asistente de instalacion) (Secuencia de pantallas)
-- Estamos documentado el primer click que se debe hacer durante la instalacion.
-- Objetivo: Verificar que fn_wizard_upsert_paso() agregue un nuevo paso cuando el wizard todavia no contiene ninguno.
-- Estado inicial: pasos_wizard = [] , pasos_count = 0
-- Accion: Registrar el boton "Siguiente" , identificado por la clave UIA "Next".
-- Resultado esperado: Se crea el primer elemento del JSON.
-- pasos_count pasa de 0 a 1. El paso queda registrado con : orden = 1 , fase = instalar , etiqueta = siguiente

select '--- PRUEBA 1: agregar paso ---' as test;
-- Valida v_paso := jsonb_build_object(...)
-- Luego busca: Ya existe un paso con uia_clave = Next ? select ord - 1 into v_idx
-- pasos_wizard || jsonb_build_array(...)

select slug, pasos_count
from public.aplicaciones_catalogo
where slug = 'vmware-player';
-- Esperado ahora: pasos_count 0.

-- El subquery es vmware-player , aplicacion_catalogo.id
-- 1 = orden del paso. 'instalar' = fase. 'Siguiente' = etiqueta visible.
-- 'Next' = uia_clave. 'click' = action.
select public.fn_wizard_upsert_paso(
       (select id from public.aplicaciones_catalogo where slug = 'vmware-player'),
       1, 'instalar', 'Siguiente', 'Next', null, 'Avanza el asistente', 'click'
);
-- Esperado: 1. es pasos_count

select orden, fase, etiqueta, uia_clave, action
from public.vista_wizard_pasos
where slug = 'vmware-player'
order by orden;
-- Esperado: una fila. orden 1, fase instalar, etiqueta siguiente, uia_clave Next, action click

-- PRUEBA 2 Actualizar un paso existente del wizard.
-- Objetivo: Verificar que fn_wizard_upsert_paso() reemplace un paso cunado ya existe la misma clave UIA.
-- Estado inicial: Existe un paso con: uia_clave = Next , etiqueta = Siguiente.
-- Accion: Registrar nuevamente el paso, usando la misma uia_clave , pero con otra etiqueta.
-- Resultado esperado: No se crea un segundo paso, pasos_count permanece en 1.
-- La etiqueta cambia a: Siguiente (Player)

select '--- PRUEBA 2: actualizar paso ---' as test;
-- Codigo clave: select ord - 1 into v_idx
-- jsonb_set(...)

select pasos_count
from public.aplicaciones_catalogo
where slug = 'vmware-player';
-- Esperado ahora: 1.

-- Misma uia_clave Next. Cambia la etiqueta
select public.fn_wizard_upsert_paso(
    (select id from public.aplicaciones_catalogo where slug = 'vmware-player'),
    1, 'instalar', 'Siguiente (Player)', 'Next', null, 'Avanza el asistente', 'click'
);
--Esperado ahora: 1. El contador no sube.

select etiqueta, uia_clave
from public.vista_wizard_pasos
where slug = 'vmware-player';
-- Esperado: una sola fila. etiqueta = Siguiente (Player). uia_clave Next.


