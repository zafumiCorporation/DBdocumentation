--PASO 3 PRUBAS COMO LAS HARA TU FRONTEDN 
--DASHBOAR IMAGEN 2 -- BUSCADOR GLOBAL 
select * from buscar_tutoriales('Wrod');
select * from buscar_tutoriales('video unreal'); -- 2 palabras 
select * from buscar_tutoriales('level', 'Unreal Engine'); -- chip + texto
	
-- PASO 4 PRUBAS IMAGEN 3 - Shiriaru id=1 
select * from buscar_tutoriales_perfil('',1); 				-- ENTRA AL PERFIL, SIN BUSCAR , MUESTRA TODO 
select * from buscar_tutoriales_perfil('word', 1) 			-- DENTRO DEL PERFIL BUSCA WORD 
select * from buscar_tutoriales_perfil(' ', 1, 'Word'); 	-- DENTRO DEL PERFIL TOCA CHIP Word
