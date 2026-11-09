create or replace function public.fn_purgar_menciones_caducadas()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
v_n int := 0;
v_k int;
begin
    -- 1. Menciones video expiradas o ya leidas
    delete from public.tutorial_menciones
    where expira_at < now() or leida_at is not null;
    -- get diagnostics -> Cuantas filas toco mi ultimo comando SQL
    -- row_count -> cuenta filas afectadas por el ultimo delete o update.
    get diagnostics v_k = row_count; v_n := v_n + v_k;

    -- Invitaciones expiradas o ya respondidas (accepted/declined/ignored)
    delete from public.comunidad_invitaciones
           where expira_at < now()
    or estado in ('accepted', 'declined', 'ignored');
    get diagnostics v_k =  row_count; v_n := v_n + v_k;

    -- Notificaciones huerfanas de 8h (si usas tabla notificaciones como inbox secundario)
    delete from public.notificaciones
    where tipo in ('mencion_tutorial', 'invitacion_comunidad')
      -- Ya fuero leidas , tienen mas de 8 horas de antiguedad
      and (leida or created_at < now() - make_interval(hours => 8));
    get diagnostics v_k = row_count;

    return v_n + v_k;
end;
$$;

-- PRUEBA 1. Purga de 8 horas. Limpia tickets viejos y respondidos. Deja a los miembros.
select '--- PRUEBA 1: purgar caducadas ---' as test;

-- Antes. Menciones. Las dos del seed ya caducaron
-- La de Angela al tutorial 5 ya la borro el archivo 15.
select id, tutorial_id, actor_id, destinatario_id, expira_at > now() as vigente, leida_at
from public.tutorial_menciones
order by id;
-- Esperado ahora: dos filas, id 1 e id 2. Las dos con vigente false y Leida_at null.
-- id 1: tutorial 4, actor 2 Julio, destinatario 1 Shiriaru.
-- id 2: tutorial 9, actor 4 Angela, destinatario 2 Julio.

-- Antes. Invitaciones que ya no estan pending
select id, comentario_id, destinatario_id, estado
from public.comunidad_invitaciones
order by id;
-- Esperado ahora: cuatro filas.
-- id 1, comentario 6 UnrealHQ, destinatario 4 Angela, accepted.
-- id 2, comentario 7 WordDudas, destinatario 3 Sebastian, accepted
-- La de Shiriaru a UnrealHQ, destinatario 1, declined
-- La de Julio a WordDudas, destinatario 2, ignored.

-- Antes. Los miembros siguen. Esto no debe cambiar con la purga
select c.id, c.codigo, c.miembros_count
from public.tutorial_comentarios as c
where c.clase = 'comunidad'
order by c.id;
-- Esperado ahora:
-- id 6 UnrealHQ, miembros_count 3.
-- id 7 WordDudas, miembros_count 3.
-- La comunidad "Mesa de mezclas" del tutorial 9, miembros_count 2.

-- fn_purgar_menciones_caducadas() no recibe argumentos.
select public.fn_purgar_menciones_caducadas();

-- Despues. Ya no hay tickets
select id from public.tutorial_menciones;
-- Esperado: cero filas

-- Despues. Los miembros no se fueron. Linea 58
-- Esperado: Los mismo tres conteso de antes. 3, 3 y 2.

-- Despues. El aviso del video de Angela sigue, porque esta funcion no la marca leido
select id, usuario_id, actor_id, tipo
from public.notificaciones
where tipo = 'mencion_tutorial';
-- Esperado: una fila. usuario_id 4 Angela. actor_id 1 Shiriaru.
