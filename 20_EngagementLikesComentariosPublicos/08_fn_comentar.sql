-- Publicar comentario (comunidad o normales) (texto o voz).
create or replace function public.fn_publicar_comentario(
    p_yo bigint,
    p_tutorial_id bigint,
    p_clase public.comentario_clase,
    p_texto text default null,
    p_audio_url text default null,
    p_audio_ms int default null,
    p_titulo varchar default null
)
returns bigint
language plpgsql
security definer
as $$
declare
    v_id bigint;
    v_codigo citext;
begin
    if p_clase = 'comunidad' then
        -- Codigo tipo youtube 8 chars base64url
        -- translate() -> Reemplaza caracteres dentro de la cadena
        -- Si aparece + -> se cambia por A , si aparece / -> se cambia por a.
        v_codigo := substr(
            translate(encode(gen_random_bytes(6), 'base64'), '+/', 'Aa'),
            1, 8
        )::citext;
    end if;

    insert into public.tutorial_comentarios(
        tutorial_id, autor_id, padre_id, clase, titulo, codigo,
        cuerpo_texto, audio_url, audio_duracion_ms
    ) values (
        p_tutorial_id, p_yo, null, p_clase,
              -- nullif(..., '') -> Si el resultado es una cadena vacia (''), lo convierte en null.
              case when p_clase = 'comunidad' then nullif(btrim(p_titulo), '') END,
              v_codigo,
              nullif(btrim(p_texto), ''),
              p_audio_url::public.url_http,
              p_audio_ms
    )
    -- returning -> Sirve para capturar valores generados por la base de datos.
    returning id into v_id;

    -- Parte de la funcion para devolver un resultado al que llamo la funcion.
    return v_id;
end;
$$;

-- PRUEBA 1. COMENTARIO NORMAL DE TEXTO. Patron Youtube: comentario raiz en el video.
select '--- PRUEBA 1: publicar comentario de texto ---' as test;

-- Antes. Comentarios de Sebastian en el tutorial 5.
-- 3 = Sebastian, tabla public.usuarios.
-- 5 = "Build Level in Unreal Engine", tabla public.tutoriales, creador Julio (usuarios.id 2).
select id, tutorial_id, autor_id, padre_id, clase, cuerpo_texto
from public.tutorial_comentarios
where autor_id = 3
  and tutorial_id = 5;
-- Esperado ahora: cero filas.

-- fn_publicar_comentario(p_yo, p_tutorial_id, p_clase, p_texto, P_audio_url, p_audio_ms, p_titulo)
-- 3 = Sebastian, usuarios.id
-- 5 = "Build Level in Unreal Engine", tutoriales.id.
-- 'normal' = comentario de Youtube , no comunidad.
-- El texto es el comentario. Audio, duracion y titulo van null
select public.fn_publicar_comentario(3,5, 'normal', 'El nivel carga bien.', null, null, null);
-- Esperado: un numero. Es el id nuevo del comentario.

-- PRUEBA 2. POST DE COMUNIDAD. PATRON FACEBOOK. GRUPO CON TITULO Y CODIGO.
select '--- PRUEBA 2: publicar comunidad ---' as test;

-- Antes. Comunidades de Angela en el tutorial 9.
-- 4 = Angela, usuarios.id.
-- 9 = "Edit Music & Audio Mixes", tutoriales.id. Creador: Angela.
select id, titulo, codigo, clase, miembros_count
from public.tutorial_comentarios
where autor_id = 4
  and tutorial_id = 9
  and clase = 'comunidad';
-- esperado ahora: cero filas.

-- 4 = Angela. 9= "Edit Music & Audio Mixes".
-- 'comunidad' obliga titulo. El codigo lo genera la funcion, no se lo pasas.
select public.fn_publicar_comentario (4,9,'comunidad', 'trae tus mixes.', null, null, 'Mesa de mezclas');
-- Esperado el id nuevo.

