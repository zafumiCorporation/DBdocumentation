-- ****************************************************
-- *******EJERCICIO 1 REGISTRO [bcrypt cost 12]********
-- ****************************************************
update usuarios 
-- crypt(...) funcion que cifra la contraseña. 
-- gen_salt GENERA UN SALT ESO UN FRAGMENTO DE DATOS ALETORIOS QUE SE AGREGA A LA CONTRASEÑA ANTES DE CIFRARLA 
-- 'bf' ALGORITMO bcrypt  DISE;ADO PARA PROTEGER CONTRASE;AS EN SISTEMAS INFORMATICOS 
-- 12 NIVEL DE SEGURIDAD   
set password_hash = crypt('Guatemala2026!', gen_salt('bf', 12)),  
handle = '@Shiriaru' 
where id = 1;

-- *********** EJERCICIO 2 LOGIN CREA TOKEN DE 8 HORAS + SESION RAM **************
-- ESTO ES LO QUE HACE TU BACKEND CUANDO EL USUARIO PONE PASSWORD CORRECTO 
-- OR REPLACE SI LA FUNCION YA EXISTE LA REMPLAZA CON ESTA NUEVA FUNCION. 
-- FUCTION DEFINES UNA FUNCION 
-- login_desktop NOMBRE DE LA FUNCION. 
-- (p_username text, p_password text) PARAMETROS QUE RECIBE LA FUNCION AMBOS DE TIPO TEXTO. 
create or replace function login_desktop(p_username TEXT , p_password TEXT)
-- return table LA FUNCION DEVUELVE UNA TABLA TEMPORAL CON COLUMNAS. 
-- token text COLUMNA DE TIPO TEXTO. 
-- expira_en TIMESTAMPTZ COLUMNA DE TIPO FECHA/HORA CON ZONA HORARIA. 
-- as INDICA QUE A CONTINUACION VIENE EL CODIGO DE LA FUNCION. 
-- $$ DELIMITADORES QUE MARCAN EL INICIO Y FIN DEL BLOQUE DE CODIGO 
returns table(token text, expira_en  timestamptz) as $$
-- DECLARE SECCION DONDE DEFINES VARIABLES INTERNAS DE LA FUNCION. 
declare v_id bigint;
declare v_token text;
-- BEGIN INICIO DEL CUERPO DE LA FUNCION (DONDE VA LA LOGICA)
begin 
-- select id LE DICE A POSTGRES BUSCA Y TRAEME DATOS DE LA COLUMNA id 
-- into GUARDA EL RESULTADO DENTRO DE UNA VARIABLE v_id VARIABLE INTERNA QUE GUARDA EL ID QUE SE ENCONTRO 
	select id into v_id 
	from usuarios 
-- username COLUMNA DE TU TABLA , p_username PARAMETRO DE TIPO TEXTO 
-- password_hash COLUMNA DE MI TABLA , crypt(p_password, password_hash) AGARRA p_password LO CIFRA USANDO EL MISMO SALT QUE ESTA DENTRO DEL password_hash
	where username = p_username and password_hash = crypt(p_password, password_hash) and activo = true;

	-- then ENTONCES , raise DETEN TODO Y AVISA , exception TIPO DE AVISO ERROR GRAVE QUE ROMPE LA FUNCION Y NO DEJA SEGUIR.  
	-- end if : CIERRA EL IF. 
	if v_id is null then raise exception 'Credenciales invalidas'; end if;

-- CREAMOS TOKEN DE 8 HORAS EN TABLA PERSISTENTE 
	v_token := encode(gen_random_bytes(32), 'hex');

	update usuarios
		-- auth_token COLUMNA DE TU TABLA DONDE GUARDAS EL TOKEN TEMPORAL. ES EL TOKEN QUE TU APP DE ESCRITORIO GUARDA EN RAM  
		set auth_token = v_token, 
		-- now() FUNCION QUE DEVUELVE FECHA Y HORA ACTUAL CON ZONA HORARIA. 
		-- interval TIPO DE DATO DE POSTGRES PARA DURACION DE TIEMPO. 
		-- 8 HORAS DE DURACION.   
		token_expires_at = now() + interval '8 hours'
	where id = v_id;

