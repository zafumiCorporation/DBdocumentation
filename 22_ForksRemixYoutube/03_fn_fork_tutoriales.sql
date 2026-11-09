-- Pattern: Youtube remix - FOR UPDATE lock + slug + chain depth 20
-- for update -> Bloquear temporalmente esa fila Ejemplo : Juan esta modificando Tutorial 10 y Pedro intenta hacer un fork exactamente al mismo tiempo. PostgreSQL hace que uno espere hasta que termine el otro.
-- Mientras copio el tutorial, nadie puede modificar esa misma fila al mismo tiempo.
-- chain depth 20 -> Profundidad maxima de forks = 20 , Ejemplo : Tutorial Original Fork 1 , Fork 2 , Fork 3
-- Para evitar cadenas infinitas Juan-> Pedro -> Maria -> Luis -> Carlos -> ...
-- Objetivo: Tomar un tutorial existente + Crear una copia idependiente + Asignarla a otro usuario.
create or replace function public.fn_fork_tutoriales(
    p_yo bigint, -- Id del usuario que quiere crear el fork (copia)
    p_original_id bigint -- Id del tutorial original que se quiere copiar.
)
returns bigint
language plpgsql
set search_path = ''
as $$
declare
    -- %ROWTYPE -> Esta variable puede guardar una fila completa de la tabla tutoriales.
    v_orig public.tutoriales%ROWTYPE;
    v_copia bigint; -- Id del nuevo tutorial copiado
    v_slug text; -- El nuevo slug generado para la copia.
    v_profundidad int; -- Guarda cuantos niveles de fork existen. Ejemplo: Original -> Fork -> Fork -> Fork  4 niveles
