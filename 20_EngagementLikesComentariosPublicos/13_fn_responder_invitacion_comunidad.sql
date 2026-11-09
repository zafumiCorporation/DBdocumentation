-- Responder la invitacion Aceptar o Rechazar
create or replace function public.fn_responder_invitacion_comunidad(
    p_yo bigint , p_invitacion_id bigint, p_aceptar boolean
)
returns boolean
language plpgsql
security definer
as  $$
declare
    v_comentario bigint;
    v_codigo citext;
begin
    update public.comunidad_invitaciones
    set estado = case when p_aceptar then 'accepted'::public.invitacion_estado
                      else 'declined'::public.invitacion_estado end,
        respondida_at = now() -- Marca la hora en que respondiste
    where id = p_invitacion_id -- Invitacion especifica con ese id.
      and destinatario_id = p_yo -- Solo el desinario correcto pueda responder.
      and estado = 'pending'
      and expira_at >  now()
    returning comentario_id into v_comentario;

    if v_comentario is null then
        raise exception 'invitacion % caducada o ya respondida', p_invitacion_id;
    end if;

    if p_aceptar then
        insert into public.comentario_miembros (comentario_id, usuario_id)
        values (v_comentario, p_yo) on conflict do nothing;
    end if;

    -- Borra notif por codigo para que job 8h no la reviva
    select codigo into v_codigo
    from public.tutorial_comentarios
    where id = v_comentario;

    delete from public.notificaciones
    where usuario_id = p_yo
      and tipo = 'invitacion_comunidad'
      and payload ->>'codigo' = v_codigo::text;

    return p_aceptar;
end;
$$;

-- PRUEBA 1. Aceptar. Sebastian entra a WordDudas y el aviso se borra.
select '--- PRUEBA 1: aceptar invitacion ---' as test;

-- Antes. Invitacion 2, revivida en el archivo 12.
-- destinatario 3 = Sebastian, usuarios.id. comentario 7 = WordDudas.
select id, estado, respondida_at, expira_at > now() as vigente
from public.comunidad_invitaciones
where id = 2;
-- Esperado ahora: pending, respondida_at null, vigente true.

-- Antes. Miembros de WordDudas. meimbros_count = 2
select usuario_id
from public.comentario_miembros
where comentario_id = 7
order by usuario_id;
-- Esperado ahora: 1 Shiriaru y 4 Angela. Sebastian no esta.

select miembros_count
from public.tutorial_comentarios
where id = 7;
-- Esperado ahora: 2.

select id, payload->>'codigo' as codigo
from public.notificaciones
where usuario_id = 3
  and tipo = 'invitacion_comunidad';
-- Esperado ahora: una fila, codigo WordDudas

-- fn_responder_invitacion_comunidad(p_yo, p_invitacion_id, p_aceptar)
-- 3 = Sebastian, usuarios.id. Solo el destinatario puede responder.
-- 2 = invitacion de WordDudas, comunidad_invitaciones.id
-- true = aceptar.
select public.fn_responder_invitacion_comunidad(3,2,true);
-- Esperado: true.

select id, estado, respondida_at
from public.comunidad_invitaciones
where id = 2;
-- Esperado: estado accepted. respondida_at con fecha.

-- Linea 57
-- Esperado: 1 Shiriaru, 3 Sebastian, 4 Angela.

-- La bandeja de Sebastian ya no trae WordDudas.
select origen, codigo
from public.fn_bandeja_menciones(3);
-- Esperado: cero filas.

-- PRUEBA 2. Rechazar. Shiriaru no entra a UnrealHQ
select '--- PRUEBA 2: rechazar invitacion ---' as test;

-- Antes. La invitacion nueva de Shiriaru a UnrealHQ
-- 1 = Shiriaru, usuarios.id. 6 = UnrealHQ.
select id, estado, respondida_at
from public.comunidad_invitaciones
where comentario_id = 6
  and destinatario_id = 1
  and estado = 'pending';
-- Esperado ahora: una fila pending. Anota ese id. Si el 12 no inserto mas, es el 4.

select miembros_count
from public.tutorial_comentarios
where id = 6;
-- Esperado ahora: 2. Miembros: Julio y Sebastian.

select usuario_id
from public.comentario_miembros
where comentario_id = 6
  and usuario_id = 1;
-- Esperado ahora: cero filas.

-- 1 = Shiriaru, usuarios.id.
-- El subquery toma la invitacion pending de Shiriaru a UnrealHQ.
-- false = rechazar.
select public.fn_responder_invitacion_comunidad(
    1,
    (select i.id
     from public.comunidad_invitaciones as i
     where i.comentario_id = 6
       and i.destinatario_id = 1
       and i.estado = 'pending'),
    false
);
-- Esperado: false.

select id, estado, respondida_at
from public.comunidad_invitaciones
where comentario_id = 6
  and destinatario_id = 1;
-- Esperado: estado declined. respondida_at con fecha.

-- Linea 106
-- Esperado: sigue en 2.

select id
from public.notificaciones
where usuario_id = 1
  and tipo = 'invitacion_comunidad';
-- Esperado: cero filas.
