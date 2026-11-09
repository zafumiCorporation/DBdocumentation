-- PRUEBAS
-- TEST 1: AUTOCOMPLETE PREFIJO PERFECTO (usa idx_tags_slug_pattern + idx_tags_activo_popularidad)
-- Ej: Usuario escribe #blue -> Esperas [Blueprints]
SELECT '--- TEST 1: Prefijo blue ---' as test;
select * from public.fn_autocompletar_tags('blue', 6)
-- HERRAMIENTA DE PostgreSQL PARA VER COMO SE EJECUTA UNA CONSULTA
explain analyze select * from public.fn_autocompletar_tags('blue', 6);

-- TEST2 AUTOCOMPLETE CON TYPO (usa idx_tags_nombre_trgm_activo)
-- Ej: USUARIO ESCRIBE #blueprints MAL ESCRITO -> ESPERAS [Blueprints] POR SIMILITUD
select '--- TEST 2: Typo blueprints ---' as test;
select * from public.fn_autocompletar_tags('bloprints', 6);
select public.similarity('Blueprints' , 'bloprints') as score;

-- TEST 3: AUTOCOMPLETE VACIO "#" (usa solo idx_tags_activo_popularidad)
-- ej: DEBE DEVOLVER LOS 6 MAS POPULARES EN < 1ms CON Index Only Scan
select '--- TEST 3: Solo # (mas populares) ---' as test;
select id, nombre, slug, usos_count FROM public.tags where estado = 'activo' ORDER BY usos_count desc limit 6;
explain analyze select id, nombre, slug, usos_count FROM public.tags where estado = 'activo' ORDER BY usos_count desc limit 6;

-- TEST 4: CREAR TAGS DESDE BACKEND (USA idx_tags_slug_unique)
-- A QUE FUNCION AYUDA: fn_obtener_o_crear_tags()
-- Ej: POST /tutoriales con ["#Platformer", "ue5", "Blueprints"] -> DEBE DEVOLVER 3 IDs, crear solo ue5 EN PEDIENTE
select '--- TEST 4: OBTENER O CREAR ---' as test;
select * from public.fn_obtener_o_crear_tags(ARRAY['#Platformer', 'ue5', 'Blueprints', ' ', '!!!']);
-- VERIFICA QUE ue5 NACIO PENDIENTE CON 0 USOS.
select nombre, slug, estado, usos_count from public.tags where slug = 'ue5';

-- TEST 5: TRIGGER DE PROMOCION (usa idx_tutorial_tags_id + pg_advisory_xact_lock)
-- A QUE FUNCION AYUDA: fn_tutorial_tags_after_change()
-- SIMULA QUE 100 TUTORIALES USAN 'ue5' Y DEBE PASAR A ACTIVO AUTOMATICAMENTE

-- TEST 6: DASHBOARD DE MODERACION (usa index_tags_pendiente_usos)
-- A QUE FUNCION AYUDA: TU QUERY DE ADMIN
-- COMO SE USA: where estado = 'pendiente' order by usos_count desc limit 20.
select '--- TEST 6: DASHBOARD PENDIENTES ---' as test;
select nombre, slug, usos_count from public.tags where estado = 'pendiente' order by usos_count desc limit 20;
explain analyze select * from public.tags where estado = 'pendiente' order by usos_count desc limit 20;