/* @glosa
   lemma: create
   concept: Indica que vas a crear algo nuevo en la base de datos
*/

/* @glosa
   lemma: extension
   concept: Módulo extra que añade funciones avanzadas en PostgreSQL
*/
create extension if not exists citext with schema public;

/* @glosa
   lemma: pgcrypto
   concept: Funciones criptográficas para seguridad de datos: almacenar contraseñas encriptadas, verificar integridad, cifrar información sensible
*/
create extension if not exists pgcrypto; 
/* pg_trgm BUSQUEDA DE TEXTO APROXIMADO , DIVIDE CADENAS EN SECUENCIAS DE 3 CARACTERES Y MIDE 
 * SIMILITUD , similarity(text1 , text2) devuelve puntaje de similitud, % busqueda tolerante
 * a errores tipograficos , GIN/GIST OPTIMIZADOS PARA BUSQUEDAS RAPIDAS */
create extension if not exists pg_trgm with schema public;

-- PASO 0 EXTENSION PARA ACENTOS - SI BUSCAS "video" ECUENTRA "vídeo"
create extension if not exists unaccent;

-- CREAR UNA VERSION IMMUTABLE DE unaccent() , EVOLVERLA EN UNA FUNCION MARCADA COMO IMMUTABLE , PERMITIENDO USARLA EN INDICES 
    -- public HACE LA FUNSION VISIBLE DESDE CUALQUIER PARTE DE TU BASE DE DATOS.
 create or replace function public.immutable_unaccent(text)
-- returns text  LO QUE VA A DEVOLVER, SIEMPRE TEXTO SIN ACENTOS. 
returns text 
language sql
-- immutable OBLIGATORIO PARA QUE LA FUNCION PUEDA USARSE EN UN IDEX 
-- SI ME MANDAS SIEMPRE EL MISMO TEXTO TE DEVUELVO SIEMPRE LO MISMO 
immutable 
-- parallel safe LA FUNCION SE PUEDE USAR EN PARALELO 
-- PostgreSQL PUEDE USAR VARIOS PROCESOS PARA ACELERAR LA BUSQUEDAD 
parallel safe 
-- INDICA QUE SI EL PARAMETRO ES NULL , DEVUELVE NULL AUTOMATICAMENTE 
strict 
as $$
-- $1 PRIMER PARAMETRO QUE LE MANDAS 
-- ::text CONVIERTE ESE $1 a tipo texto. 
	select public.unaccent($1::text)
$$;

-- CONSULTAR EXTENSIONES INSTALADAS 
select * from pg_extension;



