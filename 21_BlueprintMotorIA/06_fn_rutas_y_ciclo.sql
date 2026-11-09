-- 08 - Ciclo (cycle sobre la secuencia)
create or replace function public.fn_hay_ciclo_secuencia(
    p_secuencia text[], -- Lista de paso (claves de nodos) que forma la ruta
    p_cerrada boolean default false -- cerrada = true -> el ultimo nodo conecta de nuevo al primero. false -> la ruta debe termina en un nodo distinto al inicial
)
returns boolean
language sql
immutable
set search_path = ''
as $$
    -- Deteccion de duplicados , Devuelve true si hay duplicados , false si no.
    select exists(
        select 1
        -- unnest(p_secuencia) -> convierte el arreglo p_secuencia en filas, cada fila es un paso.
        -- with ordinality -> Agrega un numero de orden (1,2,3...) a cada paso.
        -- clave -> el valor del paso (ejemplo: "Insertar")
        -- ord -> la posicion en la secuencia (ejemplo: 1,2,3..)
        from unnest(p_secuencia) with ordinality as u(clave, ord)
        group by clave -- Agrupa los pasos por su nombre (ejemplo: "Insertar").
        having count(*) > 1 -- Detecta si algun paso aparece mas de una vez
    )
    -- Validacion de cierre incorrecto
    or (
        -- cerrado=true: fin apunta a inicio a proposito (doble circulo -> entry).
        -- p_cerrada = false -> not p_cerrada -> not false = true
        (not p_cerrada) -- Indica que la ruta no esta marcada como cerrada.
        -- cardinality(p_secuencia) -> Devuelve el numero de elementos en la secuencia.
        and cardinality(p_secuencia) >= 2 -- Asegura que haya al menos 2 pasos
        -- Compara el primer paso con el ultimo, Si son iguales y la ruta no esta marcada como cerrada -> es un ciclo incorrecto.
        and p_secuencia[1] = p_secuencia[cardinality(p_secuencia)]
    );
$$;
-- PRUEBA 1 validar que una ruta no contenga ciclos no permitidos.
-- Objetivo: Verificar que fn_hay_ciclo_secuencia() detecte correctamente cuando una secuencia
-- de nodos vuelve a pasar por el mismo nodo.
-- Estado inicial: No modifica tablas. No crea rutas , No crea nodos.
-- Accion: Evaluar dos secuencias : 1. insertar -> pagina-en-blanco , 2. insertar -> pagina-en-blanco -> insertar.
-- Resultado esperado: La primera devuelve False porque no tiene ciclos.
select '--- PRUEBA 1: detectar ciclo ---' as test;

-- Las claves ya estan normalizadas, como quedaron en el borrador.
-- false = la ruta no esta marcada como cerrada.
select public.fn_hay_ciclo_secuencia(array['insertar', 'pagina-en-blanco'], false) as hay_ciclo;
-- Esperado: false.

-- La segunda True por que vuelve a pasar por un nodo ya visitado.
select public.fn_hay_ciclo_secuencia(array['insertar', 'pagina-en-blanco', 'insertar'], false) as hay_ciclo;
-- esperado: true.

-- Rutas (Secuencia completa en el mismo documento)
create or replace function public.fn_agregar_ruta(
    p_yo bigint, -- Id del usuario que esta agregando la ruta.
    p_tutorial_id bigint, -- Id del tutorial donde se guardara la ruta.
    p_nombre text, -- Nombre de la ruta (ejemplo: "margenes", "marca-de-agua"). Sirve para Identificarla.
    p_secuencia text[], -- Lista de claves de nodos que forman la ruta, en orden. Ejemplo: ["Insertar", "pagina-blanco"]
    p_cerrada boolean default false -- Indica si la ruta es cerrada (el ultimo nodo conecta de nuevo al primero). Por defecto es false.
)
returns int
language plpgsql
set search_path = ''
as $$
declare
    v_orden int;
    v_ruta jsonb;
