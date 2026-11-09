truncate table public.tags restart identity cascade ;
INSERT INTO public.tags(nombre, slug, estado, usos_count, es_entrenable, promovido_at) values
    ('Blueprints', 'blueprints', 'activo', 9999, true, now()),
    ('Character Controller', 'character-controller', 'activo', 9999, true, now()),
    ('Platformer', 'platformer', 'activo', 9999, true, now()),
    ('Resume', 'resume', 'activo', 9999, true, now()),
    ('Hoja en Blanco', 'hoja-en-blanco', 'activo', 8500, true, now()),
    ('Third Person', 'third-person', 'activo', 8000, true, now()),
    ('Multiplayer', 'multiplayer', 'activo', 7500, true, now()),
    ('AI', 'ai', 'activo', 7000, true, now()),
    ('Beginner', 'beginner', 'activo', 6500, true, now()),
    ('Advanced', 'advanced', 'activo', 6000, true, now())

-- SI INTENTO INSERTAR UN TAG CON UN SLUG QUE YA EXISTE, NO ME DES ERROR; EN LUGAR DE ESO, ACTUALIZA LA FILA EXISTENTE
-- do update set INDICA QUE COLUMNAS SE VAN A ACTUALIZAR EN ESA FILA QUE ENTRO EN CONFLICTO
on conflict (slug) do update set
   estado = 'activo',
-- excluded TABLA TEMPORAL INVISIBLE LLAMADA excluded GUARDA LA FILA QUE SE INTENTO INSERTAR Y QUE ENTRO EN CONFLICTO
-- tags.usos_count ES EL VALOR QUE YA TENIA LA FILA EN LA TABLA , VALOR MINIMO 999
   usos_count = greatest(excluded.usos_count, tags.usos_count, 999),
   es_entrenable = true,
   promovido_at = coalesce(tags.promovido_at, now()),
   actualizado_at = now();