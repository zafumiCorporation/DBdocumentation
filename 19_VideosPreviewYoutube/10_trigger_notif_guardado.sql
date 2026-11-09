alter type public.notificacion_tipo add value if not exists 'tutorial_guardado';

create or replace function public.fn_notif_guardado()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- Caso 1: Guardado nuevo
    if tg_op = 'INSERT' then
        insert into public.notificaciones(usuario_id, actor_id, tipo, payload)
        select t.creador_id , new.usuario_id, 'tutorial_guardado'::public.notificacion_tipo,
               jsonb_build_object('tutorial_id', new.tutorial_id, 'titulo', t.titulo)
        from public.tutoriales as t
        where t.id = new.tutorial_id
          and t.creador_id <> new.usuario_id; -- No notificarte a ti mismo

     -- Caso 2 - Estaba eliminado y ahora Guardado de nuevo
    elsif tg_op = 'UPDATE' then
        -- Si old.eliminado_at no es null y new.eliminado_at es null
        if old.eliminado_at is not null and new.eliminado_at is null then
            insert into public.notificaciones(usuario_id, actor_id, tipo, payload)
            select t.creador_id, new.usuario_id, 'tutorial_guardado'::public.notificacion_tipo,
                   jsonb_build_object('tutorial_id', new.tutorial_id, 'titulo', t.titulo)
            from public.tutoriales as t
            where t.id = new.tutorial_id
              and t.creador_id <> new.usuario_id;
        end if;
    end if;

    return null;
end;
$$;

drop trigger if  exists trg_guardados_notif on public.tutorial_guardados;
create trigger trg_guardados_notif
after insert or update of eliminado_at on public.tutorial_guardados
for each row execute function public.fn_notif_guardado();

-- PRUEBA 1. Alguien guarda un tutorial de otra persona. El creador recibe el aviso.
-- Patron Youtube/Facebook: "Julio guarda tu video"
select '--- PRUEBA 1: notificar al creador ---' as test;

-- Antes. Contador de Julio
-- 2 = Julio, tabla public.usuarios
select id, username, guardados_count
from public.usuarios
where id = 2;
-- Esperado ahora: guardados_count = 0.

-- Antes. Guardados de Julio
select usuario_id, tutorial_id, estado, eliminado_at
from public.tutorial_guardados
where usuario_id = 2
order by tutorial_id;
-- esperado ahora: solo tutorial_id 1 "Create Sheet in Word", activo.

-- fn_guardar_tutorial(p_yo, p_tutorial_id)
-- 2 = Julio, tabla public.usuarios. El es el actor.
-- 3 = "Guardar Hoja en Blanco", tabla public.tutoriales. Creador: 1 Shiriaru
select public.fn_guardar_tutorial(2,3);

-- Despues. Julio sumo un guardado. line 47
-- Esperado: guardados_count = 1

-- Despues. Aparece el tutorial 3 activo , linea 53
-- Esperado: tutorial 1 y tutorial 3, los dos activos.

-- Despues. Shiriaru recibe el aviso. Julio no se avisa a si mismo
select id, usuario_id, actor_id, tipo, payload, created_at
from public.notificaciones
where tipo = 'tutorial_guardado'
order by id;
-- Esperado: una fila.
-- usuario_id 1 = Shiriaru, el creador que recibe el aviso, tabla public.usuarios.
-- actor_id 2 = Julio, quien guardo el tutorial, tabla public.usuarios.
-- payload.tutorial_id = 3, payload.titulo = "Guardar Hoja en Blanco"

-- PRUEBA 2. Guardar un tutorial propio no crea aviso.
select '--- PRUEBA 2: no notificarme a mi mismo ---' as test;
-- Antes. Sebastian
-- 3 = Sebastian, tabla public.usuarios
select id, username, guardados_count
from public.usuarios
where id = 3;
-- Esperado ahora: guardados_count = 0.

-- Antes. Avisos cuyo actor es Sebastian.
select id, usuario_id, actor_id, tipo, payload
from public.notificaciones
where tipo = 'tutorial_guardado'
  and actor_id = 3;
-- Esperado ahora: cero filas.

-- 3 = Sebastian, tabla public.usuarios
-- 8 = "Filtrar lineas correctas", tabla public.tutoriales. Creador: Sebastian (usuarios.id 3)
select public.fn_guardar_tutorial(3,8);

-- Despues el guardado si se creo y el contado si sumo. linea 84
-- Esperado: una fila, estado activo, eliminado_at null.

select usuario_id, tutorial_id, estado, eliminado_at
from public.tutorial_guardados
where usuario_id = 3
  and tutorial_id = 8;

-- Despues. Sigue sin aviso. Creador y actor son la misma persona.
select id, usuario_id, actor_id, tipo, payload
from public.notificaciones
where tipo = 'tutorial_guardado'
  and actor_id = 3;
-- Esperado: cero filas.

-- PRUEBA 3. Quitar no avisa. Volver a guardar si avisa otra vez.
select '--- PRUEBA 3: reactivar tambien notifica ---' as test;

-- Antes Cuantos avisos tutorial_guardado existen. Linea 71
-- Esperado ahora: una fila, la de la prueba 1.
-- usuario_id 1 Shiriaru, actor_id 2 Julio , tutorial 3

-- Antes. Julio todavia tiene el tutorial 3 activo y su contador en 1. linea 47

select usuario_id, tutorial_id, estado, eliminado_at
from public.tutorial_guardados
where usuario_id = 2
  and tutorial_id = 3;
-- Esperado ahora: estado activo, eliminado_at null.

-- Quitar. 2 = Julio, tabla public.usuarios.
-- 3 = "Guardar Hoja en Blanco", tabla public.tutoriales.
select public.fn_quitar_guardado(2,3);

-- Despues de quitar. el contador baja y la fila queda oculta
select id, username, guardados_count
from public.usuarios
where id = 2;
-- Esperado: guardados_count = 0.

select usuario_id, tutorial_id, estado, eliminado_at
from public.tutorial_guardados
where usuario_id = 2
  and tutorial_id = 3;
-- Esperado: estado eliminado, eliminado_at con fecha

-- Quitar no escribe otro aviso. Sigue habiendo una sola notificacion.
select id, usuario_id, actor_id, payload
from public.notificaciones
where tipo = 'tutorial_guardado'
order by id;
-- Esperado: la misma fila de la prueba 1. No aparece una segunda.

-- Guardar de nuevo. Mismos ids: Julio (usuarios.id 2) y tutorial 3 (tutoriales.id 3).
select public.fn_guardar_tutorial(2,3);

-- Despues de reactivar. Contador otra vez en 1 y fila activa.
select id, username, guardados_count
from public.usuarios
where id = 2;
-- Esperado: guardados_count = 1.

select usuario_id, tutorial_id, estado, eliminado_at, guardado_at
from public.tutorial_guardados
where usuario_id = 2
  and tutorial_id = 3;
-- Esperado: estado activo, eliminado_at null, guardado_at mas reciente.

-- Despues. Shiriaru tiene un segundo aviso del mismo tutorial.
select id, usuario_id, actor_id, tipo , payload, created_at
from public.notificaciones
where tipo = 'tutorial_guardado'
order by id;




