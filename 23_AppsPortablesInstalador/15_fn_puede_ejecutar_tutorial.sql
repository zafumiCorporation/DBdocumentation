-- Play del blueprint (21) vs "no tienes VMware"
-- Decide, Puede ejecutar el tutorial ? Si o No.
-- Ej: Tutorial 21 -> Necesita VMware , Cuando el usuario pulse: play
-- La funcion decide: Lo dejo ejecutar ?  o Le digo primero instala VMware ?
-- Que hace fn_puede_ejecutar_tutorial? Verifica si el usuario puede ejecutar el tutorial.
-- Ejemplo: Tutorial VMware -> Necesita VMware -> La tiene instalada
-- Tutorial Word -> Word no existe en el catalogo -> permitir play.

-- Objetivo : Cuando usuario pulse play la funcion anlaiza:
-- Tutorial -> Que aplciacion necesita -> Esta instalada? -> Entonces decide: puede ejecutar , No puede ejecutar
create or replace function public.fn_puede_ejecutar_tutorial(
    p_yo bigint, -- Id del usuario que quier ejecutar el tutorial. Ej: 7
    p_tutorial_id bigint -- Id del tutorial que quiere ejecutar.
)
-- Devuelve una fila con informacion.
-- ok -> Indica true = si puede ejecutar , false = no puede ejecutar.
-- aplicacion_id -> aplicacion requerida por el tutorial.
-- slug -> Identificador unico. Ejemplo: vmware-workstation-player
-- motivo -> Explica la decision Ej: 1. tutorial no existe ,2. instalada o detectada , 3. instala primero.
returns table (ok boolean, aplicacion_id bigint, slug varchar, motivo text)
language sql
stable
parallel safe
set search_path = ''
as $$
    -- Tabla temporal guara id , app_objetivo , ej: id = 21 , app_objetivo = vmware-workstation-player
    with t as (
        select id, app_objetivo
        from public.tutoriales
        where id = p_tutorial_id
    ),
    -- Tabla temporal Busca la aplicacion en aplicaciones_catalogo, Obtiene: id , slug
    app as (
        select c.id, c.slug
        from public.aplicaciones_catalogo as c
        join t on c.slug = t.app_objetivo and c.activa
    )
    select
        case -- Este case llena ok
            when (select id from t) is null then false -- No existe el tutorial. Resultado:false
            when not exists(select 1 from app) then true -- No encontre ninguan aplicacion en el catalogo  ej: Word , no esta en aplicaciones_catalogo , Resultado: true por que no puede obligar al usuario a instalar algo que la tienda no administra
            when exists(-- La aplicacion requerida ya esta instalada.
                -- Aplicacion instalada del usuario actual.
                select 1
                from public.aplicaciones_usuario as au
                -- Une aplicacion requerida con aplicacion instalada
                join app on app.id = au.aplicacion_id
                where au.usuario_id = p_yo and au.estado = 'instalada'
            ) then true -- Si existe true
            else false -- La aplicacion existe en el catalogo pero no esta instalada.
        end,
        (select id from app), -- Id de la aplicacion requerida
        (select slug from app), --
        case -- LLena motivo.
            when (select id from t) is null then 'tutorial no existe'
            when not exists(select 1 from app) then 'app no esta en el store; Play sigue'
            when exists(
                select 1
                from public.aplicaciones_usuario as au
                join app on app.id = au.aplicacion_id
                where au.usuario_id = p_yo and au.estado = 'instalada'
            ) then 'instalada o detectada'
            else 'instala primero; llama fn_recomendar_instalacion'
        end;
$$;

-- Escenario 1 Word no esta en la tienda. Play sigue
select '--- PRUEBA 1: gate de Play ---' as test;

-- 1 = Shiriaru, usuarios.id.
-- 1 = "Create Sheet in Word", tutoriales.id. app_objetivo = word. No hay slug word en el catalogo
select ok, aplicacion_id, slug, motivo
from public.fn_puede_ejecutar_tutorial(1,1);
-- El tutorial apunta a word, pero en aplicaciones_catalogo No existe
-- La funcion entra a when not exists(select 1 from app) then true
-- Aqui tambien when not exists(select 1 from app) then 'app no esta en el store; Play sigue'
-- La funcion esta diciendo No puedo obligarte a instalar Word , Entonces Permite Play.

-- Esperado: ok true , aplicacion_id null, slug null.
-- motivo = app no esta en el store; Play sigue.

-- Escenario 2 Tutorial inexistente.
select ok, aplicacion_id, slug, motivo
from public.fn_puede_ejecutar_tutorial(1, 99999);
-- El tutorial 99999 no existe
-- La funcion entra aqui : when (select id from t) is null

-- Esperado:: ok false, aplicacion_id null, slug null.
-- motivo = tutorial no existe.

-- Escenario 3 Notepad si esta en la tienda
-- Aqui modificas temporalmente : app_objetivo = 'notepadpp-portable'
-- Ahora si existe una aplicacion en: aplicaciones_catalogo , La aplicacion es: notepadpp-portable
-- La funcion pregunta: El usuario la tiene instalada.

update public.tutoriales
set app_objetivo = 'notepadpp-portable'
where id = 8;

-- 1 = Shiriaru. ya confirmo Notepad.
select ok, slug, motivo
from public.fn_puede_ejecutar_tutorial(2, 8);
-- Esperado: ok false, slug notepadpp-portable, motivo = instalada o detectada.

-- Caso Julio No tiene Notepad registrada
select  ok, slug, motivo
from public.fn_puede_ejecutar_tutorial(2,8);
-- Esperado: ok false, slug notepadpp-portable.
-- motivo = instalada primero; Llama fn_recomendar_instalacion

update public.tutoriales
set app_objetivo = 'word'
where id = 8;

select id, app_objetivo
from public.tutoriales
where id = 8;


