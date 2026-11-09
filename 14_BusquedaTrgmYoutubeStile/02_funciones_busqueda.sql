drop function buscar_tutoriales(text , text);
-- 2.1 BUSCADOR REAL TIPO YOUTUBE - UNA SOLA FUNCION PARA 40K PALABRAS  
-- p_query = LO QUE ESCRIBE EL USUARIO EN TU BARRA , EJ : 'video unreal', 'wrod', 'hoja blanko'
-- p_categoria = CHIP QUE TOCA [Word, Unreal Engine] , default null SIGNIFICA QUE SI NO TOCA NINGUN CHIP VIENE VACIO Y BUSCA EN TODAS. 
create or replace function buscar_tutoriales(p_query text, p_categoria text default null)
returns table(id bigint, titulo varchar, categoria varchar, thubnail_url text, score real) as $$
declare 
-- trim(p_query) CORTA LOS EPACIOS FEOS AL INICIO Y FINAL , " video " lo deja como "video"
	v_q text := lower(public.immutable_unaccent(trim(p_query)));
begin
--set_config FUNCION DE POSTGRES QUE CAMBIA UNA CONFIGURACION EN MEMORIA ('clave', 'valor', true)
--pg_trgm.word_similarity_threshold QUE TAN PARECIDO DEBE SER UNA PALABRA DENTRO DE UN TEXTO LARGO
	perform set_config('pg_trgm.word_similarity_threshold', '0.15', true);
-- pg_trgm.similarity_threshold DEFINE QUE TAN PARECIDO DEBE SER TODO EL TEXTO CONTRA TODO EL TEXTO
	perform set_config('pg_trgm.similarity_threshold', '0.1', true);

-- NO RETORNA UN ARCHIVO DE TEXTO , RETORNA EL RESULTADO DEL SELECT.
	return query
	select 
		t.id, t.titulo , t.categoria , t.thumbail_url, 
--greates DEVUELVE EL VALOR MAS GRANDE DE LA LISTA QUE LE PASAS greatest(0.2, 0.8) = 0.8
		(greatest(
--word_similarity(v_q,texto) v_q APARECE COMO UNA PALABRA PARECIDA DENTRO DE UN TEXTO LARGO.
-- BUSCA PALABRAS INDIVIDUALES  DE TU QUERY  (vudeo, unreal, engine) Y COMPARA CONTRAS LAS PALABRAS DEL TEXTO LARGO 
-- (create, video, game, in, unreal, engine). SALIDA UN NUMERO EJ. 0.75
			word_similarity(v_q, lower(public.immutable_unaccent(t.titulo || ' ' || coalesce(t.descripcion,'') || ' ' || t.categoria))),
--similarity(v_q, texto) PARECIDO GENERAL ENTRE DOS TEXTOS COMPLETOS 
			similarity(v_q, lower(public.immutable_unaccent(t.titulo || ' ' || coalesce(t.descripcion,'') || ' ' || t.categoria)))
--::real CONVIERTE EL RESULTADO DE SIMILARITY A REAL. 
-- + LE SUMAS SI EL TITULO CONTIENE LITERAL LA BUSQUEDA 
-- case when CUANDO SE CUMPLA ESTO 
		) + case when lower(public.immutable_unaccent(
-- like BUSCA TEXTO PERO DISTINGUE MAYUSCULAS
-- ilike BUSCA TEXTO PERO NO DISTINGUE MAYUSCULAS
-- text% EMPIEZA CON text
-- %text TERMINA CON text
-- %text% CONTIENE text EN CUALQUIER PARTE
-- case when t.titulo contiene v_q
			t.titulo)) ilike '%' || v_q || '%' then 0.3 else 0 end)::real as s
	from tutoriales t
	where
--ESTA LINEA ES LA CLAVE PARA USAR EL INDICE GIN 
-- % SIGNIFICA ES PARECIDO DEVUELVE TRUE SI EL TEXTO LARGO SE PARECE A TU BUSQUEDA
--  COMO 0.8 > 01 DEVUELVE TRUE 
	(lower(public.immutable_unaccent(t.titulo || ' ' || coalesce(t.descripcion,'') || ' ' || t.categoria)) % v_q
--<% CONTINE UNA PALABRA PARECIDA
-- v_q <% MI BUSQUEDA CORTA v_q ESTA CONTENIDA COMO PALABRA PARECIDA DENTRO DEL TEXTO LARGO
	OR v_q <% lower(public.immutable_unaccent(t.titulo || ' ' || coalesce(t.descripcion,'') || ' ' || t.categoria)))
	and (p_categoria is null or t.categoria = p_categoria) -- USA MAPA idx_tutoriales_categoria.
	order by s desc, t.likes_count desc 
	limit 10;	
end; $$ language plpgsql;

-- 2.3 BUSCADOR DE PERFIL - PARA TU IMAGEN 3 - PERFIL Shiriaru 
-- SE ACTIVA CUANDO DAN CLICK EN UN PERFIL. SIEMPRE FILTRA POR  creador_id. 
-- SI EN PERFIL Shiriaru BUSCAN "word" SOLO TRAE TUTORIALES DE Shiriaru 
-- SI TOCAN CHIP [word] TRAE SOLO LOS DE Word de Shiriaru 

drop function buscar_tutoriales_perfil(text, bigint, text);
create or replace function buscar_tutoriales_perfil(p_query text, p_creador_id bigint , p_categoria text default null)
returns table(id bigint, titulo varchar, categoria varchar, score real) as $$ 
declare v_q text := lower(public.immutable_unaccent(trim(p_query)));
begin 
	perform set_config('pg_trgm.word_similarity_threshold', '0.15', true);
	perform set_config('pg_trgm.similarity_threshold', '0.1', true);
	
	return query 
	select
		t.id, t.titulo, t.categoria,
		greatest(
			word_similarity(v_q, lower(public.immutable_unaccent(t.titulo || ' ' || coalesce(t.descripcion,'') || ' ' || t.categoria))),
			similarity(v_q, lower(public.immutable_unaccent(t.titulo || ' ' || coalesce(t.descripcion,'') || ' ' || t.categoria)))
		):: real as s 
	from tutoriales t
	where t.creador_id = p_creador_id 		--OLBIGATORIO SOLO DE ESTE USUARIO idx_tutoriales_creador
		and(
			v_q = ''						--SI LA BARRA ESTA VACIA, MUESTRA TODOS COMO EN MI DISEÑO
			or lower(public.immutable_unaccent(t.titulo || ' ' || coalesce(t.descripcion,'') || ' ' || t.categoria)) % v_q
			or v_q <% lower(public.immutable_unaccent(t.titulo || ' ' || coalesce(t.descripcion,'') || ' ' || t.categoria))
		)
		and (p_categoria is null or t.categoria = p_categoria)			-- USA idx_tutoriales_categoria. 
	order by s desc, t.created_at desc 
	limit 20;
end; $$ language plpgsql;
