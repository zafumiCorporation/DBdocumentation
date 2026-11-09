-- Empujar un boton al JSON (jsonb_insert)
create or replace function public.fn_paleta_upsert_boton(
    p_categoria_id bigint, -- Id de la categoria (Word, Unreal, etc.)
    p_nombre text, -- Nombre del boton (ej: "Archivo")
    p_etiqueta text, -- Etiqueta visible (ej: "Insertar Texto")
    p_uia_clave text, -- Clave unica del boton (ej: "File")
    p_icono text default null, -- Nombre del icono (ej:"icon_file")
    p_es_accion boolean default true -- Si es accion UIA (true/false)
)
returns int
language plpgsql
set search_path = ''
as $$
declare
    v_idx int;
    v_boton jsonb;
begin
    -- Si la categoria no existe, la crea con un JSON vacio ([])
    -- Si ya existe, no hace nada.
    insert into public.paletas_categoria (categoria_id, botones)
    values (p_categoria_id, '[]'::jsonb)
    on conflict (categoria_id) do nothing;

    -- jsonb_build_object -> crea un objeto JSON con pares clave-valor.
    v_boton := jsonb_build_object(
        'nombre', p_nombre,
        'etiqueta', p_etiqueta,
        'uia_clave', p_uia_clave,
        'icono', p_icono,
        'es_accion_uia', p_es_accion
    );

    -- Ecuentra donde esta el boton dentro del JSON
    -- ord - 1 -> No es un campo de tu tabla, lo crea With Ordinality.
    -- ord -1 -> Convierte el numero de orden en indice de array , empieza en indice 0.
    select ord - 1
    into v_idx -- Posicion del boton dentro del JSON
    from public.paletas_categoria as p
    cross join lateral jsonb_array_elements(p.botones)
        -- With ordinality -> agrega un numero de orden (1,2,3...)
        -- Ejemplo: si tu JSON tiene 3 botones , se generarn filas con ord = 1, ord =2 , ord = 3.
        -- as x(elem, ord) -> da un apodo , elem -> El contenido del boton (JSON)
        -- ord -> El numero de orden(1,2,3...)
        with ordinality as x(elem, ord)
    where p.categoria_id = p_categoria_id --> Filtra la categoria correcta.
      and lower(elem->>'uia_clave') = lower(p_uia_clave);

    -- Caso 1: El boton ya existe (v_idx no es null)
    if v_idx is not null then
        update public.paletas_categoria
        -- Actualiza el boton existente
        -- botones -> el JSON original
        -- array[v_idx::text] -> la ruta dentro del JSON (posicion del boton)
        -- v_boton -> el nuevo objeto JSON del boton
        -- false -> no crea claves nuevas, solo reemplaza
        set botones = jsonb_set(botones, array[v_idx::text], v_boton, false)
        where categoria_id = p_categoria_id;

    -- Caso 2: El boton no existe
    else
        update public.paletas_categoria
        -- Concatena y agrega el nuevo boton al final de JSON.
        set botones = botones || jsonb_build_array(v_boton)
        where categoria_id = p_categoria_id;
    end if;

    select botones_count into v_idx
    from public.paletas_categoria where categoria_id = p_categoria_id;
    return v_idx;

end;
$$;

-- PRUEBA 1. Agregar un nuevo boton a la categoria Word.
-- Objetivo: Verificar que la funcion agregue un nuevo boton al JSON cuando no existe otro boton con la misma uia_clave.
select '--- PRUEBA 1: agregar boton ---' as test;

-- Antes tabla public.paletas_categoria.
-- 1 = Word, tabla public.categorias, slug word.
select categoria_id, botones_count
from public.paletas_categoria
where categoria_id = 1;
-- Esperado ahora: botones_count = 3.

select nombre, uia_clave
from public.vista_botones_catalogo
where categoria_id = 1
order by uia_clave;
-- Esperado ahora: BlankPage, File, Insert. No esta Design

-- 1 = Word, categorias.id.
-- 'Diseno' = nombre del boton.
-- 'Diseno' = etiqueta visible.
-- 'Desing' = uia_clave. No pasa por fn_normalizar_slug.
-- 'icon_desing' = icono. true = es accion UIA.
select public.fn_paleta_upsert_boton(1, 'Diseno', 'Diseno', 'Desing', 'icon_desing', true);
-- Esperado: 4. Es botones_count

-- Linea 80
-- Esperado: botones_count = 4.

select nombre, etiqueta, uia_clave, icono
from public.vista_botones_catalogo
where categoria_id = 1
  and uia_clave = 'Design';
-- Esperado: una fila. nombre Diseno, etiqueta Diseno, icono icon_design.

-- PRUEBA 2. El mismo uia_clave se actualiza. No nace otro boton.
select '--- PRUEBA 2: actualizar boton ---' as test;

-- Linea 80
-- Esperado ahora: 4

-- 1 = Word, categorias.id.
-- La uia_clave sigue siendo Design. Cambia la etiqueta.  -- La uia Clave nunca deberia de agregarse por el usuario.
select public.fn_paleta_upsert_boton(1, 'Diseno', 'Diseno de pagina', 'Design', 'icon_design', true);
-- Esperado: 4. El conteo no sube.

select nombre, etiqueta, uia_clave
from public.vista_botones_catalogo
where categoria_id = 1
    and lower(uia_clave) = 'design';
-- Esperado: una sola fila. etiqueta = "Diseno de pagina".