-- Despues. Post raiz, codigo de 8 caracteres y Angela ya es miembro.
select id, tutorial_id, autor_id, padre_id, clase, titulo, codigo, cuerpo_texto, miembros_count
from public.tutorial_comentarios
where autor_id = 4
  and tutorial_id = 9
  and clase = 'comunidad';
-- Esperado: una fila. titulo = "Mesa de mezclas". codigo con 8 caracteres.
-- padre_id null. miembros_count = 1. El trigger del archivo 03 metio a la autora.

-- PRUEBA 3. COMENTARIO DE VOZ
select '--- PRUEBA 3: publicar comentario de voz ---' as test;

-- Antes. Comentarios de Julio en el tutorial 6.
-- 2 = Julio, usuarios.id.
-- 6 = "Create new project in Unreal Engine 5", tutoriales.id. Creador: Julio.
select id, cuerpo_texto, audio_url, audio_duracion_ms
from public.tutorial_comentarios
where autor_id = 2
  and tutorial_id = 6;
-- Esperado ahora: cero filas.

-- 2 = Julio. 6 = "Create new project in Unreal Engine 5". 'normal'.
-- P_texto null. La url tiene que empezar con http:// o https://.
-- 1200 = duracion en milisegundos. El titulo va null.
select public.fn_publicar_comentario(
    2, 6, 'normal', null,
    'https://cdn.ejemplo.com/audio/julio-tutorial-6.mp3',
    1200, null
);
-- Esperado el id nuevo

select id, tutorial_id, autor_id, clase, cuerpo_texto, audio_url, audio_duracion_ms
from public.tutorial_comentarios
where autor_id = 2
  and tutorial_id = 6;
-- Esperado: una fila. cuerpo_texto null. audio_duracion_ms = 1200.
-- audio_url = https://cdn.ejemplo.com/audio/julio-tutorial-6.mp3


