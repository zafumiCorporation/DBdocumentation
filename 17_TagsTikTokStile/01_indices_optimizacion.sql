-- 2 BUSQUEDA POR SLUG - LA MAS CRITICA DE TODO TU SISTEMA
-- A QUE FUNCION AYUDA: A fn_obtener_o_crear_tags(p_nombres text[])
-- COMO SE USA CUANDO PONES: where tags.slug in (select slug from validos) y on conflict (slug) do nothing
-- Ej: where slug = 'hoja-en-blanco' -> ENCUENTRA EL ID DE ESTE TAG EN 0.1ms
-- Ej: insert .. on conflict (slug) -> Si el usuario manda 'ue5' dos veces, no duplica.
create unique index if not exists idx_tags_slug_unique ON tags(slug);

-- 3. PATTERN MACH (TEXTO QUE EMPIEZA CON UN PREFIJO) PARA PREFIJO: ilike 'unreal%'
-- A QUE FUNCION AYUDA A fn_autocompletar_tags() -> CTE (tabla temporal en memoria) prefijo
-- COMO SE USA CUANDO PONES :  where t.slug ilike q.q_slug || '%'
-- CUANDO EL USUARIO ESCRIBE #unr Y YA LE MUESTRAS #unreal_engine
-- Ej: where slug ilike 'unreal%' -> DEVUELVE ['unreal-engine' 'unreal-engine-5'] EN 2ms
-- varchar_pattern_ops OPTIMIZA COLUMNAS PARA BUSQUEDAS CON like o ilike QUE EMPIEZAN CON UN TEXTO FIJO 'texto%'
create index if not exists idx_tags_slug_pattern ON tags(slug varchar_pattern_ops);

-- 4. AUTOCOMPLETADO TIPO TIKTOK CON TYPOS #platf -> #platformer
-- A QUE FUNCION AYUDA A  A fn_autocompletar_tags() -> CTE fuzzy
-- COMO SE USA: where t.nombre::text % q.raw
-- Ej: Usuario Escribe #bluepr Y LE SUGIERES #blueprints AUNQUE ESCRIBIO MAL
create index if not exists idx_tags_nombre_trgm_activo on tags using gin (nombre gin_trgm_ops)
where estado = 'activo';

-- 5. INDICE PARCIAL CON WHERE SOLO GUARDA LOS TAGS ACTIVOS
-- A QUE FUNCION AYUDA a fn_autocompletar_tags()
-- COMO SE USA CUANDO PONES : where estado = 'activo' ORDER BY usos_count desc
-- Ej: CUANDO EL USUARIO PONE # Y LE MUESTRAS LOS 6 TAGS MAS USADOS PRIMERO
create index if not exists idx_tags_activo_popularidad ON tags (usos_count desc, nombre asc)
-- INCLUDE SIGNIFICA QUE ADEMAS DE LAS COLUMNAS QUE ORDENAN EL INDICE , TAMBIEN ALMACENA ESTAS COLUMNAS EXTRA DENTRO DEL INDICE
include (id, slug, es_entrenable)
where estado = 'activo';

-- 6 PARA EL JOB QUE PROMUEVE TAGS Y DASHBOARD DE MODERACION CON WHERE SOLO GUARDA LOS TAGS PENDIENTES
-- A QUE FUNCION AYUDA A tu cron job y A TU dashboard /admin/tags
-- COMO SE USA CUANDO PONES: where estado = 'pediente' order by usos_count desc
-- JOB: where estado = 'pediente' and usos_count >= 100 ESTE INDICE ENCUENTRA QUE TAGS LLEGARON A 100 USOS PARA PASARLOS A 'activo'
-- DASHBOARD: where estado = 'pendiente' ORDER BY usos_count DESC LIMIT 20 -> Te muestra "Estos 20 tags nuevos son los mas usados, los apruebas o los fusionas"
create index if not exists index_tags_pendiente_usos on tags(usos_count desc)
    include (nombre, slug)
where estado = 'pendiente';

-- 7 PARA RESOLVER FUSIONES INSTATANEO (ue5 -> unreal-engine-5)
-- A QUE FUNCION AYUDA: A TU QUERY DE LECTURA DE TUTORIALES CON TAGS FUSIONADOS
-- COMO SE USA CUANDO PONES : where tags.fusionado_a_id = p_tag_id
-- Ej: Where fusionado_a_id = 15 ->  ENCUENTRA TODOS LOS TAGS QUE FUERON ABSORBIDOS POR 'unreal-engine-5'
create index if not exists idx_tags_fusionado_a_id ON tags (fusionado_a_id)
where fusionado_a_id is not null and estado = 'fusionado';

-- 8 PARA CONTAR RAPIDO 'CUANTOS TUTORIALES TIENE X TAG'
-- A QUE FUNCION AYUDA a fn_tutorial_tags_after_change()
-- COMO SE USA CUANDO PONES: Where tutorial_tags.tag_id = p_tag_id
-- LO USA EL TRIGGER PARA HACER EL pg_advisory_xact_lock y luego UPDATE tags SET usos_count
-- WHERE tag_id = 2 (Unreal) -> ENCUENTRA TODOS LOS TUTORIALES DE UNREAL SABE QUE TIENE 5000 TUTORIALES
create index if not exists idx_tutorial_tags_tag_id on tutorial_tags(tag_id);

-- 9 PARA BORRAR UN TUTORIAL EN CASCADA Y LISTAR TAGS DE UN TUTORIAL
-- A QUE FUNCION AYUDA: A delete from tutoriales where id = x (cascade)
-- COMO SE USA CUANDO PONES: WHERE tutorial_tags.tutorial_id = p_tutorial_id
-- Ej: where tutorial_tags.tutorial_id = 4 -> TRAE LOS 3 TAGS DE 'Create video Game'
create index if not exists idx_tutorial_tags_tutorial_id ON tutorial_tags (tutorial_id);

-- 10 CONVERING INDEX PARA FEED ORDENADO POR RECIENTES
-- COMO SE USA CUANDO PONES: where tag_id = 2 order by created_at desc limit 20
-- Ej: Muestra los ultimos 20 tutoriales de #platformer sin ordenar en memoria
create index  idx_tutorial_tags_tag_created ON tutorial_tags(tag_id, created_at desc);

-- 10 ANTI-SPAM Y AUDITORIA - QUIEN PUSO QUE TAG Y CUANDO
-- A QUE FUNCION AYUDA A TU SISTEMA ANTI-SPAM y a fn_tutorial_tags_after_change()
-- PARA PREVENIR QUE UN USUARIO HAGA SPAM DEL MISMO TAG 100 VECES EN 1 HORA
-- COMO SE USA CUANDO PONES: where created_by = p_user_id and created_at > now() - interval '1 hour'
create index if not exists idx_tutorial_tags_created_by_at on tutorial_tags (created_by, created_at desc);
create index if not exists idx_tutorial_tags_created_at on tutorial_tags (created_at desc);