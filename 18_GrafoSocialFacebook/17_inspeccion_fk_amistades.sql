-- Llaves foraneas entre 'amistades' y usuarios
-- Muestra que columna en 'amistades' apunta a que columna en 'usuarios'.
SELECT
    -- relname = NOMBRE DE LA TABLA , attname = NOMBRE DE LA COLUMNA
    -- origen (amistades) , destino (usuarios)
    origen.relname       AS tabla_origen,
    att_origen.attname   AS columna_origen,
    destino.relname      AS tabla_destino,
    att_destino.attname  AS columna_destino
--pg_constraint GUARDA TODAS LAS RESTRICCIONES (PRIMARY KEY , FOREING KEY, UNIQUE, CHECK)
FROM pg_constraint AS c
-- pg_class GUARDA INFORMACION DE LA TABLAS
INNER JOIN pg_class AS origen-- OBTENER TODAS LAS RESTRICCIONES DE LA TABLA amistades
            -- oid IDENTIFICADOR UNICO DE CADA TABLA
            -- conrelid id de la tabla que tiene la restriccion (amistades)
    ON origen.oid = c.conrelid
INNER JOIN pg_class AS destino-- OBTENER TODAS LAS RESTRICCIONES DE LA TABLA usuarios
    ON destino.oid = c.confrelid
--pg_namespace catalogo que guarda los esquemas(carpetas)
INNER JOIN pg_namespace AS n
            -- relnamespace = id del esquema donde vive la tabla amistades
    ON n.oid = origen.relnamespace
-- unnest funcion que expande un arreglo en filas.
-- c.conkey lista de columnas de la tabla amistad que forman la foreing key.
-- c.confkey lista de columnas de la tabla usuarios a las que apunta la foreing key.
-- as cols(...) apodo para esas dos listas , con nombre origen_attnum y destino_attnum
JOIN LATERAL unnest(c.conkey, c.confkey) AS cols(origen_attnum, destino_attnum) ON true
-- pg_attribute GUARDA LAS COLUMNAS DE CADA TABLA.
INNER JOIN pg_attribute AS att_origen
    --attrelid ID DE LA TABLA A LA QUE PERTENECE LA COLUMNA
    --attnum NUMERO INTERNO DE LA COLUMNA
    ON att_origen.attrelid = c.conrelid
   AND att_origen.attnum   = cols.origen_attnum
INNER JOIN pg_attribute AS att_destino -- PARA TABLA USUARIOS
    ON att_destino.attrelid = c.confrelid
   AND att_destino.attnum   = cols.destino_attnum
-- c.contype tipo de restriccion 'f' significa foreing key.
WHERE c.contype = 'f'
  --  n.nspname = 'public' SOLO TABLAS EN EL ESQUEMA PUBLICO
  AND n.nspname = 'public'
  AND origen.relname = 'amistades'
  AND destino.relname = 'usuarios'
ORDER BY att_origen.attname;