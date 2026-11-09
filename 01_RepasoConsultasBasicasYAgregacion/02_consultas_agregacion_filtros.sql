-- SELECT BASICO 
-- USO DE SELECT Y FROM 
select * 					-- SELECT QUE COLUMNA QUIERO VER 
from tutoriales; 			-- FROM DE QUE TABLA SACO LOS DATOS 

-- WHERE + AGRUPACION 
-- Objetivo final: ¿Cuántos tutoriales hay por categoría, cuál es su duración promedio y cuáles categorías son las más populares?

-- Solo queremos tutoriales públicos y con duración conocida: 
select categoria,				
	   duracion_min , 			
       likes_count 				
from tutoriales n_min is not null
	and es_publico = true; 
       

-- Agrupa (GROUP BY)
select categoria, 
	   COUNT(*) as total_tutoriales, 			-- Cuantos tutoriales hay por categoria.
	   AVG(duracion_min) as duracion_promedio   -- Cual es su duracion promedio. 
from  tutoriales 
where duracion_min is not null 
	and es_publico = true 
-- COUNT(*) y el AVG(duracion_min) se calculan por cada categoría
group by categoria; 

-- FILTRA GRUPOS (HAVING)
select 
	categoria, 
	count(*) as total_tutoriales, 				-- Cuantos tutoriales hay por categoria.
	avg(duracion_min) as duracion_promedio 		-- Cual es su duracion promedio.
from tutoriales 
where duracion_min is not null 
	and es_publico = true 
group by categoria 
-- FILTRA LOS GRUPOS YA FORMADOS , SOLO MUESTRA LAS CATEGORIAS QUE TIENEN MAS DE UN TUTORIAL
having count(*) > 1 
-- ORDENA LOS VALORES POR COLUMNA 
-- DESC DESCENDENTE DE MAYOR A MENOR 
-- ASC ASCENDENTE DE MENOR A MAYOR 
order by total_tutoriales desc;


-- EJERCICIO COMPLETO - AGRUPACION AVANZADA CON FILTER  
select 
	categoria, 
	count(*) as total_tutoriales, 				-- Cuantos tutoriales hay por categoria.
	count(distinct titulo) as titulos_unicos, 	-- Cuantos titulos unicos (practica DISTINCT)
	avg(duracion_min) as duracion_promedio,     -- Duracion promedio por categoria.
	sum(ejecuciones) as total_ejecuciones, 		-- Total de ejecuciones (popularidad) 	
	min(likes_count) as menos_likeado,			-- Tutorial con menos likes 
	max(likes_count) as mas_likeado,			-- Tutorial con mas likes
	-- FILTER CUENTA PERO UNICAMENTE LOS QUE CUMPLE ESTA CONDICION 
	-- WHERE SELECCIONA SOLO LOS TUTORIALES CUYA DURACION ES MAYOR A 20 
	count(*) filter (where duracion_min > 20) as tutoriales_largos,		
	-- WHERE SELECCIONA SOLO LOS TUTORIALES CON MAS DE 100 LIKES  
	count(*) filter (where likes_count > 100) as tutoriales_populares 	-- cuántos superan 100 likes
from tutoriales 
where es_publico = true							-- solo tutoriales públicos
group by categoria 								-- agrupamos métricas por categoría
having count(*) >=2								-- solo categorías con al menos 2 tutoriales
order by total_ejecuciones desc;				-- ordenamos por popularidad (ejecuciones)


-- TUTORIAL CON MAS LIKES 
select 
	titulo, 									-- NOMBRE DEL TUTORIAL 
	likes_count, 								-- NUMERO DE LIKES 
	categoria, 									-- CATEGORIA A LA QUE PERTENECE 
	ejecuciones									-- NUMERO DE EJECUCIONES (POPULARIDAD)
from tutoriales
where es_publico = true 						-- SOLO TUTORIALES PUBLICOS
	and likes_count is not null 				-- EXCLUEY LOS TUTORIAS SIN LIKES (NULL) 
order by likes_count desc               		-- ORDENAMOS DE MAYOR A MENOR LIKES 
limit 3;										-- MOSTRAMOS LOS 3 MAS POPULARES POR LIKES. 

-- Reto extra: practica con valores NULL en la tabla tutoriales 
select 
	count(*) as filas_totales, 
	count(likes_count) as likes_con_valor,		-- CUENTA SOLO LOS QUE NO SON NULL 
	count(*) filter (where likes_count is null) as likes_nulos, -- CUANTOS TIENEN LIKES EN NULL
		avg(likes_count) as promedio_likes		-- promedio de likes (ignora null)
from tutoriales; 

