-- Unirse a comunidad por codigo
create or replace function public.fn_unirse_comunidad_por_codigo(
    p_yo bigint, p_codigo citext, p_aceptar boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_comentario bigint;
    v_inv bigint;
begin
    select id into v_comentario
    from public.tutorial_comentarios
    where clase = 'comunidad'
      and codigo = p_codigo;

    if v_comentario is null then raise exception 'codigo de comunidad % no existe', p_codigo; end if;

    -- Si tenia invitacion pendiente, reusa fn_responder (misma puerta Aceptar/Rechazar)
    select i.id into v_inv
    from public.comunidad_invitaciones i
    where i.comentario_id = v_comentario
      and i.destinatario_id = p_yo
      and i.estado='pending';

    if v_inv is not null then
        return public.fn_responder_invitacion_comunidad(p_yo, v_inv, p_aceptar);
    end if;

    -- Si no tenia invitacion y acepta, join directo (buscador por codigo exacto)
    if p_aceptar then
        insert into public.comentario_miembros (comentario_id, usuario_id)
        values (v_comentario, p_yo) on conflict do nothing;
    end if;

    delete from public.notificaciones
    where usuario_id = p_yo
    and tipo = 'invitacion_comunidad'
    and payload ->>'codigo' = p_codigo::text;

    return p_aceptar;
end;
$$;

-- PRUEBA 1. Unirse por codigo sin invitacion. PATRON DE BUSCAR EL GRUPO Y ENTRAR.
select '--- PRUEBA 1: join directo por codigo ---' as test;

-- Antes. Comunidad "Mesa de mezclas" del tutorial 9. El codigo lo genero la funcion, no es fijo.
-- 4 = Angela, usuarios.id. 9 = "Edit Music & Audio Mixes", tutoriales.id.
select id, titulo, codigo, miembros_count
from public.tutorial_comentarios
where autor_id = 4
  and tutorial_id = 9
  and clase = 'comunidad';
-- Esperado ahora: una fila. titulo "Mesa de mezclas". miembros_count = 1.

select m.usuario_id, u.username
from public.comentario_miembros as m
join public.usuarios as u on u.id = m.usuario_id
where m.comentario_id = (
    select c.id
    from public.tutorial_comentarios as c
    where c.autor_id = 4
      and c.tutorial_id = 9
      and c.clase = 'comunidad'
);
-- Esperado ahora: solo Angela.

-- fn_unirse_comunidad_por_codigo(p_yo, p_codigo, p_aceptar)
-- 2 = Julio, usuarios.id. No tiene invitacion a esta comunidad.
-- El codigo sale de la fila de arriba.
-- true = entrar.
select public.fn_unirse_comunidad_por_codigo(
    2,
    (select c.codigo
     from public.tutorial_comentarios as c
     where c.autor_id = 4
       and c.tutorial_id = 9
       and c.clase = 'comunidad'),
    true
);
-- Esperado: true.

select id, miembros_count
from public.tutorial_comentarios
where autor_id = 4
  and tutorial_id = 9
  and clase = 'comunidad';
-- Esperado: miembros_count = 2

select m.usuario_id, u.username
from public.comentario_miembros as m
join public.usuarios as u on u.id = m.usuario_id
where m.comentario_id = (
    select c.id
    from public.tutorial_comentarios as c
    where c.autor_id = 4
      and c.tutorial_id = 9
      and c.clase = 'comunidad'
)
order by m.usuario_id;
-- Esperado: 2 Julio y 4 Angela.

-- PRUEBA 2. Unirse por codigo cuando si hay invitacion pending. Entra por la misma puerta que aceptar.
select '--- PRUEBA 2: el codigo acepta la invitacion ---' as test;

-- Antes. Invitacion 1 de Angela a UnrealHQ,  revivida y todavia pending.
-- 4 = Angela. 6 = UnrealHQ, revivida y todavia pending.
select id, estado, respondida_at
from public.comunidad_invitaciones
where id = 6;
-- Esperado ahora: pending, respondida_at null.

select miembros_count
from public.tutorial_comentarios
where id = 6;
-- Esperado ahora: 2.

select usuario_id
from public.comentario_miembros
where comentario_id = 6
order by usuario_id;
-- Esperado ahora: 2 Julio y 3 Sebastian

-- 4 = Angela, usuarios.id.
-- 'UnrealHQ' = codigo de la comunidad, tutorial_comentario.codigo.
-- true = aceptar esa invitacion.
select public.fn_unirse_comunidad_por_codigo(4, 'UnrealHQ', true);

select id, estado, respondida_at
from public.comunidad_invitaciones
where id = 1;
-- Esperado: accepted. respondida_at con fecha.

-- Liena 116
-- Esperado: 3.

-- Linea 121
-- Esperado: 2 Julio , 3 Sebastian , 4 Angela

select id
from public.notificaciones
where usuario_id = 4
  and tipo = 'invitacion_comunidad';
-- Esperado: cero filas.

select origen, codigo
from public.fn_bandeja_menciones(4);
-- Esperado: solo el origen video del tutorial 5, si todavia no corriste el archivo 15
-- UnrealHQ ya no sale: la invitacion dejo de estar pending.
