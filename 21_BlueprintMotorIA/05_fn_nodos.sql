drop function public.fn_agregar_nodo(bigint, bigint, text, text, text, text, int, int, boolean, boolean);
create or replace function public.fn_agregar_nodo(
    p_yo bigint, -- Id del usuario que esta agregando el nodo.
    p_tutorial_id bigint, -- Id del tutorial donde se agregara el nodo.
    p_clave text, -- clave tecnica unica para identificar el nodo (ejemplo: "insertar-texto")
    p_etiqueta text, -- nombre visible para el usuario (ejemplo: "Insertar Texto")
    p_uia_clave text, -- Identificador unico del boton/nodo en la Interfaz (ejemplo: "File")
    p_selector text default null, -- Direccion tecnica para ubicar el nodo en la interfaz
    p_x int default 0, --Posicion horizontal del nodo en el lienzo.
    p_y int default 0, --Posicion vertical del nodo en el lienzo.
    p_inicio boolean default false, -- Indica si el nodo es el inicio del tutorial.
    p_fin boolean default false -- Indica si el nodo es el fin del tutorial.
)
returns int
language plpgsql
set search_path = ''
as $$
declare
    v_clave text;
    v_nodo jsonb;
begin

    -- Asegura que exista un lienzo y un borrador para ese tutorial.
    perform public.fn_lienzo_upsert(p_yo, p_tutorial_id);

    v_clave := public.fn_normalizar_slug(p_clave::public.citext);

    -- and -> al mismo tiempo
    -- Un nodo no puede ser el punto de partida y el punto final a la vez.
    if p_inicio and p_fin then
        raise exception 'Un nodo no es inicio y fin a la vez';
    end if;

    -- Arma un JSON con todos los datos del nodo.
    v_nodo := jsonb_build_object(
        'clave', v_clave,
        'etiqueta', btrim(p_etiqueta),
        'uia_clave', p_uia_clave,
        'selector_uia', p_selector,
        'pos_x', p_x,
        'pos_y', p_y,
        'es_inicio', p_inicio,
        'es_fin', p_fin
    );


    update public.lienzo_borrador_ram
    set nodos = case
        -- Revisa si ya existe un nodo con la misma clave en el JSON
        when exists(
            select 1
            from jsonb_array_elements(nodos) e(elem)
            where elem->>'clave' = v_clave
        ) then (
            --json_agg -> Vuelve a juntar todos los nodos en un array JSON.
            select jsonb_agg(
                -- Si la clave coincide -> reemplaza ese nodo con el nuevo (v_nodo).
                -- Si no coincide -> deja el nodo como estaba
                case when elem->>'clave' = v_clave then v_nodo else elem end
            )
            from jsonb_array_elements(nodos) e(elem)
        )
        -- Si no existe concatena el nuevo nodo al final del JSON.
        else nodos || jsonb_build_array(v_nodo)
    end,
    -- Actualiza la fecha de guardado.
    saved_at = now()
    where tutorial_id = p_tutorial_id
    and editor_id = p_yo;

    return (
        select jsonb_array_length(nodos)
        from public.lienzo_borrador_ram where tutorial_id = p_tutorial_id
    );
end;
$$;

-- PRUEBA 1 Crear nodos dentro del blueprint en construccion.
-- Objetivo: Verificar que fn_agregar_nodo() agregue correctamente nuevos nodos al borrador RAM del tutorial.
-- Estado inicial: El borrador existe. No hay nodos en el lienzo.
-- Accion:Agregar tres nodos:
-- 1. Insertar Nodo de inicio, 2. Pagina en Blanco Nodo fin. 3. Archivo - Nodo intermedio.
-- Resultado esperado: El JSON nodos contiene tres elementos. Existe un unico nodo marcado como inicion
-- Existe un unico nodo marcado como fin.
-- Cada nodo conserva su clave, etiqueta y uia_clave.
select '--- PRUEBA 1: agregar nodos ---' as test;

-- Antes. Borrador de Shiriaru en el tutorial 1.
select jsonb_array_length(nodos) as nodos
from public.lienzo_borrador_ram
where tutorial_id = 1
    and editor_id = 1;
-- Esperado ahora: 0.

-- 1 = Shiriaru, usuario.id.
-- 1 = "Create Sheet in Word", tutoriales.id.
-- 'Insertar' pasa por fn_normalizar_slug y queda insertar
-- 'Insert' = uia_clave del boton de la paleta Word.
-- true, false = este nodo es el inicio, no el fin.
select public.fn_agregar_nodo(1,1, 'Insertar', 'Insertar', 'Insert', null, 40, 80, true, false);
-- Esperado: 1

-- 'Pagina en Blanco' queda clave pagina-en-blanco.
-- 'BlankPage' = uia_clave de la paleta Word.
-- false, true = este nod es el fin.
select public.fn_agregar_nodo(1, 1, 'Pagina en Blanco', 'Pagina en Blanco', 'BlankPage', null, 240, 80, false, true);
-- Esperado: 2.

