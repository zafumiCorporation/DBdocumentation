-- Mencionar tutorial / mencionar comunidad / unirse por codigo
create or replace function public.fn_mencionar_tutorial(
    p_yo bigint, p_tutorial_id bigint, p_destinatario bigint
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id bigint;
begin
    -- Me falta esta tabla
    -- tutorial_id -> tutorial donde se hizo la mencion
    -- actor_id -> tu, el que menciona(p_yo)
    -- destinatario_id -> la persona mencionada.
    insert into public.tutorial_menciones (tutorial_id, actor_id, destinatario_id)
    values (p_tutorial_id, p_yo, p_destinatario)
    returning id into v_id;

    -- usuario_id -> el que recibe la notificacion (el mencionado).
    -- actor_id -> el que hizo la accion (tu)
    -- tipo -> "mencion_tutorial"
    -- Creo una notificacion para avisarle al destinatario que fue mencionado en un tutorial
    insert into public.notificaciones (usuario_id, actor_id, tipo, payload)
    values (p_destinatario, p_yo, 'mencion_tutorial',
           jsonb_build_object('mencion_id', v_id, 'tutorial_id', p_tutorial_id));

    -- Enviar notificacion en tiempo real
    perform pg_notify('canal_notif_'||p_destinatario::text,
            jsonb_build_object('tipo','mencion_tutorial','mencion_id', v_id)::text);

    return v_id;
end;
$$;

-- PRUEBA 1. Mencionar un video. Patron TikTok/Youtube: te etiqueto en este tutorial.
select '--- PRUEBA 1: mencionar tutorial ---' as test;

-- Antes. Menciones de Shiriaru hacia Angela en el tutorial 5.
-- 1 = Shiriaru, usuarios.id. El actor.
-- 4 = Angela, usuarios.id. La destinataria.
-- 5 = "Build Level in Unreal Engine", tutoriales.id. Creador: Julio.
select id, tutorial_id, actor_id, destinatario_id, leida_at, expira_at > now() as vigente
from public.tutorial_menciones
where actor_id = 1
  and destinatario_id = 4
  and tutorial_id = 5;
-- Esperado ahora cero filas

--Antes. Avisos mencion_tutorial para Angela.
select id, usuario_id, actor_id, tipo, payload
from public.notificaciones
where usuario_id = 4
  and tipo = 'mencion_tutorial';
-- Esperado ahora: cero filas.

-- fn_mencionar_tutorial(p_yo, p_tutorial_id, p_destinatario)
-- 1 = Shiriaru, usuarios.id. Quien menciona.
-- 5 = "Build Level in Unreal Engine", tutoriales.id
-- 4 = Angela, usuarios.id. Quien recibe el ticket.
select public.fn_mencionar_tutorial(1,5,4);
-- Esperado: el id nuevo de tutorial_menciones.
-- pg_notify no sale en un SELECT. Lo que si queda escrito es la fila y la notificacion.

-- Despues. Ticket vigente, sin Leer, vida de 8 horas. Linea 44
-- Esperado: una fila. Leida_at null. vigente = true.
-- actor_id 1 Shiriaru. destinatario_id 4 Angela. tutorial_id 5.

-- Despues. Angela tiene el aviso. linea 52
-- Esperado: una fila. usuario_id 4 Angela. actor_id 1 Shiriaru.
-- payload.mencion_id = el id de la fila de arriba.  payload.tutorial_id = 5.

