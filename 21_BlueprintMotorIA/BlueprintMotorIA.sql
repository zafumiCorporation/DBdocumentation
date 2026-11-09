-- Solo para saber que debo de aprender en el futuro
CREATE OR REPLACE FUNCTION public.fn_hay_ciclo(
    p_tutorial_id BIGINT,
    p_origen BIGINT,
    p_destino BIGINT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    -- Tabla temporal puede consultarse a si misma.
    -- Ejecuta una consulta, toma el resultado y vuelve a usar ese resultado para seguir buscando mas datos.
    -- Supongamos que tienes estas conexiones: Nodo 1 -> Nodo 2 -> Nodo 3
    -- El usuario quiere agregar Nodo 3 -> Nodo 1. Quedaria: Nodo 2-> Nodo 3 -> Nodo 1
    -- Eso es un ciclo. Si conecto origen -> destino , Podre regresar al origen caminando por las conexiones existentes?
    -- Si la respuesta es si Hay ciclo.
    WITH RECURSIVE camina AS (
        -- Supongamos p_origen  = 3 , p_destino = 1
        -- Entonces la primera fila de camina sera 1.
        SELECT p_destino AS nodo
        UNION ALL
        -- Tabla ejemplo blueprint_conexiones
        -- origen..........................destino
        -- 1...............................2
        -- 2...............................3
        -- 3...............................4
        SELECT c.destino_nodo_id
        FROM public.blueprint_conexiones AS c
        -- tabla camina
        -- nodo
        -- 1
        -- Busca quien sale de 1 ? , Encuentra 2 Agrega
        -- nodo
        -- 2
        -- Segunda vuelta , Ahora toma: 2 , Pregunta: Quien sale 2 ? , Encuentra 3 Agrega 3
        -- nodo
        -- 1
        -- 2
        -- 3
        -- Tercera vuelta , Ahora Toma 3, Pregunta: Quien sale de 3 ? , Encuentra 3 Agrega 4.
        JOIN camina AS w ON w.nodo = c.origen_nodo_id
        -- La tabla temporal camina contiene Despues de recorrer. 1 -> 2 -> 3 -> 4
        -- nodo
        -- 1
        -- 2
        -- 3
        -- 4
        WHERE c.tutorial_id = p_tutorial_id
    -- Supongamos: 1 -> 2 , 2 -> 3 , 3 -> 1  Si vuelves a visitar un nodo que ya habias visitado, marca la fila como ciclo.
    -- y automaticamente pone: is_cycle = true.
    ) CYCLE nodo SET is_cycle USING camino
    -- nodo = p_origen , Desde destino puedo regrasar al origen
    SELECT EXISTS (SELECT 1 FROM camina WHERE nodo = p_origen OR is_cycle);
$$;