-- 'Archivo' queda clave archivo. No es inicio ni fin. sirve para quitarlo despues.
select public.fn_agregar_nodo(1, 1, 'Archivo', 'Archivo', 'File', null, 140, 160, false, false);
-- Esperado: 3.

select elem->>'clave' as clave, elem->>'etiqueta' as etiqueta, elem->>'uia_clave' as uia_clave,
       elem->>'es_inicio' as es_inicio, elem->>'es_fin' as es_fin
from public.lienzo_borrador_ram as r
cross join lateral jsonb_array_elements(r.nodos) as elem
where r.tutorial_id = 1
order by clave;
-- Esperado: archivo, insertar (es_inicio true), pagina-en-blanco (es_fin true).

-- El publicado sigue vacio. Persistir del archivo 04 corrio ante de estos nodos.
select nodos_count
from public.tutorial_lienzo
where tutorial_id = 1;
-- Esperado: 0.

-- Quitar nodo
create or replace function public.fn_quitar_nodo(
    p_yo bigint, -- Id del usuario que intenta quitar el nodo.
    p_tutorial_id bigint, -- Id del tutorial donde se esta quitando el nodo.
    p_clave text -- Clave unica del nodo que se quiere eliminar.
)
returns int
language plpgsql
set search_path = ''
as $$
declare
    v_clave text := public.fn_normalizar_slug(p_clave::public.citext);
begin
    update public.lienzo_borrador_ram
    -- Elimina el nodo con esa clave y reconstruye el JSON de nodos.
    -- coalesce(..., '[]'::jsonb) -> Si no queda nada(null), devuelve un array vacio.
    set nodos = coalesce(
                (
                    -- Vuelve a juntar los nodos filtrados en un array JSON.
                    select jsonb_agg(elem)
                    -- Convierte el JSON de nodos en filas. cada fila es un nodo.
                    from jsonb_array_elements(nodos) e(elem)
                    -- Filtra todos los nodos excepto el que tiene la clave que queremos quitar.
                    where elem->>'clave' <> v_clave
                ), '[]'::jsonb),

        rutas = coalesce(
                (
                    select jsonb_agg(
                           -- Cada ruta le agrega/modifica el campo "secuencia"
                           elem || jsonb_build_object(
                                        -- coalesce(..., '[]'::jsonb) -> Si no queda nada, devuelve un array vacio.
                                        'secuencia', coalesce(
                                                     (
                                                         -- Vuelve a juntar los pasos restantes en un array JSON
                                                         select jsonb_agg(paso)
                                                         -- Convierta la secuencia de pasos de esa ruta en filas de texto.
                                                         from jsonb_array_elements_text(elem->'secuencia') s(paso)
                                                         -- Elimina de la secuencia el paso que coincide con la clave del nodo eliminado.
                                                         where paso <> v_clave
                                                     ) , '[]'::jsonb)
                                   )
                           )
                    -- Convierte el json de rutas en filas, cada fila es una ruta.
                    from jsonb_array_elements(rutas) r(elem)
                ), '[]'::jsonb),
        saved_at = now()
        where tutorial_id = p_tutorial_id
        and editor_id = p_yo;

    -- Cuantos nodos tiene el JSON despues de la eliminacion , cuantos nodos tiene el lienzo ahora.
    return (
        select jsonb_array_length(nodos)
        from public.lienzo_borrador_ram
        where tutorial_id = p_tutorial_id
    );

end;
$$;

-- PRUEBA 2 ELIMINAR UN NODO DEL BORRADOR.
-- Objetivo: Verificar que fn_quitar_nodo() elimine  correctamente un nodo existente del blueprint.
-- Estado inicial: Existen tres nodos: insertar, archivo, pagina-en-blanco.
-- Accion: Eliminar el nodo "archivo".
-- Resultado esperado: El nodo archivo desaparece del JSON nodos.
-- El conteo baja de 3 a 2 Solo permanecen: insertar , pagina-en-blanco
-- Nota: si el nodo eliminado estuviera siendo utilizado por alguna ruta, la funcion tambien limpiaria
-- automaticamente las referencias dentro de las secuencias.
select '--- PRUEBA 2: quitar nodo ---' as test;

select  jsonb_array_length(nodos) as nodos
from public.lienzo_borrador_ram
where tutorial_id = 1;
-- Esperado ahora; 3.

-- 1 = Shiriaru, usuario.id.
-- 1 = "Create Sheet in Word", tutoriales.id.
-- 'Archivo' se normaliza a archivo.
select public.fn_quitar_nodo(1,1,'Archivo');
-- Esperado: 2.

select elem->>'clave' as clave
from public.lienzo_borrador_ram as r
cross join lateral jsonb_array_elements(r.nodos) as elem
where r.tutorial_id = 1
order by clave;
-- Esperado: insertar y pagina-en-blanco. archivo ya no esta.