begin
    -- Llama a otra funcion que revisa si la secuencia tiene un ciclo incorrecto.
    if public.fn_hay_ciclo_secuencia(p_secuencia, p_cerrada) then
        raise exception 'Secuencia con ciclo interno';
    end if;

    -- Calcula el numero de la nueva ruta
    -- coalesce(..., 0) -> si no hay rutas (null), devuelve 0.
    -- +1 -> suma 1 para asignar el numero de orden de la nueva ruta.
    select coalesce(jsonb_array_length(rutas), 0) + 1
    into v_orden
    from public.lienzo_borrador_ram
    where tutorial_id = p_tutorial_id
    and editor_id = p_yo;

    -- Construir la ruta
    v_ruta := jsonb_build_object(
        'orden', v_orden,
        'nombre', public.fn_normalizar_slug(p_nombre::public.citext),
        -- Convierte el arreglo de texto p_secuencia en un JSON
        'secuencia', to_json(p_secuencia),
        'cerrada', p_cerrada
    );

    --Guardar la ruta
    update public.lienzo_borrador_ram
    set rutas = rutas || jsonb_build_array(v_ruta),
        saved_at = now()
    where tutorial_id = p_tutorial_id
    and editor_id = p_yo;

    return v_orden;
end;
$$;

-- PRUEBA 2. Crear una ruta dentro del blueprint.
-- Objetivo: Verificar que fn_agregar_ruta() almacene correctamente , una secuencia valida de nodos dentro del borrador.
-- Estado inicial: Existen los nodos: insertar , pagina-en-blanco
-- Accion: Crea una ruta llamada: camino-principal
-- formada por la secuencia: insertar -> pagian-en-blanco
-- Resultado esperado: Se agrega una nueva ruta al JSON rutas.
-- orden = 1. nombre = camino-principal. cerrada = false.
-- La secuencia conserva el orden de los nodos.
-- Nota: La ruta describe el recorrido que seguira el usuario dentro del tutorial.
select '--- PRUEBA 2: agregar ruta ---' as test;

select jsonb_array_length(rutas) as rutas
from public.lienzo_borrador_ram
where tutorial_id = 1
and editor_id = 1;
-- Esperado ahora 0.

-- 1 = Shiriaru, usuarios.id.
-- 1 = "Create Sheet in Word", tutoriales.id.
-- 'Camino principal' se normaliza a camino-principal.
-- La secuencia usa las claves del borrador, no el texto visible.
-- false = no es una ruta cerrada.
select public.fn_agregar_ruta(1,1, 'Camino principal', array['insertar', 'pagina-en-blanco'], false);
-- Esperado: 1. Es el orden de la ruta.

select elem->>'orden' as orden, elem->>'nombre' as nombre, elem->'secuencia' as secuencia, elem->>'cerrada' as cerrada
from public.lienzo_borrador_ram as r
cross join lateral jsonb_array_elements(r.rutas) as elem
where r.tutorial_id = 1;
-- Eperado: una fila. orden 1, nombre camino-principal,
-- secuencia ["insertar", "pagina-en-blanco"], cerrada false.

-- PRUEBA 3 Rechazar una ruta con ciclos internos.
-- Objetivo: Verificar que fn_agregar_ruta() impida alamacenar , rutas que contienen nodos repetidos.
-- Estado inicial: Existe una ruta valida , El total de rutas es 1.
-- Accion: Intenta crear la secuencia: insertar -> insertar
-- Resultado esperado: fn_hay_ciclo_secuencia() devuelve TRUE.
-- Se lanza la excepcion: "Secuencia con ciclo interno"
-- La nueva ruta no se guarda. El total de rutas continua siendo 1.
-- Nota: Esto evita flujos invalidos que podrian provocar recorridos infinitos dentro del tutorial.
select '--- PRUEBA 3: rechazar ciclo ---' as test;

select jsonb_array_length(rutas) as rutas
from public.lienzo_borrador_ram
where tutorial_id = 1;
-- Esperado ahora: 1.

-- 1 = Shiriaru. 1 = "Create Sheet in Word".
-- insertar esta dos veces. fn_hay_ciclo_secuencia devuelve true y esta funcion aborta.
do $$
begin
    perform public.fn_agregar_ruta(1,1, 'Ruta mala', array ['insertar', 'insertar'], false);
    raise exception 'FALLO: guardo una ruta con ciclo';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK ciclo rechazado: %', sqlerrm;
end;
$$;
-- esperado en Messages; OK ciclo rechazado: Secuencia con cilco interno.

select jsonb_array_length(rutas) as rutas
from public.lienzo_borrador_ram
where tutorial_id = 1;
-- Esperado: sigue en 1. No nacio "ruta-mala".

