-- ********************* VER FUNCION POR NOMBRE ESPECIFICO 
select proname
-- ES UNA TABLA DEL CATALOGO INTERNO DE PostgreSQL 
from pg_proc 
-- proname CONTIENE TODAS LAS FUNCIONES REGISTRADAS EN LA BASE DE DATOS 
-- pronamespace , proowner , prolang , prorettype , proargtypes. 
where proname = 'on_pc_usuario_apagada'
-- pronamespace INDICA EL oid DEL ESQUEMA. CADA ESQUEMA TIENE UN IDETIFICADOR UNICO (oid)
-- not in QUE NO ESTE DENTRO DE ESTA LISTA 
-- EN ESTE CASO QUEREMOS EXCLUIR FUNCIOENS QUE ESTAN EN ESQUEMAS INTERNOS (pg_catalog, information_schema) POR QUE SON FUNCIONES DEL SISTEMA 
-- pg_namespace ES OTRA TABLA INTERNA QUE GUARDA LOS ESQUMAS DE LA BASE DE DATOS. 
	and pronamespace not in (select oid from pg_namespace where nspname in ('pg_catalog','information_schema'));

/*PRUEBAS VISUALES DE LOS 3 NUEVOS*/
select * from login_desktop('Shiriaru', 'Guatemala2026!'); --login id 1 
select * from sesiones_ram; 							   -- ves 1  

-- SE LE APAGA PC A Shiriaru (id 1) SOLO A EL 
select on_pc_usuario_apagada(1);
select * from sesiones_ram;								   -- Shiriaru borrado
select auth_token from usuarios where id=1;	
select token_expires_at from usuarios where id=1; 	