begin
    -- 1. for update = candado de fila hasta COMMIT
    -- Aqui si alguien edita titulo mientras forkeas, esperas.
    select * into v_orig -- Guarda toda la fila.
    from public.tutoriales
    where id = p_original_id -- Tutorial original.
    for update; -- Bloquea esa fila temporalmente.

    if not found then
        raise exception 'tutorial original no existe';
    end if;

    if v_orig.creador_id = p_yo then
        raise exception 'El dueno edita el original, no hace remix';
    end if;

    -- Empieza a funcionar cuando se inserta forks(copias)
    -- Anti-chain infinita: Julio -> Pedro -> Maria -> ... max 20
    -- with -> Crea una tabla temporal en memoria.
    -- recursive -> consultarse a si misma. Ejecuta una consulta , toma el resultado y vuelve
    -- a usar ese resultado para seguir buscando mas datos. Ejemplo: Padre <- Abuelo <- Bisabuelo <- Tatarabuelo
    with recursive sube as(
        -- Resultado id: 50 , tutorial_padre_id: 40 , nivel 1.
        -- 1 as nivel -> Empieza contando desde nivel 1.
        select id, tutorial_padre_id, 1 as nivel
        from public.tutoriales
        where id = p_original_id -- Supongamos tutorial 50
        union all -- Une la consulta inicial con la siguientes consultas recursivas.
        -- Supogamos que ya encontro: Tutorial 50 y Nivel 1.
        -- Ahora calcula 1 + 1 Resultado = Nivel 2.
        select t.id, t.tutorial_padre_id, s.nivel + 1
        from public.tutoriales as t
        -- Parte Importante :
        -- Id..........tutorial_padre_id(forks)..........Nivel............Vuelta
        -- 50..........40................................1................Primera
        -- 40..........30................................2................Segunda
        -- 30..........20................................3................Tercera
        -- 20..........null..............................4................
        join sube as s on t.id = s.tutorial_padre_id -- Busca quien tiene id = 40. 40 -> padre 30
        -- Luego quien tiene id = 30 ? , Encuentra 30 -> padre 20.
        -- Luego quien tiene id = 20 -> null
        where s.nivel < 20 --> no sigas subiendo despues del nivel 20.
    )
    select max(nivel) into v_profundidad from sube; -- Busca el nivel mas alto.
    -- Que contiene la tabla "sube".
    -- Id................tutorial_padre.................Nivel.
    -- 50................40.............................1
    -- 40................30.............................2
    -- 30................20.............................3
    -- 20................null...........................4

    if v_profundidad >= 20 then
        raise exception 'cadena de remix demasiado profunda';
    end if;

    -- 3. format() + left(240->280) + 6 hex = slug YouTube style.
    -- left(texto_generado , 280) Si el slug queda demasiado largo,
    -- Quedate unicamente con los primeros 280 caracteres.
    v_slug:= left(
      format( -- Sirve para construir un texto.
          -- %s -> Aqui voy a poner un texto.
          '%s-remix-%s',
          coalesce( -- Valor 1
              -- v_orig.slug , '' -> Si es null devuelve null , si tiene valor devuelve v_orig.slug
              nullif(v_orig.slug, ''),
              public.fn_normalizar_slug(v_orig.titulo::public.citext)
          ),
          -- Genera 3 bytes aleatorios y los convierte a hexadecimal.
          encode(public.gen_random_bytes(3), 'hex') -- Valor 2.
      ),
      280
    );
    -- Resultado word-basico-remix-a1b2c3.

    -- 4. Copia como draft, contadores en 0, version 1 , hijo del original.
    -- Crea una copia del tutorial.
    insert into public.tutoriales(
        creador_id, titulo, categoria, duracion_min, likes_count, ejecuciones, es_publico,
        fecha_publicacion, slug, descripcion, app_objetivo, thumbail_url, preview_video_url,
        estado, es_cript, es_based_dataset, version, tutorial_padre_id, muestras_entrenamiento
    ) values (
        p_yo, -- Dueno del fork.
        format('Remix: %s', v_orig.titulo), -- Word Basico. -> La copia sera Remix: Word Basico.
              v_orig.categoria, -- Copia la categorial del original.
              v_orig.duracion_min, -- Copia la duracion.
              -- La copia inicia sin likes, Sin ejecuciones , La copia nace privada.
              0, 0, false, null,
              v_slug,   -- Slug nuevo generado.
              v_orig.descripcion, -- Se copia la descripcion.
              v_orig.app_objetivo, -- Se copia.
              v_orig.thumbail_url,
              v_orig.preview_video_url,
              'draft', -- Significa: Borrador todavia no esta publicado.
              false, -- La copia no inicia como tutorial criptografico.
              false, -- No nace como dato de entranamiento
              1, -- Toda copia empieza desde: Version 1 , aunque el original tenga version 50.
              p_original_id, -- Aqui se guarda quien es el padre.
              0 -- Todavia no ha generado ejemplos para entrenar IA.
    )
    returning id into v_copia;

    -- 5. Copia tags - ON CONFLICT DO NOTHING si trigger de tags racea
    -- Copia todas las etiquetas.
    -- Si el tutorial original tiene etiquetas: la copia tambien debe tenerlas.
    -- Word , Office , Tablas .
    -- Crea tutorial 25 -> Tag Word , Tag Office , Tag Tablas.
    insert into public.tutorial_tags (tutorial_id, tag_id, created_by)
    -- Id del tutorial copia, Id de cada tag , Usuario que creo el fork(copia).
    select v_copia, tt.tag_id, p_yo
    from public.tutorial_tags as tt
    where tt.tutorial_id = p_original_id -- Busca todos los tags del tutorial original.
    -- Ejemplo: Tutorial 10 -> Tag Word , Tag Office , Tag Tablas.
    on conflict do nothing; -- Si por alguna razon el tag ya existe : No hagas nada , no lances error , Continua.

    -- 6. Copia lienzo JSON - nodos + rutas. No copies tutorial_pasos/scripts, se recompilan
    -- Copia todos los nodos y rutas.
    -- Que Copia el Blueprint completo nodos + rutas
    insert into public.tutorial_lienzo (tutorial_id, editor_id, nodos, rutas)
    -- Id del tutorial copia. Usuario que creo el fork.  l.nodos = nodos , l.rutas = rutas.
    select v_copia, p_yo, l.nodos, l.rutas
    from public.tutorial_lienzo as l
    where l.tutorial_id = p_original_id
    on conflict (tutorial_id) do nothing;

    -- 7. Registra evento fork - trigger trg_forks_count sube forks_count
    -- Guarda un registro diciendo: "este tutorial fue copiado".
    -- Aqui se crea el Registro oficial del fork(copia).
    insert into public.tutorial_forks(
        tutorial_original_id, tutorial_copia_id, usuario_fork_id
        -- Tutorial original, Tutorial copia , Usuario que hizo el fork(copia)
        -- Resultado: Tutorial 10 fue copiado como Tutorial 25 por Usuario 7.
    )values (p_original_id, v_copia, p_yo);

    -- 8. Notificacion + pg_notify realtime
    -- Crea una notificacion para el dueno original.
    insert into public.notificaciones(usuario_id, actor_id, tipo, payload)
    values (
        v_orig.creador_id, -- Dueno del tutorial original.
            p_yo, -- El que hizo la accion el fork(copia)
            'tutorial_fork', -- Tipo de notificacion.
            json_build_object('original_id', p_original_id, 'copia_id', v_copia) -- Informacion adicional.
    );


    -- Envia una alerta en tiempo real.
    perform pg_notify( -- Notificacion en tiempo real.
        -- Usuario crea fork -> PostgreSQL envia mensaje -> Backend lo recibe -> Frontend actualiza la pantalla.
        'canal_notif_' || v_orig.creador_id::text, -- canal_notif_15 Canal donde escuchara ese usuario.
        json_build_object('tipo', 'tutorial_fork', 'copia_id', v_copia)::text -- Que envia.
    );

    -- Devuelve el ID de la nueva copia.
    return v_copia; -- Retorna ID de la copia.
