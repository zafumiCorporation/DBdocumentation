-- Poner / quitar nodo (cirugia JSON, no Delete de fila)
create or replace function public.fn_lienzo_upsert (
    p_yo bigint, p_tutorial_id bigint
)
returns void
language plpgsql
set search_path = ''
as $$
declare
    v_dueno bigint;
begin
    -- Guarda en la variable quien es el creado del tutorial.
    select creador_id into v_dueno
    from public.tutoriales
    where id = p_tutorial_id;

    -- Compara el id del creador (v_dueno) con el id del usuario que intenta editar (p_yo).
    if v_dueno is distinct from p_yo then
        raise exception 'solo el creador edita el blueprint';
    end if;

    insert into public.lienzo_borrador_ram (tutorial_id, editor_id)
    values (p_tutorial_id, p_yo)
    on conflict (tutorial_id) do nothing;

    insert into public.tutorial_lienzo (tutorial_id, editor_id)
    select p_tutorial_id, p_yo
    -- Si no existe un lienzo con el id del tutorial y el editor.
    where not exists(
        select 1
        from public.tutorial_lienzo
        where tutorial_id = p_tutorial_id
    );
end;
$$;

-- PRUEBA 1
-- Crear el area de trabajo (borrador) de un tutorial.
-- Objetivo: Verificar que el creador del tutorial pueda abrir el blueprint. Para comenzar a disenar el flujo.
-- Estado Inicial: No existe registro en lienzo_borrador_ram. No existe registro en tutorial_lienzo.
-- Accion: Ejecutar fn_lienzo_upsert().
-- Resultado esperado: Se crea un borrador en memoria (RAM). nodos inician como []. rutas inicia como [].
-- Se crea el registro inicial en tutorial_lienzo. nodos_count = 0. rutas_count = 0.
select '--- PRUEBA 1: abrir lienzo ---' as test;

-- Antes. 1 = tutorial "Create Sheet in Word", tabla public.tutoriales. Creador: Shiriaru.
select tutorial_id, editor_id, nodos_count, rutas_count
from public.tutorial_lienzo
where tutorial_id = 1;
-- Esperado ahora: cero filas.

select tutorial_id, editor_id , nodos, rutas
from public.lienzo_borrador_ram
where tutorial_id = 1;
-- Esperado ahora: cero filas.

-- 1 = Shiriaru, tabla public.usuarios, columna id.
-- 1 = "Create Sheet in Word", tabla public.tutoriales, columna id.
select public.fn_lienzo_upsert(1,1);

--Linea 52
-- Esperado: una fila. editor_id, 1 Shiriaru. nodos = []. rutas = [].

select tutorial_id, editor_id, nodos_count, rutas_count
from public.tutorial_lienzo
where tutorial_id = 1;
-- Esperado: una fila. editor_id 1. nodos_count 0. rutas_count 0.

-- PRUEBA 2. Julio no es el creador. el blueprint no se abre para el.
-- Objetivo: Verificar que solamente el creador del tutorial pueda abrir y modificar el blueprint.
-- Estado Inicial: El tutorial pertenece a Shiriaru. Julio no es el creador
-- Accion: Julio intenta ejecutar fn_lienzo_upsert().
-- Resultados esperados: Solo el creador edita el blueprint , No se crea borrador RAM para Julio.
-- No se modifica el blueprint existente.
-- Nota: esta validacion protege la estructura del tutorial , Contra modificaciones realizadas por otros usuarios.
select '--- PRUEBA 2: otro usuario no edita ---' as test;

-- 2 = Julio, usuarios.id.
-- 1 - "Create Sheet in Word", tutoriales.id. El creador es Shiriaru, no Julio.
do $$
begin
    perform public.fn_lienzo_upsert(2,1);
    raise exception 'FALLO: Julio edito el blueprint de Shiriaru';
exception
    when others then
        if sqlerrm like 'FALLOl%' then
            raise;
        end if;
        raise notice 'OK solo el creador: %', sqlerrm;
end;
$$;
-- Esperado en Messages: Ok solo el creador: solo el creador edita el blueprint.

create or replace function public.fn_persistir_lienzo(p_yo bigint, p_tutorial_id bigint)
returns void
language plpgsql
set search_path = ''
as $$
begin
    insert into public.tutorial_lienzo (tutorial_id, editor_id, nodos, rutas)
    select tutorial_id, editor_id, nodos, rutas
    from public.lienzo_borrador_ram
    where tutorial_id = p_tutorial_id
    and editor_id = p_yo
    on conflict (tutorial_id) do update set
        nodos = excluded.nodos,
        rutas = excluded.rutas,
        updated_at = now();

    if not found then
        raise exception 'no hay borrador RAM para persistir';
    end if;
end;
$$;

-- PRUEBA 3 Guardar el contenido del borrador en el lienzo persistente.
-- Objetivo: Verificar que los datos almacenados temporalmente en RAM , Se copien al alamacenamiento permanente del tutorial.
-- Estado inicial: Existe un borrador RAM para el tutorial. nodos y rutas estan cargados en el borrador.
-- Accion: Ejecutar fn_persistir_lienzo().
-- Resultado esperado: nodos se copian a tutorial_lienzo.
-- rutas se copian a tutorial_lienzo. updated_at se actualiza.
-- El lienzo publicado refleja el estado actual del borrador.
-- Nota: Esta operacion equival a un "Guardar" o "Publicar" , los cambios realizados en el diseno del tutorial.
select '--- PRUEBA 3: persistir lienzo vacio ---' as test;

-- Antes. RAM  del tutorial 1, editor Shiriaru.
select tutorial_id, editor_id, nodos, rutas
from public.lienzo_borrador_ram
where tutorial_id = 1
  and editor_id = 1;
-- Esperado ahora: nodos [] y rutas [].

-- 1 = Shiriaru, usuarios.id.
-- 1 = "Create Sheet in Word", tutoriales.id.
select public.fn_persistir_lienzo(1,1);

select tutorial_id, editor_id, nodos_count, rutas_count, updated_at
from public.tutorial_lienzo
where tutorial_id = 1;
-- Esperado: nodos_count 0, rutas_count 0, updated_at de ahora
-- Los nodos de la prueba siguiente vive en RAM hasta que compile.