-- Esta funcion se puede simplificar.
create or replace function public.fn_responder_comentario(
    p_yo bigint,-- Usuario que esta respondiendo
    p_padre_id bigint, -- El id del comentario al que quieres responder.
    p_texto text default null, -- El texto de tu respuesta
    p_audio_url text default null,
    p_audio_ms int default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id bigint;            -- Id del nuevo comentario respuesta que vas a insertar.
    v_tutorial bigint;      -- El tutorial donde vive el comentario padre.
    v_raiz bigint;          -- El comentario raiz de toda la conversacion
    v_clase public.comentario_clase; -- La clase del comentario raiz (normal o comunidad)
begin
    -- c.tutorial_id -> Obtiene el tutorial al que pertenece el comentario. Se guarda en v_tutorial.
    select c.tutorial_id,
           -- Si padre_id es null , usa el propio id.
           coalesce(c.padre_id, c.id),
           -- Si padre_id es null toma su clase , toma la clase del comentario raiz
           case when c.padre_id is null then c.clase else p.clase end
    into v_tutorial, v_raiz , v_clase
    -- c -> comentario actual.
    from public.tutorial_comentarios as c
    -- p -> comentario raiz.
    left join public.tutorial_comentarios as p
        on p.id = coalesce(c.padre_id, c.id)
    where c.id = p_padre_id;

    if v_tutorial is null then
        raise exception 'comentario padre % no existe', p_padre_id;
    end if;

    -- Comunidad: para escribir hay que ser miembro. Leer es publico
    -- Si no existe una fila en la tabla comentario_miembros que cumpla:
    if v_clase = 'comunidad' and not exists( -- Revisa si tu eres miembro de la comunidad del comentario raiz.
        select 1 from public.comentario_miembros
        where comentario_id = v_raiz -- Comentario raiz de la comunidad
        and usuario_id = p_yo        -- El usuario que intenta responder
    ) then -- Si no existe significa que no eres miembro.
        raise exception 'unete a la comunidad % para responder', v_raiz;
    end if;

    insert into public.tutorial_comentarios(
        tutorial_id, autor_id, padre_id, clase,
        cuerpo_texto, audio_url, audio_duracion_ms
    ) values (
        v_tutorial, p_yo, p_padre_id, 'normal',
              nullif(btrim(p_texto), ''),
              p_audio_url::public.url_http,
              p_audio_ms
    )
    returning id into  v_id;

    return v_id;
end;
$$;

-- PRUEBA 4. Respuesta en un comentario normal. No pide ser miembro.
select '--- PRUEBA 4: responder comentario normal ---' as test;

-- Antes. Respuestas al comentario 1.
-- 1 = comentario raiz de Shiriaru, tabla public.tutorial_comentarios.
-- Texto actual de esa raiz: "Este es el comentario raiz del tutorial."
select id, autor_id, padre_id, cuerpo_texto , clase
from public.tutorial_comentarios
where padre_id = 1
order by id;
-- Esperado ahora: una fila, id 4, autor Sebastian, texto "Yo tambien, en el paso 2."

-- fn_responder_comentario(p_yo, p_padre_id, p_texto)
-- 3 = Sebastian, usuarios.id.
-- 1 = comentario raiz de Shiriaru, tutorial_comentarios.id.
select public.fn_responder_comentario(3,1, 'Lo anoto para el paso 3.');
-- Esperado: el id nuevo de la respuesta.

-- Linea 194.
-- Esperado: dos filas. La id 4 sigue. Aparece otra con autor_id 3 Sebastian,
-- tutorial_id 1, clase normal, cuerpo_texto "Lo anoto para el paso 3."

-- PRUEBA 5. Responder en una comunidad sin ser miembro. Facebook no deja comentar el grupo.
select '--- PRUEBA 5: responder sin ser miembro ---' as test;

-- Antes. Shiriaru no esta en UnrealHQ
-- 6 = comentario comunidad UnrealHQ, tutorial_comentarios.id. Autor: Julio.
select usuario_id
from public.comentario_miembros
where comentario_id = 6
order by usuario_id;
-- Esperado ahora: 2 Julio y 3 Sebastian. No esta el 1.

-- 1 = Shiriaru, usuarios.id. No es miembro de UnrealHQ.
-- 6 = UnrealHQ, tutorial_comentarios.id.
do $$
begin
    perform public.fn_responder_comentario(1,6, 'Quiero entrar.');
    raise exception 'FALLO: Shiriaru respondio sin ser miembro';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'Ok responder sin miembro: %', sqlerrm;
end;
$$;

-- Esperado en Messages: OK responder sin miembro: unete a la comunidad 6 para responder.

-- Linea 215
-- Esperado: sigue una sola fila, la id 8. No aparecio "Quiero entrar."

-- PRUEBA 6. Responder siendo miembro. Angela ya esta en WordDudas.
select '--- PRUEBA 6: responder siendo miembro ---' as test;

-- Antes. Miembros de WordDudas.
-- 7 = comentario comunidad WordDudas, tutorial_comentarios.id. Autor: Shiriaru. codigo WordDudas.
select usuario_id
from public.comentario_miembros
where comentario_id = 7
order by usuario_id;
-- Esperado ahora: 1 Shiriaru y 4 Angela.

select id, autor_id, cuerpo_texto , tutorial_id,  padre_id
from public.tutorial_comentarios
where padre_id = 7
order by id;
-- Esperado ahora: una fila, id 9, Angela, "Lo voy a probar en el paso 1."

-- 4 = Angela, usuarios.id. Si es miembro.
-- 7 = WordDudas, tutorial_comentarios.id
select public.fn_responder_comentario(4,7, 'Paso 1 listo.');
-- Esperado: el id nuevo.

-- Linea 252
-- Esperado: dos filas. La id 9 sigue.
-- La nueva tiene autor_id 4 Angela , tutorial_id 1, clase normal, texto "Paso 1 listo."