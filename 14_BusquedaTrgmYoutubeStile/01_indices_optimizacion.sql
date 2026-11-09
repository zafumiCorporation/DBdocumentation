-- ***************************************************************************
-- ************* PRACTICA pg_trgm [COMO LO HACE YOUTUBE SEARCH] **************
-- ***************************************************************************

-- PASO 1 PARA QUE EL FEED VUELE (COMO TIKTOK/YOUTUBE home) 

-- MPA 1 idx_tutoriales_categoria PARA FILTRAR POR CATEGORIA (chips) RAPIDO
-- index ESTRUCTURA QUE ORGANIZA DATOS PARA ENCONTRARLOS MAS RAPIDO. IR DIRECTO AL CAPITULO
-- COMO SE USA: Cuando en tu funcion pones WHERE t.categoria = p_categoria
-- POR QUE SE USA: Porque t.categoria ES EXACTAMENTE IGUAL A LO QUE TIENES DENTRO on tutoriales(categoria)  
-- on tutoriales(categoria) DONDE LO CREAS EN LA TABLA tutoriales Y SOBRE LA COLUMNA categoria. 
create index if not exists idx_tutoriales_categoria on tutoriales(categoria);
-- idx_tutoriales_creador PARA VER EL PERFIL DE CREADOR RAPIDO IMAGEN 3 
-- COMO SE USA: CUANDO EN TU FUNCION PONES WHERE t.creador_id = p_creador_id
create index if not exists idx_tutoriales_creador on tutoriales(creador_id);
-- idx_tutoriales_publico_fecha PARA FEED PUBLICO ORDENADO POR FECHA (WHERE es_publico=true)
-- COMO SE USA: CUANDO TU FUNCION PONE WHERE t.es_publico = true ORDER BY t.fecha_publicacion DESC
create index if not exists idx_tutoriales_publico_fecha on tutoriales(es_publico , fecha_publicacion DESC) where es_publico = true;
-- idx_tutoriales_trgm ESTE ES EL CLAVE: GIN CON gin_trgm_ops PARA BUSQUEDA CON TYPOS
-- COMO SE USA: CUANDO EN TU FUNCION PONES WHERE t.titulo % 'Wrod' o WHERE 'Wrod' <% t.titulo 
-- gin BUSQUEDAS DE TEXTO Y ARRAYS , TYPOS AUNQUE EL USUARIO ESCRIBA MAL O INCOMPLETO EL SISTEMA PUEDA ENCONTRAR COINCIDENCIA APROXIMADAS 
-- gin_trgm_ops DIVIDE titulo EN TRIGRAMAS ej: 'Word' -> {' W',' Wo', 'ord', 'rd '}
create index if not exists idx_tutoriales_titulo_trgm on tutoriales using gin (titulo gin_trgm_ops);
-- PUEDES BUSCAR EN TITULO , DESCRIPCION Y CATEGORA AL MISMO TIEMPO [COMO YOUTUBE BUSCA EN TITULO Y DESCRIPCION]
-- COMO SE USA: CUADO PONES LA MISMA FORMULA WHERE lower(public.immutable_unaccent(t.titulo || ' ' || coalesce(t.descripcion,'') || ' ' || t.categoria)) % v_q
create index if not exists idx_tutoriales_busqueda_total 
-- EL INDICE SE APLICA SOBRE LA TABLA tutoriales 
on tutoriales 
using gin (
-- (lower()) CONVIERTE TODO EL TEXTO A MINUSCULAS , ASI “Word” y “word” SE CONSIDERAN IGUALES
-- titulo || ' ' || coalesce(descripcion,'') || ' ' || categoria CONCATENA VARIAS COLUMNAS EN UNA SOLA
-- || ' ' || OPERADOR DE CONCATENACION AÑADE UN ESPACIO ENTRE VALORES 
-- coalesce(a, b) DEVUELVE a si no es nulo , si es nulo devuelve b.
	(lower(public.immutable_unaccent(
		titulo || ' ' || coalesce(descripcion,'') || ' ' || categoria
	))) gin_trgm_ops
);

-- DEVOLVER TODOS LOS INDICES ASOCIADOS A LA TABLA tutoriales CON SU DEFINICION 
select indexname , indexdef 
from pg_indexes 
where tablename = 'tutoriales';