end;
$$;

-- PRUEBA 1. Crear un remix a partir de un tutorial original.
-- Objetivo: Verificar que un usuario pueda crear una copia , idependiente de un tutorial ajeno.
-- Resultado esperado: Se crea un nuevo tutorial para Julio.
-- El tutorial original permanece intacto. El original aumenta forks_count
-- Se copian tags y blueprint. , Se registra el fork.
-- Se envia una notificacion al autor original.
select '--- PRUEBA 1: remix del original ---' as test;

-- Verifica que puede crearse la copia , viene de: insert into public.tutoriales(). linea 97
-- Aqui nace , Remix: Create Sheet in Word.

-- Antes. Tutorial 1, tabla public.tutoriales.
-- 1 = "Create Sheet in Word". Creador: Shiriaru, usuarios.id 1.
select id, titulo, creador_id, forks_count, tutorial_padre_id
from public.tutoriales
where id = 1;
-- Esperado ahora: forks_count 0, tutorial_padre_id null.

select id
from public.tutorial_forks;
-- Esperado ahora: cero filas.

-- 2 = Julio, tabla public.usuarios, columna id. No es el dueno.
-- 1 = "Create Sheet in Word", tabla public.tutoriales, columna id.
select public.fn_fork_tutoriales(2,1);
-- Esperado: un numero. Es el id nuevo de la copia. El slug trae 6 hex al azar, no es fijo.
-- pg_notify no sale en un select.

-- Despues. El original sumo 1. Ese movimiento lo hace el trigger del archivo 02.
-- Linea 183
-- Esperado: forks_count = 1. El titulo del original no cambia.

-- Despues la copia.
select id, creador_id, titulo, estado, es_publico, likes_count, version,
       tutorial_padre_id, forks_count, slug
from public.tutoriales
where creador_id = 2
  and tutorial_padre_id = 1;
-- Esperado: una fila.
-- creador_id 2 = Julio.
-- titulo = "Remix: Create Sheet in Word".
-- estado draft. es_publico false. likes_count 0. version 1. forks_count 0.
-- tutorial_padre_id = "Create Sheet in Word".
-- slug empieza con create-sheet-inword-remix- y cierra con 6 hex.

-- Despues. El registro del fork.
select f.tutorial_original_id, f.tutorial_copia_id, f.usuario_fork_id
from public.tutorial_forks as f
where f.usuario_fork_id = 2;
-- Esperado: original 1, copia = el id nuevo, usuario 2 Julio.

-- Despues. El tag Begginner viaja con la copia. created_by pasa a ser Julio.
select tt.tag_id, t.nombre, tt.created_by
from public.tutorial_tags as tt
join public.tags as t on t.id = tt.tag_id
where tt.tutorial_id = (
    select id from public.tutoriales
    where creador_id = 2 and tutorial_padre_id = 1
);
-- Esperado: una fila. tag_id 9, nombre Beginner, created_by 2.