-- CREAMOS SESSION RAM QUE MUERE SI SE APAGA LA PC 
	-- insert into INDICA QUE VAS A INSERTAR, CREAR UNA FILA NUEVA EN UNA TABLA. 
	-- sessiones_ram LA TABLA RAM UNLOGGED QUE CREASTE , usuario_id COLUMNA EN LA TABLA sessiones_ram. 
	insert into  sesiones_ram (usuario_id, last_seen_at) values (v_id, now()) 
	-- on conflict (usuario_id) LA COLUMNA DONDE CHECAS EL CONFLICTO 
	-- do update ACCION SI HAY CONFLICTO , set INDICA QUE COLUMNAS VAS A ACTUALIZAR EN ESA FILA 
	-- last_seen_at COLUMNA DE ULTIMA VEZ VISTO ACTIVO 
	on conflict (usuario_id) do update set last_seen_at = now();

	-- query RESULTADO DE UN SELECT 
	return query select u.auth_token, u.token_expires_at from usuarios u where u.id = v_id;

-- END FIN DEL CUERPO DE LA FUNCION 
-- LANGUAGE PLPGSQL ESPECIFICA QUE LA FUNCION ESTA ESCRITA EN PL/pgSQL 
end; $$ language plpgsql; 

-- ************** EJERCICIO 4 CERRAR SESION [REGLA: EXPIRA AL CERRAR SESION] **************
create or replace function logout_desktop(p_user_id bigint) 
returns void as $$
begin 
	update usuarios
	set auth_token = null ,
	token_expires_at = null 
	where id = p_user_id;

	-- delete from BORRA FILAS 
	delete from sesiones_ram where usuario_id = p_user_id;
end; $$ language plpgsql;

-- ************** EJERCICIO 5 JOB DE LIMPIEZA [REGLA: EXPIRA A LAS 8 HORAS] ****************
/* COMO LO HACE X.com / INSTAGRAM -JOB QUE CORRE CADA 5 MINUTOS CON pg_cron
   pg_cron UN SCRIP EXTERNO QUE SE CONECTA CADA X MINUTOS , LE DICES A POSTGRES "EJECUTA ESTE SQL CADA NOCHE A LAS 3am"
 * SI EL USUARIO NO CERRO SESION PERO PASARON 8 HORAS SE INVALIDA SOLO */
create or replace function job_limpieza_8h() 
returns void as $$
begin 
	delete from sesiones_ram 
	where last_seen_at < now() - interval '8 hours';

	update usuarios 
	set auth_token = null,
	token_expires_at = null 
	where token_expires_at < now(); 
end; $$ language plpgsql;

-- ************** EJERCICIO 6 PC APAGADA [REGLA:EXPIRA AL APAGAR PC - FAANG]
create or replace function on_pc_usuario_apagada(p_user_id bigint) 
returns void as $$
begin  
	-- exists (select 1) PREGUNTA EXISTE AL MENOS UNA FILA PARA ESTEE USUARIO ?  RETORNA TRUE O FALSE 
	if exists (select 1 from sesiones_ram where usuario_id = p_user_id) then

	delete from sesiones_ram 
	where usuario_id = p_user_id;

	-- UPDATE BORRA TODOS LOS auth_token HUERFANOS QUE QUEDARON SIN SESSION RAM 
	-- ASI AUNQUE FALTABAN 5 HORAS PARA LAS 8 HORAS, AL APAGAR PC EXPIRA Y PIDE LOGIN
	update usuarios set auth_token = null, 
	token_expires_at = null 
	where id = p_user_id;
	end if;
	
	-- perform SE USA PARA EJECUTAR UNA FUNCION Y QUE NO DEVUELVE NADA. 
	--perform job_limpieza_8h();
end; $$ language plpgsql;

