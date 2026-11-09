-- CREAR TABLA DE USUARIOS CON ESTANDARES MODERNOS. 
create table usuarios (
	id bigint generated always as identity primary key, 
	username varchar(50) unique not null, 
	email varchar(255) unique not null, 
	avatar_url TEXT, 
	pais VARCHAR(50), 
	plan VARCHAR(20) not null
		-- CHECK ASEGURA QUE SOLO SE GUARDEN VALORES VALIDOS 
		check (plan in ('free', 'pro', 'creator')) default 'free', 
	activo BOOLEAN default true, 
	-- TIMESTAMPTZ GUARDA FECHA Y HORA CON ZONA HORARIA 
	created_at timestamptz default now()
);

-- *************************************************************************************
--LLAVE FOREANEA ES UN CAMPO QUE HACE REFERENCIA A LA LLAVE PRIMARIA DE OTRA TABLA.  

-- CREAR TABLA DE TUTORIALES CON PUBLICACION PROGRAMADA CON BUENAS PRACTICAS 
create table tutoriales(
	id bigint generated always as identity primary key,
	-- RELACION FORANEA 
	creador_id bigint default 0 
		--REFERENCES CREA UNA LLAVE FORANEA 
		--ON DELETE CASCADE SI UN USUARIO DE LA TABLA USUARIOS SE ELIMINA AUTOMATICAMENTE SE ELIMINARAN TODOS LOS TUTORIALES
		references usuarios(id)
		-- SI SE BORRA EL USUARIO SE ASIGNA EL VALOR POR DEFECTO 0 APUNTANDO AL USUARIO system. 
		-- ON CUANDO OCURRA ESTE EVENTO 
		-- DELETE EL EVENTO ES CUANDO SE ELIMINA UN REGISTRO 
		-- SET DEFAULT LA ACCION QUE SE EJECUTA SOBRE LA COLUMNA QUE TIENE LA RELACION FORANEA. 
		on delete set default,
	titulo varchar(255) not null, 
	categoria varchar(50) not null 
		check (categoria in ('Word','Unreal Engine', 'PowerPoint', 'Excel', 'Photoshop')), 
	duracion_min int check (duracion_min > 0),
	likes_count int default 0, 
	ejecuciones int default 0, 
	-- INICIA COMO PRIVADO 
	es_publico boolean  default false,
	-- FECHA HORA PROGRAMADA DE SALIDA 
	fecha_publicacion timestamptz, 
	created_at timestamptz default now()
);