-- Despues. El blueprint tambien viaja. El editor de la copia es Julio.
select editor_id, nodos_count, rutas_count
from public.tutorial_lienzo
where tutorial_id = (
    select id from public.tutoriales
    where creador_id = 2 and tutorial_padre_id = 1
);
-- Esperado: editor_id 2, nodos_count 2, rutas_count 1.

-- Despues. Shiriaru recibe el aviso. Julio es el actor.
select usuario_id , actor_id, tipo ,
       payload->>'original_id' as original_id,
       payload->>'copia_id' as copia_id
from public.notificaciones
where tipo = 'tutorial_fork'
order by id;
-- Esperado: una fila. usuario_id 1 Shiriaru. actor_id 2 Julio. original_id 1.

-- PRUEBA 2. El dueno no se hace remix de su propio tutorial.
-- Impedir forks del propio creadro.
-- Objetivo: Verificar que el dueno del tutorial, no pueda crear una copia de si mismo
-- Resultado esperado: Se genera una excepcion , No nace ninguna copia, forks_count no cambia.
select '--- PRUEBA 2: el dueno no forkea ---' as test;

-- proviene de linea 33.

select forks_count
from public.tutoriales
where id = 1;
-- Esperado ahora: 1.

-- 1 = Shiriaru, usuarios.id. Es el creador del tutorial 1.
-- 1 = "Create Sheet in Word", tutoriales.id.
do $$
begin
    perform public.fn_fork_tutoriales(1,1);
    raise exception 'FALLO: Shiriaru forkeo su propio tutorial';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'Ok el dueno no remiza: %', sqlerrm ;
end;
$$;
-- Esperado en Message: Ok el dueno no remizaL el dueno edita el original, no hace remix.

-- Linea 252
-- Esperado: sigue en 1.

-- PRUEBA 3. Sebastian remixa el remix de Julio. La cadena baja un nivel mas.
-- Crear un fork a partir de otro fork.
-- Objetivo: Verificar que una copia tambien pueda convertirse en origen de nuevas copias.
-- Resultado esperado: Sebastian obtiene una copia propia.
-- El padre de la copia es Julio.
-- El original de Shiriaru no suma forks.
-- El remix de Julio aumenta forks_count
select '--- PRUEBA 3: remix de un remix ---' as test;

-- Antes. La copia de Julio todavia no tiene forks.
select id, titulo, forks_count
from public.tutoriales
where creador_id = 2
  and tutorial_padre_id = 1;
-- Esperado ahora: titulo "Remix:" Create Sheet in Word", forks_count 0.

-- 3 = Sebastian, usuarios.id. No es el dueno de la copia de Julio.
-- El subquery es el id de esa copia, tutoriales.id.
select public.fn_fork_tutoriales(
    3,
    (select id
        from public.tutoriales
        where creador_id = 2
        and tutorial_padre_id = 1)
);
-- Esperado: el id nuevo de la copia de Sebastian.

-- Despues. El original de Shiriaru no suma otra vez. El que suma es el remix de Julio.
select id, titulo, forks_count
from public.tutoriales
where id = 1
    or (creador_id = 2 and tutorial_padre_id = 1)
order by id;
-- Esperado: tutorial 1 sigue en forks_count 1.
-- El remix de Julio pasa a forks_count 1.

select id, creador_id, titulo, estado, likes_count, version, tutorial_padre_id, slug
from public.tutoriales
where creador_id = 3
  and titulo like 'Remix:  Remix%';
-- Esperado: una fila.
-- creador_id 3 = Sebastian.
-- titulo = "Remix: Remix: Create Sheet in Word".
-- estado draft. likes_count 0. version 1.
-- tutorial_padre_id = el id del remix de Julio, no el 1.
-- slug empieza con el slug de Julio y le agrega otro -remix- mas 6 hex.

select usuario_id, actor_id, tipo, payload->>'original_id' as original_id
from public.notificaciones
where tipo = 'tutorial_fork'
  and actor_id = 3;
-- esperado: una fila. usuario_id 1 Julio. actor_id 3 Sebastian.
-- original_id = el id del remix de Julio.