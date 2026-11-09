create or replace function public.fn_abrir_mencion_tutorial(p_yo bigint, p_mencion_id bigint)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare v_tutorial bigint;
begin
    -- Marca leida solo si no ha expirado y no ha sido leida
    update public.tutorial_menciones
    set leida_at = now()
    where id = p_mencion_id
        and destinatario_id = p_yo
        and leida_at is null
        and expira_at > now()
    returning tutorial_id into v_tutorial;

    if v_tutorial is null then
        raise exception 'mencion % caducada o ya leida', p_mencion_id;
    end if;

    -- Delete despues de marcar: la fila era el ticket, ya no sirve.
    delete from public.tutorial_menciones where id = p_mencion_id;

    return v_tutorial;
end;
$$;

-- PRUEBA 1. Abrir la mencion. El ticket se consume: La fila se borra y la bandeja la pierde.
select '--- PRUEBA 1: abrir mencion de video ---' as test;

-- Antes. Mencion  que Shiriaru le dejo a Angela en el archivo 10.
-- 4 = Angela, usuarios.id. 5 = "Build Level in Unreal Engine", tutoriales.id. 1 = Shiriaru, el actor.
select id, tutorial_id, actor_id, destinatario_id, leida_at, expira_at > now() as vigente
from public.tutorial_menciones
where destinatario_id = 4
  and tutorial_id = 5
  and actor_id = 1;
-- Esperado ahora: una fila. leida_at null. vigente true.

select origen, tutorial_id, actor_id
from public.fn_bandeja_menciones(4);
-- Esperadoa ahora: una fila origen video. tutorial_id 5. actor_id 1 Shiriaru.
-- UnrealHQ ya no esta si el archivo 14 ya acepto esa invitacion.

-- fn_abrir_mencion_tutorial(p_yo, p_mencion_id)
-- 4 = Angela, usuarios.id. Solo ella puede abrir su ticket.
-- El subquery es el id de esa mencion.
select public.fn_abrir_mencion_tutorial(
    4,
    (select m.id
     from public.tutorial_menciones as m
     where m.destinatario_id = 4
       and m.tutorial_id = 5
       and m.actor_id = 1
     order by m.id desc
     limit 1)
);
-- Esperado: 5. Es el tutorial_id, "Build Level in Unreal Engine"

-- Despues. El ticket ya no existe. Linea 34
-- Esperado: cero filas.

-- Linea 41
-- Esperado: cero filas.

-- La notificacion no la borra esta funcion. Sigue en la tabla
select id, usuario_id, actor_id, tipo, payload ->> 'tutorial_id' as tutorial_id
from public.notificaciones
where usuario_id = 4
  and tipo = 'mencion_tutorial';
-- Esperado: La fila sigue. usuario_id 4 Angela. actor_id 1 Shiriaru. tutorial_id 5.