-- *************************************************************************************
-- TALBA SESION RAM - UNIDAD 10 - DATOS TEMPORALES 
-- drop table BORRAR TABLA sesiones_ram 
drop table if exists sesiones_ram;
create table if not exists sesiones_ram(
-- UNLOGGED TABLA EN RAM , SUPER RAPIDA Y TEMPORAL , SI TU PC O POSTGRES SE APAGA LO QUE LIMPIA SON LOS REGISTROS. 
--create unlogged table if not exists sesiones_ram(
	usuario_id bigint primary key references usuarios(id) on delete cascade, 
-- created_at FECHA Y HORA DE CUANDO INICIO SESION EN LA APP DE ESCRITORIO 
	created_at timestamptz default now(), -- FECHA Y HORA DE LA ULTIMA VEZ QUE LA IA LO VIO ACTIVO SIRVE PARA LAS 8 HORAS DE EXPIRACION
	last_seen_at timestamptz default now()
);

-- *************************************************************************************
-- HARDENING (FORTALECER LA SEGURIDAD Y CONSISTENCIA) DE LLAVES FORANES 

-- **** NOMBRE DE LAS CONSTRAINTS(NOMBRE LLAVE FORANEA O RELACION) ASOCIADAS A LA TABLA tutoriales. 
select constraint_name, table_name, column_name
from information_schema.key_column_usage
where table_name = 'tutoriales';

-- *** ELIMINACION DE LA RELACION FORANEA ACTUAL ENTRE tutoriales.creador_id y usuarios.id ***
-- ALTER TABLE INDICA QUE VAS A MODIFICAR LA ESTRUCTURA DE LA TABLA LLAMADA tutoriales. 
alter table tutoriales 
-- DROP CONSTRAINT ROMPER LA RELACION FORANEA ENTRE TUTORIALES Y USUARIOS PARA CREAR UNA RELACION MAS SEGURA Y CONFIABLE 
-- IF EXISTS SOLO INTENTA ELIMINAR LA RESTrICCION SI REALMENTE EXISTE. 
-- NOMBRE DE LA CONSTRAINT tutoriales_creador_id_fkey IDENTIFICADOR AUTOMATICO DE LA RELACION.
	drop constraint if exists tutoriales_creador_id_fkey;

-- **** ASEGURAR QUE LA COLUMNA creador_id NO TENGA VALORES POR DEFECTO INSEGUROS ****
alter table tutoriales 
-- ALTER COLUMN SEÑALA QUE EL CAMBIO SE APLICARA ESPECIFICAMENTE A LA COLUMNA  creador_id. 
-- DROP DEFAULT ELIMINA EL VALOR POR DEFECTO QUE TENIA ESA COLUMNA (creador_id bigint default 0)
	alter column creador_id drop default;

-- **** CONFIRMAR QUE EL TIPO DE DATO (BIGINT) DE creador_id  PARA ALINEARLO CON LA PK DE USUARIOS 
alter table tutoriales 
-- TYPE BIGINT REESCRIBE EL TIPO DE DATO DE ESA COLUMNA PARA QUE SEA BIGINT 
	alter column creador_id type BIGINT;

-- *** CREAR EL USUARIO DE SISTEMA QUE REPRESENTARA CONTENIDO HUERFANO. 
insert into usuarios (id, username, email, avatar_url, pais, plan , activo , created_at)
-- OVERRIDING SYSTEM VALUE PERMITE USAR UN ID MANUAL (0) EN LUGAR DE DEJAR QUE POSTGRESQL GENERE UNO AUTOMATICAMENTE. 
overriding system value
values (0, 'system', 'system@ai_assistant.internal', null, 'Guatemala', 'creator', false , now())
-- ON CONFLICT (id) INDICA QUE HACER SI OCURRE UN CONFLICTO AL INSERTAR 
-- DO NOTHING ACCION QUE SE EJECUTA SI OCURRE EL CONFLICTO. NO HAGAS NADA Y EVITA EL ERROR. 
on conflict (id) do nothing; 

-- *** SETEAR EL DEFAULT 0 DE FORMA SEGURA , AHORA QUE EL 0 EXISTE. 
alter table tutoriales
alter column creador_id set default 0; 

-- *** CREAR LA NUEVA LLAVE FORANEA 
alter table tutoriales 
-- NOMBRE DE MI LLAVE FORANEA EN LA TABLA tutoriales QUE HACE REFERENCIA A LA TABLA usuario. 
	add constraint fk_tutoriales_usuario 
	foreign key (creador_id) references usuarios(id)
-- CUADO OCURRA EL EVENTO DE ELIMINAR UN REGISTRO EN LA TABLA DE REFERENCIA
	on delete set default
-- CUANDO OURRA EL EVENTO UPDATE CUANDO CAMBIA EL VALOR DE ID EN LA TABLA DE REFERENCIA  ACTUALIZAR 
-- TODOS LOS TUTORIALES RELACIONADOS PARA REFLEJAR EL NUEVO ID. 
	on update cascade; 

-- *************************************************************************************
-- UPGRADE PARA APP SOCIAL REAL - IMAGEN 2 Y 3 
alter table usuarios 
-- ADD SIGNIFICA QUE VAS A AGREGAR UNA NUEVA COLUMNA 
-- UNIQUE ASEGURA QUE NO SE REPITAN VALORES EN ESTA COLUMNA  
-- handle ALIAS NOMBRE PUBLICO UNICO DE CADA USUARIO PARA MOSTRAR Y BUSCAR USUARIOS POR ALIAS 
add column if not exists handle varchar(30) unique, -- @Shiriaru
-- bio DESCRIPCION PERSONAL DEL USUARIO COMO QUIEN ES , QUE LE GUSTA O INFORMACION PUBLICA. 
add column if not exists bio TEXT, 
-- seguidores_count NUMERO DE PERSONAS QUE SIGUEN AL USUARIO 
add column if not exists seguidores_count int default 0 check (seguidores_count >=0 ),
-- following_count NUMERO DE PERSONAS QUE EL USUARIO SIGUE 
add column if not exists following_count int default 0 check (following_count >= 0),
-- verfied ESTADO DE VERIFICACION DEL USUARIO. 
add column if not exists verified boolean default false,
-- updated_at  FECHA/HORA DE ULTIMA ACTUALIZACION CUANDO SE MODIFICO POR ULTIMA VEZ LA INFORMACION DEL USUARIO. 
add column if not exists updated_at timestamptz default now();

-- ********* TABLA tutoriales UPGRADE***********
alter table tutoriales 
-- slgu URL AMIGABLE UNICA PARA COMPARTIR Y BUSCAR EL TUTORIAL 
add column if not exists slug varchar(300) unique, 
-- descripcion TEXTO CORTO QUE EXPLICA QUE HACE EL TUTORIAL Y QUE RESULTADO DA. 
add column if not exists descripcion text, 
-- app_objetivo NOMBRE DE LA APLICACION/CATEGORIA DONDE SE EJECUTA EL TUTORIAL (Word, Unreal Engine , etc.)
add column if not exists app_objetivo varchar(50) not null default 'word', 
-- thumbail_url ENLACE DE LA IMAGEN MINIATURA QUE SE MUESTRA EN LA TARJETA DEL TUTORIAL. 
add column if not exists thumbail_url text,
-- preview_video_url ENLACE DE UN VIDEO CORTO DE VISTA PREVIA QUE SE MUESTRA AL PASAR EL MOUSE.  
add column if not exists preview_video_url text,
-- estado BORRADOR , PROBANDO , PUBLICADO O ARCHIVADO CONTROLA SI SE MUESTRA. 
add column if not exists estado varchar(20) default 'draft' check(estado in ('draft', 'testing', 'published', 'archived')), 
-- es_cript TRUE SI EL TUTORIAL YA FUNCIONO Y SE GUARDO COMO SCRIPT PARA TAREAS REPETITIVAS 
add column if not exists es_cript boolean default false, 
-- es_based_dataset TRUE SI EL TUTORIAL PROVIENE DEL DATASET DE ENTRENAMIENTO DE LA IA 
add column if not exists es_based_dataset boolean default false, 
-- vesrion NUMERO DE VERSION DEL TUTORIAL AUMENTA CADA VEZ QUE ALGUIEN LO EDITA 
add column if not exists version int default 1, 
-- tutorial_padre_id REFERENCIA AL TUTORIAL ORIGINAL SI ESTE ES UNA COPIA EDITADA. EVITA DA;AR EL ORIGINAL  
add column if not exists tutorial_padre_id bigint references tutoriales(id) on delete set null, 
-- muestras_entrenamiento CANTIDAD DE VECES QUE ESTE TUTORIAL SE USO PARA ENTRENAR LA IA
add column if not exists muestras_entrenamiento int default 0,
-- updated_at FECHA Y HORA DE LA ULTIMA MODIFICACION DEL TUTORIAL 
add column if not exists updated_at timestamptz default now();


