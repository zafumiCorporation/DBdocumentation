create or replace function public.fn_ignorar_invitacion(p_yo bigint, p_invitacion_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.comunidad_invitaciones
    set estado = 'ignored', respondida_at = now()
    where id = p_invitacion_id
    and destinatario_id = p_yo
    and estado = 'pending';
end;
$$;

-- PRUEBA 1. Ignorar. La invitacion deja de estar pending y Julio no entra a WordDudas.
select '--- PRUEBA 1: ignorar invitacion ---' as test;

-- Antes. Invitacion de Julio a WordDudas, creada en la prueba 4 del archivo 12
-- 2 = Julio, usuarios.id. 7 = WordDudas, tutorial_comentarios.id.
select id, estado, respondida_at, expira_at > now() as vigente
from public.comunidad_invitaciones
where comentario_id = 7
  and destinatario_id = 2;
-- Esperado ahora: una fila pending, vigente true, respondida_at null.

select usuario_id
from public.comentario_miembros
where comentario_id = 7
  and usuario_id = 2;
-- Esperado ahora: cero filas. Julio no es miembro.

select origen, codigo
from public.fn_bandeja_menciones(2);
-- Esperado ahora: una fila. origen comunidad. codigo WordDudas.

-- fn_ignorar_invitacion(p_yo, p_invitacion_id)
-- 2 = Julio, usuarios.id
-- El subquery es su invitacion pending a WordDudas.
select public.fn_ignorar_invitacion(
    2,
    (select i.id
     from public.comunidad_invitaciones as i
     where i.comentario_id = 7
       and i.destinatario_id = 2
       and i.estado = 'pending')
);
-- La funcion no devuelve fila. El cambio se ve en el select de abajo

-- Linea 27
-- Esperado: estado ignored. respondida_at con fecha.

select usuario_id
from public.comentario_miembros
where comentario_id = 7
order by usuario_id;
-- Esperado: 1 Shiriaru, 3 Sebastian, 4 Angela. Julio no entro.
-- miembros_count de WordDudas sigue en 3.

-- Linea 33
-- Esperado: cero filas. ignored ya no es pending.