-- Invitar a la comunidad
create or replace function public.fn_mencionar_comunidad(
    p_yo bigint, p_comentario_id bigint, p_destinatario bigint
)
returns bigint
language plpgsql
security definer
as $$
declare
    v_id bigint;
    v_titulo varchar;
    v_codigo citext;
begin
    -- Buscas en la tabla tutorial_comentarios el titulo y el codigo del comentario raiz de tipo comunidad.
    select titulo, codigo into v_titulo, v_codigo
    from public.tutorial_comentarios
    where id = p_comentario_id
    and clase = 'comunidad';

    if v_codigo is null then raise exception 'solo se menciona un comentario comunidad'; end if;

    -- Si ya invitaste, revive la invitacion a pending + 8h (no duplica fila por UNIQUE)
    -- actor_id -> El que envia la invitacion
    insert into public.comunidad_invitaciones (comentario_id, actor_id, destinatario_id)
    values (p_comentario_id, p_yo, p_destinatario)
    on conflict (comentario_id, destinatario_id) do update
    set estado = 'pending', created_at = now(),
        expira_at = now() + make_interval(hours => 8),
        respondida_at = null, actor_id = excluded.actor_id -- Usa el actor que viene del nuevo intento de insercion.
    returning id into v_id;

    insert into public.notificaciones (usuario_id, actor_id, tipo, payload)
    values (p_destinatario, p_yo, 'invitacion_comunidad',
            jsonb_build_object('invitacion_id',v_id, 'comentario_id',p_comentario_id, 'titulo', v_titulo, 'codigo', v_codigo));

    perform pg_notify('canal_notif_'||p_destinatario::text,
            jsonb_build_object('tipo', 'invitacion_comunidad', 'titulo', v_titulo, 'codigo', v_codigo)::text);

    return v_id;
end;
$$;

-- PRUEBA 1. Revivir una invitacion caducada. No crea otra fila: la misma vuelve a pending y a 8 horas.
select '--- PRUEBA 1: revivir invitacion ---' as test;

-- Antes. Invitacion 1.
-- comentario_id 6 = UnrealHQ, tutorial_comentarios.id.
-- actor 2 = Julio, usuarios.id. destinatario 4 = Angela, usuarios.id.
select id, comentario_id, actor_id, destinatario_id, estado, expira_at > now() as vigente, respondida_at
from public.comunidad_invitaciones
where id = 1;
-- Esperado ahora: estado pending, vigente false, respondida_at null.

select id, usuario_id, actor_id, tipo, payload
from public.notificaciones
where usuario_id = 4
  and tipo = 'invitacion_comunidad';
-- Esperado: 1. Es el id de la invitacion que ya existia.

-- fn_mencioanr_comunidad(p_yo, p_comentario_id, p_destinatario)
-- 2 = Julio, usuarios.id. Quien invita.
-- 6 = UnrealHQ, tutorial_comentarios.id.
-- 4 = Angela, usuarios.id. Quien recibe.
select public.fn_mencionar_comunidad(2,6,4);
-- Esperado: 1. Es el id de la invitacion que ya existia.

select id, comentario_id, actor_id, destinatario_id, estado, expira_at > now() as vigente, respondida_at
from public.comunidad_invitaciones
where comentario_id = 6
  and destinatario_id = 4;
-- Esperado: una sola fila, id 1. estado pending. vigente true. respondiad_at null

-- Linea 54
-- Esperado: una fila. usuario_id 4 Angela. actor_id 2 Julio.
-- codigo UnrealHQ. titulo "Comunidad Unreal".

-- PRUEBA 2. Invitar a alguien que no tenia ticket. Aqui si nace una fila nueva.
select '--- PRUEBA 2: invitacion nueva ---' as test;

-- Antes. Shiriaru no tiene invitacion a UnrealHQ.
-- 1 = Shiriaru, usuarios.id. 6 = UnrealHQ.
select id, estado
from public.comunidad_invitaciones
where comentario_id = 6
  and destinatario_id = 1;
-- Esperado ahora: cero filas.

-- 2 = Julio, usuarios.id. 6 = UnrealHQ. 1 = Shiriaru, usuarios.id.
select public.fn_mencionar_comunidad(2,6,1);
-- Esperado: el id nuevo.

select id, comentario_id, actor_id, destinatario_id, estado, expira_at > now() as vigente
from public.comunidad_invitaciones
where comentario_id = 6
  and destinatario_id = 1;
-- Esperado: una fila. actor 2 Julio. destinatario 1 Shiriaru. estado pending. vigente true.

select id, usuario_id, actor_id, payload->>'codigo' as codigo
from public.notificaciones
where usuario_id = 1
  and tipo = 'invitacion_comunidad';
-- Esperado: una fila. usuario_id 1 Shiriaru. actor_id 2 Julio. codigo UnrealHQ.

-- PRUEBA 3. Invitacion que se va a ignorar en el archivo 16. Julio entra a WordDudas por ticket, no por codigo.
select '--- PRUEBA 3: invitacion para ignorar ---' as test;

-- Antes. Julio no tiene invitacion a WordDudas.
-- 2 = Julio, usuarios.id. 7 = WordDudas.
select id
from public.comunidad_invitaciones
where comentario_id = 7
  and destinatario_id = 2;
-- Esperado ahora: cero filas.

-- 1 = Shiriaru, usuarios.id. 7 = WordDudas. 2 = Julio, usuarios.id.
select public.fn_mencionar_comunidad(1,7,2);
-- Esperado: el id nuevo.

select id, comentario_id, actor_id, destinatario_id, estado, expira_at > now() as vigente
from public.comunidad_invitaciones
where comentario_id = 7
  and destinatario_id = 2;
-- Esperado: una fila. actor 1 Shiriaru. destinatario 2 Julio. pending. vigente true.