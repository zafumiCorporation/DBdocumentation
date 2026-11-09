-- Pattern: Cook (lienzo -> pasos -> script verificado) + PIE Play
create or replace function public.fn_compilar_script(
    p_yo bigint,
    p_tutorial_id bigint
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_dueno bigint;
    v_ver int;
    v_cuerpo jsonb;
begin
    -- Guarda el borrador RAM , dentro de tutorial_lienzo  , tus datos estan aqui lienzo_borrador_ram ->  tutorial_lienzo
    perform public.fn_persistir_lienzo(p_yo, p_tutorial_id);

    -- Busca quien creo este tutorial y lo guarda en : v_dueno.
    select creador_id into  v_dueno
    from public.tutoriales
    where id = p_tutorial_id;

    -- Borra todos los pasos compilados anteriormente de ese tutorial.
    -- Por que se va construir desde cero usando la informacion del lienzo.
    delete from public.tutorial_pasos
    where tutorial_id = p_tutorial_id;

    -- Llenar la tabla tutorial_pasos , Llenar cada columna de la tabla. Se construyen las filas una a una.
    insert into public.tutorial_pasos (tutorial_id, ruta_orden, orden, clave, titulo_paso, rectangulo_neon)
    -- Todo lo que devuelve el select se inserta aqui.
    select
        p_tutorial_id, -- Es el tutorial que estamos compilando.
        (ruta.elem->>'orden')::int, -- Representa , Ruta 1 , Ruta 2 , Ruta 3 , Numero de ruta
        paso.ord::int, -- Representa el numero de paso ejemplo: clave : insertar: ord 1, clave: formas ord: 2
        paso.clave, -- Representa la clave de cada paso(nodo) , Ejemplo: insertar , formas .
        -- Busca la etiqueta del nodo si es null , usa la clave
        coalesce(n.elem->>'etiqueta', paso.clave),
        jsonb_build_object( -- Crea un JSON
            'x', coalesce((n.elem->>'pos_x')::int, 0),
            'y', coalesce((n.elem->>'pos_y')::int, 0),
            'w', 90,
            'h', 24,
            'color', '#FFFF00'
        )
    from public.tutorial_lienzo as l
    -- Cross join , Tutorial: Word , la funcion devuelve : ruta1 , ruta2 , Resultado Word + Ruta1 , Word + Ruta2
    cross join lateral jsonb_array_elements(l.rutas) as ruta(elem) -- Convierta la columna en filas , Ruta 1 , Ruta 2
    -- jsonb_array_elements_text() devuelve texto , Obtengo un paso con clave: insertas  ord: 1 , clave: formas ord:2
    cross join lateral jsonb_array_elements_text(ruta.elem->'secuencia') with ordinality as paso(clave, ord)
    -- left join Busca el nodo correspondiente al paso actual. Me quedo solo con la tabla nodos , no pasos.
    left join lateral jsonb_array_elements(l.nodos) as n(elem) on n.elem->>'clave' = paso.clave
    where l.tutorial_id = p_tutorial_id
    order by 2, 3; -- 2 -> rutaroden , 3 -> orden.

    -- Devuelve el resultado de la consulta, Si el resultado es null, devuelve un arreglo json vacio.
    -- Es basicamente el script ejecutable que luego usara tu runner para reproducir el tutorial paso a paso.
    select coalesce(
        jsonb_agg( -- Junta muchas filas y conviertelas en unico arreglo JSON
            jsonb_build_object( -- Objeto JSON
                'ruta', tp.ruta_orden, -- Viene de tutorial_pasos , Ruta 1 , Ruta 2 , Ruta 3 . Numero de ruta.
                'orden', tp.orden, -- Es el numero de paso.
                'action', 'click', -- Estas creando una instruccion para el runner -> Cuando llegues aqui haz click
                'clave', tp.clave, -- Clave tecnica que representa el paso (nodo)
                'titulo', tp.titulo_paso, -- Nombre visible
                'rect', tp.rectangulo_neon, -- Overlay rectangulo en pantalla.
                'selector', n2.elem->>'selector_uia',-- Sirve para econtrar el boton real en Windows
                'uia_clave', n2.elem->> 'uia_clave' -- Identificador unico del contro UIA. File , Insert , NewProject
            ) order by tp.ruta_orden, tp.orden -- Ordena primero por ruta  y dentro de cada ruta por paso(orden).
        ), '[]'::jsonb
    )
    into v_cuerpo -- Guarda el json completo.
    from public.tutorial_pasos as tp -- Pasos del tutorial compilado.
    left join public.tutorial_lienzo l
        on l.tutorial_id = tp.tutorial_id -- Busca el blueprint original
    -- Dame el nodo cuya clave = paso actual
    left join lateral jsonb_array_elements(l.nodos) as n2(elem)
        on n2.elem->>'clave' = tp.clave
    where tp.tutorial_id = p_tutorial_id;

    select coalesce(
        jsonb_agg(
            jsonb_build_object(
                'ruta', tp.ruta_orden,
                'orden', tp.orden,
                'action', 'click',
                'clave', tp.clave,
                'titulo', tp.titulo_paso,
                'rect', tp.rectangulo_neon
            ) order by tp.rectangulo_neon
        ), '[]'::jsonb
    ) into v_cuerpo from public.tutorial_pasos tp where tp.tutorial_id = p_tutorial_id;

    if jsonb_array_length(v_cuerpo) = 0 then
        raise exception 'no hay pasos para compilar';
    end if;

    -- Calculo de la nueva version.
    -- Busca la version mas alta existenta para ese tutorial. y genera la siguiente.
    select coalesce(max(version), 0) + 1 into v_ver
    from public.tutorial_scripts
    where tutorial_id = p_tutorial_id;

    insert into public.tutorial_scripts (tutorial_id, version, cuerpo_script, verificado, verificado_en)
    values (p_tutorial_id, v_ver, v_cuerpo, true, now());

    return v_ver;
end;
$$;

-- PRUEBA 1 Compilar un blueprint en un script ejecutable.
-- Objetivo: Verificar que fn_compilar_script() transforme correctamente , el blueprint almacenado
-- en RAM en una version ejecutable del tutorial.
-- Estado inicial: El borrador contiene nodos y rutas. tutorial_pasos esta vacio , tutorial_scripts esta vacio
-- tutorial_lienzo aun no refleja los cambios del borrador.
-- Accion: Ejecutar fn_compilar_script(). Resultado esperado: El borrador RAM se guarda en tutorial_lienzo.
-- Se generan los registros de tutorial_pasos , Se construye el script JSON ejecutable.
-- Se crea la version 1 del script , El script queda marcado como verificado.
-- Nota: Esta operacion equivale al proceso de compilacion de un blueprint. El disenador deja de ver unicamente nodos y rutas
-- obtiene una secuencia de instrucciones lista para que el runner reproduzca el tutorial paso a paso.
select '--- PRUEBA 1: compilar script ---' as test;

-- Antes. Pasos del tutorial 1.
select id, clave
from public.tutorial_pasos
where tutorial_id = 1;
-- Esperado ahora: cero filas.

select version, verificado
from public.tutorial_scripts
where tutorial_id = 1;
-- Esperado ahora: cero filas.

select nodos_count, rutas_count
from public.tutorial_lienzo
where tutorial_id = 1;
-- Esperado ahora: nodos_count 0, rutas_count 0.
-- El camino sigue solo en RAM

-- 1 = Shiriraru, usuarios.id Tiene que ser el editor del borrador.
-- 1 = "Create Sheet in Word", tutoriales.id.
select public.fn_compilar_script(1, 1);
-- Esperado: 1. Es la version del script.

select nodos_count, rutas_count
from public.tutorial_lienzo
where tutorial_id = 1;
-- Esperado: nodos_count 2, rutas_count 1.
-- Persistir, llamado desde compilar, copio el RAM al publicado.

select ruta_orden, orden, clave, titulo_paso, rectangulo_neon
from public.tutorial_pasos
where tutorial_id = 1
order by orden;
-- Esperado: dos filas.
-- orden 1, clave insertar, titulo Insertar, rect x 40, y 80, w 90, h 24, color #FFFFF00.
-- orden 2, clave pagina-en-blanco, titulo Pagina en Blanco, rect x 240, y 80

select version, verificado, verificado_en is not null as tiene_fecha,
       jsonb_array_length(cuerpo_script) as pasos,
       cuerpo_script->0->>'clave' as paso_1,
       cuerpo_script->0->>'uia_clave' as uia_1,
       cuerpo_script->1->>'clave' as paso_2,
       cuerpo_script->1->>'uia_clave' as uia_2
from public.tutorial_scripts
where tutorial_id = 1;
-- Esperado: version 1, verificado true, tiene_fecha true, pasos 2.
-- paso_1 insertar, uia_1 Insert.
-- paso_2 pagina-en-blanco, uia_2 BlankPage.